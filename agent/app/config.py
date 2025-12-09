from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    アプリケーションの環境変数設定。
    Cloud Build環境では環境変数を読み込み、ローカル開発では.envファイルを利用する。
    """

    # Model Settings
    ## Bidi-Streaming
    model_id: str = Field(
        default="gemini-live-2.5-flash-preview-native-audio-09-2025",
        description="Bidi-Streaming用のモデルID",
    )
    ## Image Generation
    image_gen_model_id: str = Field(
        default="gemini-3-pro-image-preview", description="画像生成用のモデルID"
    )
    image_gen_location: str = Field(
        default="global", description="画像生成用のロケーション"
    )

    # General Google Cloud Settings
    google_cloud_project: str | None = Field(
        default=None, description="Google CloudプロジェクトID"
    )
    google_cloud_location: str = Field(
        default="asia-northeast1", description="Google Cloudロケーション"
    )

    # Vertex AI Agent Engine Settings
    vertex_ai_agent_engine_id: str | None = Field(
        default=None, description="Vertex AI Agent Engine ID"
    )
    session_type: str = Field(default="vertexai", description="セッションタイプ")

    # Firestore Settings
    firestore_collection: str = Field(
        default="image_jobs", description="画像生成ジョブ管理用のコレクション名"
    )
    users_collection: str = Field(
        default="users", description="ユーザー情報管理用のコレクション名"
    )
    chats_collection: str = Field(
        default="chats", description="チャットセッション管理用のコレクション名"
    )
    messages_collection: str = Field(
        default="messages",
        description="チャットメッセージ履歴管理用のサブコレクション名",
    )

    # Cloud Storage Settings
    gcs_bucket_name: str | None = Field(default=None, description="GCSバケット名")

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        alias_generator=(lambda x: x.upper()),  # 環境変数を大文字に変換
        extra="ignore",  # 未定義のフィールドは無視
    )


@lru_cache
def get_settings() -> Settings:
    """
    アプリケーション設定をシングルトンとして取得し、キャッシュする関数。
    """
    return Settings()


settings = get_settings()
