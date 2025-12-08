import logging

from agent.app.config import settings
from agent.app.prompts import ROOT_SYSTEM_INSTRUCTION
from agent.app.tools import end_session_tool, generate_image_tool
from google.adk import Agent

logger = logging.getLogger(__name__)


agent = Agent(
    model=settings.MODEL_ID,
    system_instruction=ROOT_SYSTEM_INSTRUCTION,
    tools=[generate_image_tool, end_session_tool],
)
