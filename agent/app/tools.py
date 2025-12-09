"""エージェントで使用するツール群。"""

import logging

from google.adk.tools import ToolContext

from app.services.image_gen import generate_image

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
) -> str:
    """
    画像を生成する。

    ユーザーが視覚的な表現を求めている場合や、説明を補足するために画像が役立つ場合に、
    このツールを使用する。プロンプトには、被写体、スタイル、ムード、
    構図などの詳細を含めること。

    Args:
        prompt: 画像生成のための詳細なプロンプト。
        tool_context: ADK ツールコンテキスト。

    Returns:
        画像生成ジョブのステータスメッセージ。
    """
    logger.info(f"generate_image_tool called with prompt: {prompt[:100]}...")

    # セッション state からユーザー情報を取得
    user_id = tool_context.state.get("user_id")
    chat_id = tool_context.state.get("chat_id")
    # message_id は image_gen.py で自動生成される

    return await generate_image(prompt, user_id, chat_id)
