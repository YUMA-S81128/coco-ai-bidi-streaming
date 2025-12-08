"""Image Generation Sub-Agent Definition."""

import logging

from agent.app.config import settings
from google.adk import Agent

from .prompts import return_instructions_image_gen
from .tools import create_image_job

logger = logging.getLogger(__name__)

image_gen_agent = Agent(
    model=settings.MODEL_ID,
    name="image_gen_agent",
    system_instruction=return_instructions_image_gen(),
    tools=[create_image_job],
)
