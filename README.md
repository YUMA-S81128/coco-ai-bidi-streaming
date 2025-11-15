# coco-ai-bidi-streaming

## ディレクトリ構成

このプロジェクトは、以下のディレクトリで構成されています。

-   `./app`: Flutter (Web) で構築されたフロントエンドクライアントアプリケーション。UI、マイク入力、音声再生などを担当します。
-   `./agent`: Python (FastAPI, ADK) で構築されたコアバックエンドエージェント。WebSocket接続を管理し、Gemini Live APIとの音声ストリーム中継やビジネスロジックを担当します。
-   `./functions`: WebSocket接続のための安全な一時認証トークンを発行する責務を持つPython 製の Cloud Functions for Firebase。