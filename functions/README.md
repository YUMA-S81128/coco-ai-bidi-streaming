# Cloud Functions for Firebase

## 1. 概要

本ディレクトリは、[Gemini Live Streaming Agent プロジェクト](../AGENTS.md)において、ADKエージェントへの安全な接続を実現するための一時トークンを発行するCloud Functionの実装です。

**Cloud Functions for Firebase (2nd Gen)** を使用し、Pythonで記述されています。

## 2. 機能と役割

このHTTPトリガー関数は、単一の責任を持ちます。

-   **一時トークンの発行:**
    1.  認証済みのFlutterクライアントから、Firebase AuthのIDトークンを含むリクエストを受け取ります。
    2.  受け取ったIDトークンを検証し、リクエストが正当なユーザーからのものであることを確認します。
    3.  ADKエージェント（Vertex AI Agent Engine上で稼働）のWebSocketエンドポイントに接続するための、**短命な一時トークン**を生成します。
    4.  生成した一時トークンをクライアントに返却します。

この仕組みにより、永続的なAPIキーやサービスアカウントキーをクライアントサイドに持つことなく、安全にバックエンドへの接続を確立できます。

## 3. 技術スタック

-   **プラットフォーム:** Cloud Functions for Firebase (2nd Gen)
-   **言語:** Python
-   **Firebase連携:** `firebase-admin` SDK, `firebase-functions`
-   **パッケージ管理:** `uv`

詳細なアーキテクチャや一時トークンのライフサイクルについては、プロジェクトルートの [`AGENTS.md`](../AGENTS.md) を参照してください。

## 4. 開発

### セットアップ

`firebase.json`の`functions.source`がこのディレクトリを指していることを確認してください。
依存関係は`requirements.txt`に記述します。

### デプロイ

Firebase CLIを使用してデプロイします。

```bash
firebase deploy --only functions
```

### コーディング規約

開発を進める際は、プロジェクトルートの [`AGENTS.md`](../AGENTS.md) に記載されているPythonに関する規約に従ってください。
特に、型ヒントの適用や非同期処理の適切な利用が求められます。
