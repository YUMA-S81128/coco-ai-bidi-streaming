from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """
    アプリケーションの環境変数設定。
    Cloud Build環境では環境変数を読み込み、ローカル開発では.envファイルを利用する。
    """

    MODEL_ID: str = "gemini-live-2.5-flash-preview-native-audio-09-2025"
    LOCATION: str = "global"

    # Session service settings
    SESSION_TYPE: str = "vertexai"
    GOOGLE_CLOUD_PROJECT: str | None = None
    GOOGLE_CLOUD_LOCATION: str = "asia-northeast1"
    VERTEX_AI_AGENT_ENGINE_ID: str | None = None

    # Image Generation & Storage settings
    FIRESTORE_COLLECTION: str = "image_jobs"
    GCS_BUCKET_NAME: str | None = None
    IMAGE_GEN_MODEL_ID: str = "gemini-3-pro-image-preview"
    IMAGE_GEN_LOCATION: str = "global"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        alias_generator=(lambda x: x.upper()),  # 環境変数を大文字に変換
        extra="ignore",  # 未定義のフィールドは無視
    )


settings = Settings()
