import logging

import firebase_admin
from fastapi import FastAPI
from google.adk.runners import Runner

from app.agent import agent
from app.config import settings
from app.routers import websocket
from app.services.session_factory import get_session_service

# ログ設定
logging.basicConfig(
    level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s"
)
logger = logging.getLogger(__name__)

# Firebase Admin SDK の初期化
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

# FastAPI アプリケーションの初期化
app = FastAPI()

# アプリケーション設定
# VertexAiSessionService を使用する場合、app_name には Agent Engine ID を指定する
# InMemorySessionService を使用する場合は任意の名前でよい
APP_NAME = (
    settings.vertex_ai_agent_engine_id
    if settings.vertex_ai_agent_engine_id
    and settings.session_type.lower() == "vertexai"
    else "coco-ai-bidi-streaming"
)

logger.info(f"Using APP_NAME: {APP_NAME}")

# ADK コンポーネントの初期化
session_service = get_session_service(APP_NAME)
runner = Runner(app_name=APP_NAME, agent=agent, session_service=session_service)

# 状態として保存 (ルーターからアクセス可能にするため)
app.state.runner = runner
app.state.session_service = session_service
app.state.app_name = APP_NAME

# ルーターの登録
app.include_router(websocket.router)


@app.get("/")
async def root():
    """
    ヘルスチェック用のルートエンドポイント。
    """
    return {"message": "Hello from ADK Agent!", "app_name": APP_NAME}


def main():
    """
    アプリケーションのエントリーポイント。
    ローカル開発および本番環境(Cloud Run)でサーバーを起動するために使用されます。
    """
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8080)


if __name__ == "__main__":
    main()
