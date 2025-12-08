"""Tools for the Agent."""

import logging

from agent.app.sub_agents.image_gen.agent import image_gen_agent
from google.adk.tools import ToolContext
from google.adk.tools.agent_tool import AgentTool

logger = logging.getLogger(__name__)


class SessionFinishedException(Exception):
    """セッションを終了するための例外。"""

    pass


async def end_session_tool():
    """
    ユーザーがさようならを言ったり、停止を求めたりしたときに現在のセッションを終了します。
    """
    logger.info("end_session_tool called. Raising SessionFinishedException.")
    raise SessionFinishedException("Session ended by user.")


async def call_image_gen_agent(
    request: str,
    tool_context: ToolContext,
    user_id: str | None = None,
    chat_id: str | None = None,
):
    """
    ユーザーの画像生成リクエストを処理するエージェントを呼び出します。

    Args:
        request: ユーザーからの自然言語による画像生成リクエスト。
        tool_context: ツール実行コンテキスト。
        user_id: リクエストしたユーザーのID (自動注入)。
        chat_id: チャットID (自動注入)。
    """
    logger.info(f"Calling image_gen_agent with request: {request}")

    # 状態に注入されたパラメータを保存（サブエージェントのツールで使用するため）
    if user_id:
        tool_context.state["user_id"] = user_id
    if chat_id:
        tool_context.state["chat_id"] = chat_id

    agent_tool = AgentTool(agent=image_gen_agent)

    # サブエージェントを実行
    # args の内容は AgentTool の実装によるが、通常は自然言語入力として渡される
    result = await agent_tool.run_async(
        args={"request": request}, tool_context=tool_context
    )

    return result
