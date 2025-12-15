# ADK Agent (Backend)

## 1. 概要

本ディレクトリは、Gemini Live Streaming Agent プロジェクトのバックエンド部分であるADKエージェントの実装です。
Python, FastAPI, ADK (Agent Development Kit) を用いて構築されており、リアルタイムの音声ストリーミング中継と、会話に応じたツール（画像生成ジョブ発行など）の実行を担当します。

デプロイ先は **Google Cloud Run (BFF構成)** です。

## 2. 主な機能

-   **WebSocketサーバー:**
    -   FastAPIと`websockets`ライブラリを使用し、FlutterクライアントからのWebSocket接続を受け付けます。
    -   接続パラメータ (`?token=...&chat_id=...`) から送られた Firebase ID トークンを検証し、認証を行います。
-   **リアルタイムストリーム中継:**
    -   クライアントから受信した音声チャンクを、ADKを介して**Gemini Live API**に転送します。
    -   Gemini Live APIから返却される応答音声チャンクを、リアルタイムでクライアントに転送します。
-   **セッション管理:**
    -   Vertex AI Agent Engine (VertexAiSessionService) を利用して、会話履歴をクラウド上に永続化します。
    -   `VertexAiSessionService` はカスタム session_id をサポートしないため、セッション ID は自動生成されます。
    -   フロントエンドの `chat_id` とバックエンドの `session_id` のマッピングは Firestore (`chats.sessionId`) で管理します。
-   **ツール実行:**
    -   会話の中でGeminiが特定のツール（例: 画像生成）を呼び出す判断をした場合、それを検知します。
    -   画像生成プロンプトを取得し、Firestoreの`image_jobs`コレクションに新しいジョブとして登録します。

## 3. アーキテクチャと技術スタック

-   **フレームワーク:** [FastAPI](https://fastapi.tiangolo.com/)
-   **AI連携:** [Google ADK (Agent Development Kit)](https://google.github.io/adk-docs/)
-   **リアルタイム通信:** [websockets](https://websockets.readthedocs.io/en/stable/)
-   **Firebase連携:** `firebase-admin` SDK を使用し、Firestoreへのデータ書き込みなどを行います。
-   **パッケージ管理:** `uv`

詳細なアーキテクチャやシーケンス図については、プロジェクトルートの [`README.md`](../README.md) を参照してください。

## 4. 開発

### セットアップ

パッケージ管理ツール`uv`を使用して、仮想環境の作成と依存関係のインストールを行います。

```bash
# 仮想環境の作成
uv venv

# 仮想環境のアクティベート
source .venv/bin/activate  # macOS/Linux
.venv\\Scripts\\activate    # Windows

# 依存関係のインストール (uv.lock から)
uv sync
```

### 実行

FastAPIの開発サーバーを起動します。

```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```
