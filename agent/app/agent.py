import logging

from google.adk import Agent

from app.config import settings
from app.prompts import ROOT_SYSTEM_INSTRUCTION
from app.tools import end_session_tool, generate_image_tool

logger = logging.getLogger(__name__)


agent = Agent(
    name="Coco-Ai Live Agent",
    model=settings.model_id,
    instruction=ROOT_SYSTEM_INSTRUCTION,
    tools=[generate_image_tool, end_session_tool],
)
