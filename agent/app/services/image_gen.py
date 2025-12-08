"""Gen AI SDK を使用した画像生成サービス。"""

import asyncio
import logging
import ssl
import uuid

import requests
from agent.app.config import settings
from google import genai
from google.cloud import firestore, storage
from google.genai import types
from tenacity import (
    before_sleep_log,
    retry,
    retry_if_exception,
    stop_after_attempt,
    wait_exponential,
)
from urllib3.exceptions import SSLError as UrllibSSLError

logger = logging.getLogger(__name__)

# Firestore クライアントの初期化
try:
    db = firestore.AsyncClient()
except Exception as e:
    logger.warning(f"Firestore initialize failed: {e}")
    db = None

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


# --- Firestore ヘルパー関数 ---
async def _update_job(db: firestore.AsyncClient, job_id: str, payload: dict) -> None:
    """
    Firestore のジョブドキュメントを更新する内部ヘルパー関数。

    Args:
        db: Firestore の非同期クライアント。
        job_id: 更新対象のジョブ ID。
        payload: 更新するデータ。
    """
    logger.info(f"[{job_id}] Updating job... Payload: {payload}")
    payload["updatedAt"] = firestore.SERVER_TIMESTAMP
    job_ref = db.collection(settings.FIRESTORE_COLLECTION).document(job_id)

    try:
        await job_ref.set(payload, merge=True)
        logger.info(f"[{job_id}] Job updated.")
    except Exception as e:
        logger.error(f"[{job_id}] Error updating job: {e}", exc_info=True)
        raise


async def update_job_status(
    db: firestore.AsyncClient, job_id: str, status: str, data: dict | None = None
) -> None:
    """
    ジョブのステータスとオプションデータを更新する。

    Args:
        db: Firestore の非同期クライアント。
        job_id: 更新対象のジョブ ID。
        status: 新しいステータス文字列。
        data: 追加で更新するデータ (オプション)。
    """
    update_payload = {"status": status}
    if data:
        update_payload.update(data)
    await _update_job(db, job_id, update_payload)


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

    if db is None:
        return "Error: Firestore not initialized."

    if not settings.GCS_BUCKET_NAME:
        logger.error("GCS_BUCKET_NAME is not set.")
        return "Error: Server configuration error (GCS bucket not set)."

    # 1. ジョブの作成 (pending 状態)
    try:
        job_ref = db.collection(settings.FIRESTORE_COLLECTION).document()
        job_id = job_ref.id
        job_data = {
            "prompt": prompt,
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "userId": user_id,
            "chatId": chat_id,
            "messageId": message_id,
        }
        await job_ref.set(job_data)
        logger.info(f"Created job: {job_id}")
    except Exception as e:
        logger.error(f"Failed to create job: {e}")
        return f"Error creating image job: {e}"

    # 2. Run Generation
    try:
        await update_job_status(db, job_id, "processing")

        client = genai.Client(
            vertexai=True,
            project=settings.GOOGLE_CLOUD_PROJECT,
            location=settings.IMAGE_GEN_LOCATION,
        )

        response = await asyncio.to_thread(
            client.models.generate_content,
            model=settings.IMAGE_GEN_MODEL_ID,
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
        image_url = await upload_blob_from_memory(
            settings.GCS_BUCKET_NAME,
            f"generated_images/{filename}",
            generated_image_bytes,
            "image/png",
        )

        # 4. Complete
        await update_job_status(db, job_id, "completed", {"imageUrl": image_url})
        return f"画像生成ジョブを開始しました。ID: {job_id}"

    except Exception as e:
        logger.error(f"Error during image generation: {e}", exc_info=True)
        await update_job_status(db, job_id, "failed", {"error": str(e)})
        return f"Image generation failed: {e}"
