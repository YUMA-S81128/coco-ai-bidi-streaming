import logging
from google.cloud import firestore
from google.cloud import firestore_v1

logger = logging.getLogger(__name__)

# Initialize Firestore client
# Assuming GOOGLE_APPLICATION_CREDENTIALS is set or environment is configured
try:
    db = firestore.Client()
except Exception as e:
    logger.warning(f"Failed to initialize Firestore client: {e}")
    db = None

async def generate_image(prompt: str, user_id: str | None = None, chat_id: str | None = None) -> str:
    """
    Generates an image based on the prompt.
    This function creates a job in Firestore to be processed by a separate worker.
    
    Args:
        prompt: The description of the image to generate.
        user_id: The ID of the user requesting the image.
        chat_id: The ID of the chat session.
    """
    logger.info(f"Tool call: generate_image(prompt='{prompt}', user_id={user_id}, chat_id={chat_id})")
    
    if db is None:
        return "Error: Firestore client not initialized."

    try:
        # Create a new document in 'image_jobs' collection
        job_ref = db.collection("image_jobs").document()
        job_data = {
            "prompt": prompt,
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "userId": user_id,
            "chatId": chat_id,
        }
        # Use set to create the document
        job_ref.set(job_data)
        
        return f"Image generation job started with ID: {job_ref.id}. The user will see it shortly."
    except Exception as e:
        logger.error(f"Error creating image job: {e}")
        return f"Error starting image generation job: {e}"
