"""Gen AI SDK を使用した画像生成サービス。"""

import asyncio
import logging
import ssl
import uuid

import requests
from google import genai
from google.cloud import storage
from google.genai import types
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)
from urllib3.exceptions import SSLError as UrllibSSLError

from app.config import settings
from app.services.firestore_service import (
    create_image_job,
    update_image_job_status,
)

logger = logging.getLogger(__name__)

# GCS クライアントの初期化
storage_client = storage.Client()


# --- リトライロジック ---
def is_ssl_error(exc: BaseException) -> bool:
    """
    SSL 関連のエラーかどうかを判定する。

    tenacity のリトライ条件として使用される述語関数。

    Args:
        exc: 発生した例外。

    Returns:
        SSL 関連のエラーの場合は True。
    """
    ssl_types = (requests.exceptions.SSLError, UrllibSSLError, ssl.SSLError)
    if isinstance(exc, ssl_types):
        return True
    cause = getattr(exc, "__cause__", None)
    if isinstance(cause, ssl_types):
        return True
    context = getattr(exc, "__context__", None)
    if isinstance(context, ssl_types):
        return True
    return False


gcs_retry_decorator = retry(
    stop=stop_after_attempt(5),
    wait=wait_exponential(multiplier=1, min=10, max=60),
    retry=retry_if_exception(is_ssl_error),
    before_sleep=before_sleep_log(logger, logging.WARNING),
    reraise=True,
)


@gcs_retry_decorator
async def upload_blob_from_memory(
    bucket_name: str,
    destination_blob_name: str,
    data: bytes,
    content_type: str,
) -> str:
    """
    バイトデータを GCS バケットにアップロードする。

    Args:
        bucket_name: アップロード先のバケット名。
        destination_blob_name: アップロード先の Blob 名。
        data: アップロードするバイトデータ。
        content_type: コンテンツタイプ (例: "image/png")。

    Returns:
        GCS URI (gs://bucket/blob_name 形式)。
    """
    logger.info(f"Uploading to GCS: gs://{bucket_name}/{destination_blob_name}")
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    await asyncio.to_thread(blob.upload_from_string, data, content_type=content_type)

    gcs_path = f"gs://{bucket_name}/{destination_blob_name}"
    logger.info(f"Uploaded: {gcs_path}")
    return gcs_path


# --- 画像生成 API ---
async def generate_image(
    prompt: str,
    user_id: str | None = None,
    chat_id: str | None = None,
    message_id: str | None = None,
) -> str:
    """
    Gen AI SDK を使用して画像を生成する。

    Args:
        prompt: 画像生成のための詳細なプロンプト。
        user_id: ユーザー ID。
        chat_id: チャット ID。
        message_id: メッセージ ID。指定されない場合は自動生成される。

    Returns:
        処理結果のステータスメッセージ。
    """
    # message_id が指定されていない場合は UUID を生成
    if not message_id:
        message_id = str(uuid.uuid4())
        logger.info(f"Generated message_id: {message_id}")

    logger.info(
        f"generate_image called: prompt='{prompt}', "
        f"user_id={user_id}, chat_id={chat_id}, message_id={message_id}"
    )

    if not settings.gcs_bucket_name:
        logger.error("GCS_BUCKET_NAME is not set.")
        return "Error: Server configuration error (GCS bucket not set)."

    # 1. ジョブの作成 (pending 状態)
    job_id = await create_image_job(prompt, user_id, chat_id, message_id)
    if not job_id:
        return "Error: Failed to create image job."

    # 2. Run Generation
    try:
        await update_image_job_status(job_id, "processing")

        client = genai.Client(
            vertexai=True,
            project=settings.google_cloud_project,
            location=settings.image_gen_location,
        )

        response = await asyncio.to_thread(
            client.models.generate_content,
            model=settings.image_gen_model_id,
            contents=prompt,
            config=types.GenerateContentConfig(
                response_modalities=["IMAGE"],
                image_config=types.ImageConfig(aspect_ratio="16:9"),
            ),
        )

        if not response.candidates or not response.candidates[0].content.parts:
            raise ValueError("No content generated.")

        generated_image_bytes = None
        for part in response.candidates[0].content.parts:
            if part.inline_data:
                generated_image_bytes = part.inline_data.data
                break

        if not generated_image_bytes:
            raise ValueError("No image data found in response.")

        # 3. Upload to GCS
        filename = f"{job_id}.png"
        upload_path = (
            f"generated_images/{user_id}/{filename}"
            if user_id
            else f"generated_images/unknown_user/{filename}"
        )

        image_url = await upload_blob_from_memory(
            settings.gcs_bucket_name,
            upload_path,
            generated_image_bytes,
            "image/png",
        )

        # 4. Complete
        await update_image_job_status(job_id, "completed", {"imageUrl": image_url})
        return f"画像生成ジョブを開始しました。ID: {job_id}"

    except Exception as e:
        logger.error(f"Error during image generation: {e}", exc_info=True)
        await update_image_job_status(job_id, "failed", {"error": str(e)})
        return f"Image generation failed: {e}"
