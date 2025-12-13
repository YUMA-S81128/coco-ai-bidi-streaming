"""Firestore データ保存サービス。

users, chats, messages, image_jobs コレクションへのデータ操作を提供する。
"""

import logging

from google.cloud import firestore

from app.config import settings

logger = logging.getLogger(__name__)

# Firestore クライアントの初期化
try:
    db = firestore.AsyncClient()
except Exception as e:
    logger.warning(f"Firestore initialize failed: {e}")
    db = None


async def ensure_user_exists(
    user_id: str,
    display_name: str | None = None,
) -> None:
    """
    ユーザードキュメントが存在しない場合に作成する。

    Args:
        user_id: Firebase Authentication の UID。
        display_name: 表示名（オプション）。
    """
    if db is None:
        logger.warning("Firestore not initialized. Skipping user creation.")
        return

    user_ref = db.collection(settings.users_collection).document(user_id)

    try:
        doc = await user_ref.get()
        if not doc.exists:
            user_data = {
                "displayName": display_name or "",
                "createdAt": firestore.SERVER_TIMESTAMP,
            }
            await user_ref.set(user_data)
            logger.info(f"Created user document: {user_id}")
        else:
            logger.debug(f"User already exists: {user_id}")
    except Exception as e:
        logger.error(f"Error ensuring user exists: {e}", exc_info=True)


async def ensure_chat_exists(
    user_id: str,
    chat_id: str,
) -> bool:
    """
    チャットドキュメントが存在しない場合に作成する。

    Args:
        user_id: 所有者のユーザー ID。
        chat_id: チャットセッションの ID。

    Returns:
        新規作成された場合は True、既存の場合は False。
    """
    if db is None:
        logger.warning("Firestore not initialized. Skipping chat creation.")
        return False

    chat_ref = db.collection(settings.chats_collection).document(chat_id)

    try:
        doc = await chat_ref.get()
        if not doc.exists:
            chat_data = {
                "userId": user_id,
                "title": "",  # タイトルは後でエージェントが設定
                "createdAt": firestore.SERVER_TIMESTAMP,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
            await chat_ref.set(chat_data)
            logger.info(f"Created chat document: {chat_id}")
            return True
        else:
            logger.debug(f"Chat already exists: {chat_id}")
            return False
    except Exception as e:
        logger.error(f"Error ensuring chat exists: {e}", exc_info=True)
        return False


async def save_message(
    chat_id: str,
    role: str,
    content: str,
    tool_calls: list[dict] | None = None,
) -> str | None:
    """
    メッセージをサブコレクションに保存する。

    Args:
        chat_id: チャットセッションの ID。
        role: 発言者 ("user" | "model" | "tool")。
        content: メッセージ内容。
        tool_calls: ツール呼び出し情報（オプション）。

    Returns:
        作成されたメッセージの ID、またはエラー時は None。
    """
    if db is None:
        logger.warning("Firestore not initialized. Skipping message save.")
        return None

    messages_ref = (
        db.collection(settings.chats_collection)
        .document(chat_id)
        .collection(settings.messages_collection)
    )

    try:
        message_data: dict = {
            "role": role,
            "content": content,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
        if tool_calls:
            message_data["toolCalls"] = tool_calls

        doc_ref = await messages_ref.add(message_data)
        message_id = doc_ref[1].id
        logger.info(f"Saved message: {chat_id}/messages/{message_id}")

        # チャットの updatedAt を更新
        chat_ref = db.collection(settings.chats_collection).document(chat_id)
        await chat_ref.update({"updatedAt": firestore.SERVER_TIMESTAMP})

        return message_id
    except Exception as e:
        logger.error(f"Error saving message: {e}", exc_info=True)
        return None


async def update_chat_title(
    chat_id: str,
    title: str,
) -> bool:
    """
    チャットのタイトルを更新する。

    Args:
        chat_id: チャットセッションの ID。
        title: 設定するタイトル。

    Returns:
        成功時は True、エラー時は False。
    """
    if db is None:
        logger.warning("Firestore not initialized. Skipping title update.")
        return False

    chat_ref = db.collection(settings.chats_collection).document(chat_id)

    try:
        await chat_ref.update(
            {
                "title": title,
                "updatedAt": firestore.SERVER_TIMESTAMP,
            }
        )
        logger.info(f"Updated chat title: {chat_id} -> {title}")
        return True
    except Exception as e:
        logger.error(f"Error updating chat title: {e}", exc_info=True)
        return False


# --- Image Jobs 関連 ---


async def create_image_job(
    prompt: str,
    user_id: str | None = None,
    chat_id: str | None = None,
    message_id: str | None = None,
) -> str | None:
    """
    画像生成ジョブを作成する。

    Args:
        prompt: 画像生成に使用するプロンプト。
        user_id: ユーザー ID。
        chat_id: チャット ID。
        message_id: メッセージ ID。

    Returns:
        作成されたジョブの ID、またはエラー時は None。
    """
    if db is None:
        logger.warning("Firestore not initialized. Cannot create job.")
        return None

    try:
        job_ref = db.collection(settings.image_jobs_collection).document()
        job_id = job_ref.id
        job_data = {
            "prompt": prompt,
            "status": "pending",
            "createdAt": firestore.SERVER_TIMESTAMP,
            "updatedAt": firestore.SERVER_TIMESTAMP,
            "userId": user_id,
            "chatId": chat_id,
            "messageId": message_id,
        }
        await job_ref.set(job_data)
        logger.info(f"Created image job: {job_id}")
        return job_id
    except Exception as e:
        logger.error(f"Failed to create image job: {e}", exc_info=True)
        return None


async def update_image_job_status(
    job_id: str,
    status: str,
    data: dict | None = None,
) -> bool:
    """
    画像生成ジョブのステータスを更新する。

    Args:
        job_id: 更新対象のジョブ ID。
        status: 新しいステータス。
            ("pending" | "processing" | "completed" | "failed")
        data: 追加で更新するデータ (オプション、例: {"imageUrl": "..."})。

    Returns:
        成功時は True、エラー時は False。
    """
    if db is None:
        logger.warning("Firestore not initialized. Cannot update job.")
        return False

    try:
        update_payload: dict = {
            "status": status,
            "updatedAt": firestore.SERVER_TIMESTAMP,
        }
        if data:
            update_payload.update(data)

        job_ref = db.collection(settings.image_jobs_collection).document(job_id)
        await job_ref.set(update_payload, merge=True)
        logger.info(f"[{job_id}] Job status updated to: {status}")
        return True
    except Exception as e:
        logger.error(f"[{job_id}] Error updating job status: {e}", exc_info=True)
        return False
