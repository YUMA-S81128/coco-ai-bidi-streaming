"""Tools for the Image Generation Agent."""

import logging

from google.adk.tools import ToolContext

from .service import generate_image

logger = logging.getLogger(__name__)


async def create_image_job(prompt: str, tool_context: ToolContext):
    """
    Creates an image generation job in Firestore.

    Args:
        prompt: The refined prompt for image generation.
        tool_context: The tool context.
    """
    logger.info(f"Sub-agent creating image job for prompt: {prompt}")

    # Retrieve user_id and chat_id from the context state
    # These should be populated by the calling tool (call_image_gen_agent)
    user_id = tool_context.state.get("user_id")
    chat_id = tool_context.state.get("chat_id")

    if not user_id or not chat_id:
        logger.warning(
            "user_id or chat_id not found in tool_context.state. "
            "Using fallback or None."
        )
        # If not found, we pass None and let the service handle it
        # (it might fail or use defaults)

    return await generate_image(prompt, user_id, chat_id)
