import asyncio
import logging
import ssl

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

# Firestore Initialization
try:
    db = firestore.AsyncClient()
except Exception as e:
    logger.warning(f"Firestore initialize failed: {e}")
    db = None

# GCS Initialization
storage_client = storage.Client()


# --- Retry Logic (from user snippet) ---
def is_ssl_error(exc: BaseException) -> bool:
    """
    tenacity predicate: check if exception is SSL related.
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
    Uploads bytes to GCS bucket.

    Returns:
        The GCS URI (gs://bucket/blob_name).
    """
    logger.info(
        f"Uploading to GCS: gs://{bucket_name}/{destination_blob_name}"
    )
    bucket = storage_client.bucket(bucket_name)
    blob = bucket.blob(destination_blob_name)

    # GCS client is synchronous, so run in thread
    await asyncio.to_thread(blob.upload_from_string, data, content_type=content_type)

    gcs_path = f"gs://{bucket_name}/{destination_blob_name}"
    logger.info(f"Uploaded: {gcs_path}")

    # Based on prompt "frontend downloads", and user request for Flutter integration:
    # return the gs:// path.
    return gcs_path


# --- Firestore Helpers (from user snippet) ---
async def _update_job(db: firestore.AsyncClient, job_id: str, payload: dict):
    """Internal helper to update Firestore job."""
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
):
    """Update job status and optional data."""
    update_payload = {"status": status}
    if data:
        update_payload.update(data)
    await _update_job(db, job_id, update_payload)


# --- API Call ---
async def generate_image(
    prompt: str, user_id: str | None = None, chat_id: str | None = None
) -> str:
    """
    Generates an image based on the prompt using Imagen 3 (via google-genai).
    """
    logger.info(
        f"generate_image called: prompt='{prompt}', "
        f"user_id={user_id}, chat_id={chat_id}"
    )

    if db is None:
        return "Error: Firestore not initialized."

    if not settings.GCS_BUCKET_NAME:
        logger.error("GCS_BUCKET_NAME is not set.")
        return "Error: Server configuration error (GCS bucket not set)."

    # 1. Create Job (Pending)
    try:
        job_ref = db.collection(settings.FIRESTORE_COLLECTION).document()
        job_id = job_ref.id
        job_data = {
            "prompt": prompt,
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "userId": user_id,
            "chatId": chat_id,
        }
        await job_ref.set(job_data)
        logger.info(f"Created job: {job_id}")
    except Exception as e:
        logger.error(f"Failed to create job: {e}")
        return f"Error creating image job: {e}"

    # 2. Run Generation
    # (Background Task concept, but we await here for the Agent tool)
    # Ideally this should be a background task if it takes long,
    # but for simplicity we await.
    try:
        await update_job_status(db, job_id, "processing")

        # Initialize Gen AI Client
        client = genai.Client(
            vertexai=True,
            project=settings.GOOGLE_CLOUD_PROJECT,
            location=settings.IMAGE_GEN_LOCATION
        )

        # Call Imagen 3
        response = await asyncio.to_thread(
             client.models.generate_content,
             model=settings.IMAGE_GEN_MODEL_ID,
             contents=prompt,
             config=types.GenerateContentConfig(
                 response_modalities=['IMAGE'],
                 image_config=types.ImageConfig(
                     aspect_ratio="16:9",
                     # 2K is not a valid enum string usually,
                     # using 1024x1024 or leaving default might be safer.
                     # "2K" isn't standard enum.
                 ),
             ),
        )

        # Check for image
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
            "image/png"
        )

        # 4. Complete
        await update_job_status(db, job_id, "completed", {"imageUrl": image_url})
        return f"Image generated successfully. Job ID: {job_id}"

    except Exception as e:
        logger.error(f"Error during image generation: {e}", exc_info=True)
        await update_job_status(db, job_id, "failed", {"error": str(e)})
        return f"Image generation failed: {e}"
