import logging
import os

from agent.app.agent import agent
from agent.app.routers import websocket
from agent.app.services.session_factory import get_session_service
from fastapi import FastAPI
from google.adk.runners import Runner

import firebase_admin
from firebase_admin import credentials

# ログ設定
logging.basicConfig(level=logging.INFO, format="%(asctime)s - %(name)s - %(levelname)s - %(message)s")
logger = logging.getLogger(__name__)

# Firebase Admin SDK の初期化
try:
    firebase_admin.get_app()
except ValueError:
    firebase_admin.initialize_app()

# アプリケーション設定
APP_NAME = "coco-ai-bidi-streaming"

# FastAPI アプリケーションの初期化
app = FastAPI()

# ADK コンポーネントの初期化
session_service = get_session_service(APP_NAME)
runner = Runner(
    app_name=APP_NAME,
    agent=agent,
    session_service=session_service
)

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

    port = int(os.environ.get("PORT", 8080))
    uvicorn.run(app, host="0.0.0.0", port=port)

if __name__ == "__main__":
    main()
