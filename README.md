# coco-ai-bidi-streaming

## ディレクトリ構成

このプロジェクトは、以下のディレクトリで構成されています。

-   `./app`: Flutter (Web) で構築されたフロントエンドクライアントアプリケーション。UI、マイク入力、音声再生などを担当します。
-   `./agent`: Python (FastAPI, ADK) で構築されたコアバックエンドエージェント。WebSocket接続を管理し、Gemini Live APIとの音声ストリーム中継やビジネスロジックを担当します。

## Cloud Shell でのセットアップ手順

`config.sh` と `initial_setup_infra.sh` を使用して、Google Cloud プロジェクトの初期設定を行う手順です。

1.  Cloud Shell を開き、`config.sh` と `initial_setup_infra.sh` をアップロードします。
2.  以下のコマンドを実行して、権限の設定とスクリプトの実行を行います。

```bash
# 実行権限の付与 (アップロード直後は権限がない場合があるため必須)
chmod +x config.sh initial_setup_infra.sh

# プロジェクトIDの設定 (ご自身のプロジェクトIDに置き換えてください)
export GOOGLE_CLOUD_PROJECT="YOUR_PROJECT_ID"

# インフラセットアップスクリプトの実行
./initial_setup_infra.sh
```

> **Note**: `YOUR_PROJECT_ID` は実際の Google Cloud プロジェクト ID に置き換えてください。

## 手動設定手順 (スクリプト実行後)

`initial_setup_infra.sh` の実行後、以下の手順を手動で行う必要があります。

### 1. Secret Manager の値設定
スクリプトはプレースホルダー値でシークレットを作成します。Google Cloud コンソールの Secret Manager から、以下のシークレットに正しい値を設定（新しいバージョンを追加）してください。

- `FIREBASE_API_KEY`
- `FIREBASE_APP_ID`
- `FIREBASE_MESSAGING_SENDER_ID`
- `FIREBASE_PROJECT_ID`
- `FIREBASE_STORAGE_BUCKET`
- `FIREBASE_AUTH_DOMAIN`

### 2. Firebase Storage へのバケットインポート
スクリプトで作成された GCS バケットを Firebase SDK から利用可能にするため、Firebase コンソールでインポートが必要です。

1. Firebase コンソール を開きます。
2. 左メニューの **Storage** を選択します。
3. **「バケットをインポート」** (または類似のオプション) を選択し、スクリプトで作成されたバケット (`YOUR_PROJECT_ID-generated-images`) を選択してインポートします。

### 3. Vertex AI Agent Engine の手動作成
セッション管理用の Agent Engine インスタンスは、現時点で `gcloud` コマンドだけで作成することが難しいため、以下の Python スクリプトを実行して作成してください。

この方法では、`identity_type=AGENT_IDENTITY` を使用して**コードをデプロイせずにIDのみを持つインスタンス**を作成します。これにより、事前にIAM権限を設定することが可能です。

Cloud Shell またはローカル環境で、`google-cloud-aiplatform` ライブラリをインストール後に実行します。

```bash
pip install google-cloud-aiplatform
```

```python
import vertexai
from vertexai import types
import os

# プロジェクトIDとロケーションを設定
PROJECT_ID = os.environ.get("GOOGLE_CLOUD_PROJECT", "YOUR_PROJECT_ID")
LOCATION = "asia-northeast1"

# Clientの初期化 (v1beta1 APIを使用)
client = vertexai.Client(
    project=PROJECT_ID,
    location=LOCATION,
    http_options=dict(api_version="v1beta1")
)

# Agent Engine インスタンスの作成 (コードなし、IDのみ)
try:
    print("Creating Agent Engine (Identity Only)...")

    remote_agent = client.agent_engines.create(
        config={
            "identity_type": types.IdentityType.AGENT_IDENTITY
        }
    )

    print("✅ Created successfully.")
    print(f"Resource Name: {remote_agent.name}")

except Exception as e:
    print(f"Error creating Agent Engine: {e}")
```

> **Note**: 作成後に表示される `Resource Name` から Agent Engine ID (例: `1234567890123456789`) を取得し、`cloudbuild.yaml` の `_VERTEX_AI_AGENT_ENGINE_ID` に設定してください。

### 4. Cloud Build トリガーの手動作成
GitHub リポジトリとの連携およびトリガーの作成は手動で行う必要があります。

1. Google Cloud コンソールの Cloud Build トリガーページを開きます。
2. **「リポジトリを接続」** をクリックし、このプロジェクトの GitHub リポジトリを接続します。
3. **「トリガーを作成」** をクリックし、以下の設定でトリガーを作成します。
    - **名前**: `deploy-pipeline` (任意)
    - **イベント**: 例: ブランチへの push
    - **ソース**: 接続したリポジトリとブランチ (例: `main`)
    - **構成**: Cloud Build 構成ファイル (yaml または json)
    - **場所**: `cloudbuild.yaml` (リポジトリルート)
4. (オプション) 作成したトリガーを実行し、デプロイが成功することを確認します。

## 今後の実装予定

### セキュリティ強化
- **Firebase App Check の導入:**
    - 現在は Cloud Run へのアクセスをアプリケーション層（IDトークン検証）と `--max-instances 1` で保護していますが、将来的には Firebase App Check を導入し、承認されていないクライアント（Bot等）からのアクセスを遮断する予定です。
    - WebSocket 接続時にもクエリパラメータ等を用いて App Check トークンを検証するロジックを実装します。