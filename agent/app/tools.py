"""Tools for the Agent."""

import logging

from agent.app.services.image_gen import generate_image
from google.adk.tools import ToolContext

logger = logging.getLogger(__name__)


class SessionFinishedException(Exception):
    """セッションを終了するための例外。"""

    pass


async def end_session_tool() -> None:
    """
    ユーザーがさようならを言ったり、停止を求めたりしたときに現在のセッションを終了します。
    """
    logger.info("end_session_tool called. Raising SessionFinishedException.")
    raise SessionFinishedException("Session ended by user.")


async def generate_image_tool(
    prompt: str,
    tool_context: ToolContext,
    user_id: str | None = None,
    chat_id: str | None = None,
    message_id: str | None = None,
) -> str:
    """
    画像を生成します。

    ユーザーが視覚的な表現を求めている場合や、説明を補足するために画像が役立つ場合に、
    このツールを使用してください。プロンプトには、被写体、スタイル、ムード、
    構図などの詳細を含めてください。

    Args:
        prompt: 画像生成のための詳細なプロンプト。
        tool_context: ツールコンテキスト。
        user_id: ユーザーID (自動注入)。
        chat_id: チャットID (自動注入)。
        message_id: メッセージID (自動注入)。

    Returns:
        画像生成ジョブのステータスメッセージ。
    """
    logger.info(f"generate_image_tool called with prompt: {prompt[:100]}...")

    # Retrieve IDs from context if not provided directly
    if not user_id:
        user_id = tool_context.state.get("user_id")
    if not chat_id:
        chat_id = tool_context.state.get("chat_id")
    if not message_id:
        message_id = tool_context.state.get("message_id")

    return await generate_image(prompt, user_id, chat_id, message_id)
