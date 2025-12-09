import asyncio
import logging

from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from firebase_admin import auth
from google.adk.agents.live_request_queue import LiveRequestQueue
from google.adk.agents.run_config import RunConfig, StreamingMode
from google.genai import types

from app.tools import SessionFinishedException

router = APIRouter()
logger = logging.getLogger(__name__)


@router.websocket("/ws")
async def websocket_endpoint(
    websocket: WebSocket,
    token: str | None = None,
    chat_id: str | None = None,
    response_mode: str = "audio",
):
    """
    WebSocket エンドポイント。

    クライアントからの接続を認証・検証し、ADK Runner を使用して
    双方向ストリーミングセッションを開始します。

    Args:
        websocket: WebSocket 接続オブジェクト。
        token: Firebase Authentication ID トークン (クエリパラメータ、必須)。
        chat_id: チャットセッションの ID (クエリパラメータ、必須)。
        response_mode: レスポンスのモード。"audio" (デフォルト) または "text"。
    """
    # 接続受け入れ前に必須パラメータを検証
    # 無効な接続を早期に拒否し、リソースを節約
    if not token or not chat_id:
        logger.warning(
            f"必須パラメータ不足: token={bool(token)}, chat_id={bool(chat_id)}"
        )
        await websocket.close(code=1008, reason="Missing required parameters")
        return

    # Firebase ID トークンを検証し、ユーザーIDを取得
    user_id: str | None = None
    try:
        decoded_token = auth.verify_id_token(token)
        user_id = decoded_token["uid"]
        logger.info(f"認証成功: user_id={user_id}")
    except Exception as e:
        logger.warning(f"トークン検証失敗: {e}")
        await websocket.close(code=1008, reason="Invalid authentication token")
        return

    # 認証成功後、WebSocket 接続を受け入れ
    await websocket.accept()
    logger.info(
        f"WebSocket 接続確立: user_id={user_id}, chat_id={chat_id}, mode={response_mode}"  # noqa: E501
    )

    # main.py で設定された Runner と SessionService を取得
    runner = websocket.app.state.runner
    session_service = websocket.app.state.session_service
    app_name = websocket.app.state.app_name

    # セッションIDとして chat_id を使用
    session_id = chat_id

    # セッションの取得または作成
    # state にユーザー情報を設定し、ツールからアクセス可能にする
    session = await session_service.get_session(
        app_name=app_name, user_id=user_id, session_id=session_id
    )
    if not session:
        await session_service.create_session(
            app_name=app_name,
            user_id=user_id,
            session_id=session_id,
            state={"user_id": user_id, "chat_id": chat_id},
        )

    # LiveRequestQueue の作成
    live_request_queue = LiveRequestQueue()

    # レスポンスモードの設定
    response_modalities = ["AUDIO"]
    output_audio_transcription = types.AudioTranscriptionConfig()

    if response_mode and response_mode.lower() == "text":
        response_modalities = ["TEXT"]
        output_audio_transcription = None

    # RunConfig の設定
    run_config = RunConfig(
        streaming_mode=StreamingMode.BIDI,
        response_modalities=response_modalities,
        input_audio_transcription=types.AudioTranscriptionConfig(),
        output_audio_transcription=output_audio_transcription,
        session_resumption=types.SessionResumptionConfig(),
    )

    async def upstream_task():
        """
        WebSocket からメッセージを受信し、LiveRequestQueue に送信します。
        """
        try:
            while True:
                message = await websocket.receive()

                if "bytes" in message:
                    # 音声データ (bytes)
                    data = message["bytes"]
                    # ADK は bytes を直接受け取れるか、
                    # Content オブジェクトにラップするか
                    # LiveRequestQueue.send_realtime は bytes を受け取る
                    # mime_type は audio/pcm;rate=16000 などを想定
                    live_request_queue.send_realtime(data, mime_type="audio/pcm")

                elif "text" in message:
                    # テキストメッセージ
                    text = message["text"]
                    content = types.Content(parts=[types.Part(text=text)])
                    live_request_queue.send_content(content)

        except WebSocketDisconnect:
            logger.info("クライアントが切断しました (Upstream)")
        except Exception as e:
            logger.error(f"Upstream エラー: {e}")
        finally:
            # クライアント切断時はキューを閉じて終了シグナルを送る
            live_request_queue.close()

    async def downstream_task():
        """
        Runner からのイベントを受信し、WebSocket に送信します。
        """
        try:
            async for event in runner.run_live(
                user_id=user_id,
                session_id=session_id,
                live_request_queue=live_request_queue,
                run_config=run_config,
            ):
                # イベントを JSON にシリアライズして送信
                # exclude_none=True でデータ量を削減
                event_json = event.model_dump_json(exclude_none=True, by_alias=True)
                await websocket.send_text(event_json)

        except Exception as e:
            logger.error(f"Downstream エラー: {e}")
            # エラー発生時も適切にクローズ処理へ

    # 双方向タスクの並行実行
    try:
        await asyncio.gather(upstream_task(), downstream_task())
    except SessionFinishedException:
        logger.info("Session ended by tool (User requested termination).")
    except Exception as e:
        logger.error(f"セッション全体のエラー: {e}")
    finally:
        logger.info("セッション終了処理")
        live_request_queue.close()
        try:
            await websocket.close()
        except Exception:
            pass
