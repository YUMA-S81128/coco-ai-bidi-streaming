import logging

from agent.app.config import settings
from google.adk.sessions import InMemorySessionService, SessionService
from google.adk.vertexai import VertexAiSessionService

logger = logging.getLogger(__name__)


def get_session_service(app_name: str) -> SessionService:
    """
    環境変数 `SESSION_TYPE` に基づいて SessionService を初期化して返す。

    Args:
        app_name: アプリケーション名。

    Returns:
        初期化された SessionService インスタンス。
        - "vertexai": VertexAiSessionService を使用 (本番環境向け)。
        - "memory": InMemorySessionService を使用 (ローカル開発向け)。
    """
    session_type = settings.SESSION_TYPE.lower()
    project_id = settings.GOOGLE_CLOUD_PROJECT
    location = settings.GOOGLE_CLOUD_LOCATION

    logger.info(f"Initializing SessionService with type: {session_type}")

    if session_type == "vertexai":
        if not project_id:
            # ローカルなどでプロジェクトIDがない場合、memoryにフォールバック、
            # またはエラーにする
            logger.warning(
                "GOOGLE_CLOUD_PROJECT not set. Fallback to InMemorySessionService."
            )
            return InMemorySessionService()

        return VertexAiSessionService(
            project_id=project_id,
            location=location,
            agent_engine_id=settings.VERTEX_AI_AGENT_ENGINE_ID,
        )
    elif session_type == "memory":
        return InMemorySessionService()
    else:
        logger.warning(
            f"Unknown SESSION_TYPE '{session_type}'. "
            "Fallback to InMemorySessionService."
        )
        return InMemorySessionService()
