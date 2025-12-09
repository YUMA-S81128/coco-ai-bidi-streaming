#!/bin/bash
set -e

# --- Initial Setup for Coco-AI-Bidi-Streaming Infrastructure ---
# This script sets up the necessary infrastructure on Google Cloud.
# It is designed to be idempotent and can be re-run safely.

# --- Prerequisites ---
# Ensure you have the following environment variables set before running:
# export GOOGLE_CLOUD_PROJECT="your-project-id"

if [ -z "$GOOGLE_CLOUD_PROJECT" ]; then
  echo "ERROR: GOOGLE_CLOUD_PROJECT is not set."
  echo "Please export GOOGLE_CLOUD_PROJECT='your-project-id' and retry."
  exit 1
fi

echo "--- 設定読み込み中 ---"
# 共通設定の読み込み
source "$(dirname "$0")/config.sh"

echo "--- 設定概要 ---"
echo "プロジェクト: $GOOGLE_CLOUD_PROJECT"
echo "ロケーション: $GOOGLE_CLOUD_LOCATION"
echo "レジストリ: $ARTIFACT_REGISTRY_REPO"
echo "バックエンドサービス: $BACKEND_SERVICE_NAME"
echo "生成画像バケット: $GCS_BUCKET_NAME"
echo "-------------------"

# カレントプロジェクトの設定
gcloud config set project ${GOOGLE_CLOUD_PROJECT}

# --- 1. 必要なAPIの有効化 ---
echo "--- 必要なAPIを有効化しています ---"
REQUIRED_APIS=(
  "artifactregistry.googleapis.com"
  "cloudbuild.googleapis.com"
  "run.googleapis.com"
  "firestore.googleapis.com"
  "storage.googleapis.com" # Cloud Storage API
  "storage-component.googleapis.com" # Cloud Storage for Firebase
  "aiplatform.googleapis.com"
  "secretmanager.googleapis.com"
  "cloudresourcemanager.googleapis.com" # IAMポリシー変更に必要
  "iam.googleapis.com"
  "serviceusage.googleapis.com" # APIの有効化に必要
)

for API in "${REQUIRED_APIS[@]}"; do
  if gcloud services list --enabled --filter="config.name:${API}" --format="value(config.name)" | grep -q "${API}"; then
     echo "API ${API} は既に有効です。"
  else
     echo "APIを有効化しています: ${API}..."
     gcloud services enable ${API}
  fi
done

# --- Vertex AI Agent Engine (セッション管理用) ---
# 以下の Python コードで Agent Engine インスタンスを作成してください:
#
#   from google import genai
#   client = genai.Client(vertexai=True, project="${GOOGLE_CLOUD_PROJECT}", location="${GOOGLE_CLOUD_LOCATION}")
#   agent_engine = client.agent_engines.create(
#       display_name="coco-ai-bidi-session-service",
#       description="Session management for Coco-AI Bidi Streaming"
#   )
#   print(f"Agent Engine ID: {agent_engine.name}")


# --- 2. Cloud Storage バケットの作成/設定 ---
echo "--- Cloud Storage バケットを設定しています ---"

create_bucket_if_not_exists() {
  local bucket_name=$1
  if gcloud storage buckets describe gs://${bucket_name} >/dev/null 2>&1; then
    echo "バケット gs://${bucket_name} は既に存在します。"
  else
    echo "バケット gs://${bucket_name} を作成しています..."
    gcloud storage buckets create gs://${bucket_name} \
      --project=${GOOGLE_CLOUD_PROJECT} \
      --location=${GOOGLE_CLOUD_LOCATION} \
      --uniform-bucket-level-access \
      --public-access-prevention
  fi
}

create_bucket_if_not_exists ${GCS_BUCKET_NAME}

# [重要] Firebase 連携の手動手順
# このスクリプトで作成したバケットを Firebase Storage (クライアントSDK) から利用するには、
# Firebase コンソールから手動でインポート（紐付け）を行う必要があります。

# CORS設定の適用
echo "--- 画像表示用バケットにCORS設定を適用中 ---"
# フロントエンド（Firebase Hosting）からの画像読み込みを許可するためのCORS設定
IMAGE_CORS_CONFIG_FILE=$(mktemp)
cat > "${IMAGE_CORS_CONFIG_FILE}" <<EOF
[
  {
    "origin": [
      "https://${GOOGLE_CLOUD_PROJECT}.web.app"
    ],
    "method": ["GET"],
    "maxAgeSeconds": 3600
  }
]
EOF
gcloud storage buckets update gs://${GCS_BUCKET_NAME} --cors-file="${IMAGE_CORS_CONFIG_FILE}"

rm "${IMAGE_CORS_CONFIG_FILE}"

# --- 3. Artifact Registry ---
echo "--- Artifact Registry を設定しています: ${ARTIFACT_REGISTRY_REPO} ---"
if gcloud artifacts repositories describe ${ARTIFACT_REGISTRY_REPO} --location=${GOOGLE_CLOUD_LOCATION} >/dev/null 2>&1; then
  echo "リポジトリ ${ARTIFACT_REGISTRY_REPO} は既に存在します。"
else
  echo "リポジトリ ${ARTIFACT_REGISTRY_REPO} を作成しています..."
  gcloud artifacts repositories create ${ARTIFACT_REGISTRY_REPO} \
    --repository-format=docker \
    --location=${GOOGLE_CLOUD_LOCATION} \
    --description="Docker repository for Coco-AI-Bidi-Streaming"
fi

# --- 4. Firestore ---
echo "--- Firestore を設定しています ---"
if ! gcloud firestore databases describe --project=${GOOGLE_CLOUD_PROJECT} >/dev/null 2>&1; then
  echo "Firestore データベース (Nativeモード) を作成しています..."
  gcloud firestore databases create --location=${GOOGLE_CLOUD_LOCATION} --project=${GOOGLE_CLOUD_PROJECT}
else
  echo "Firestore データベースは既に存在します。"
fi

# --- 5. Secret Manager ---
echo "--- Secret Manager を設定しています ---"
SECRET_KEYS=(
  "FIREBASE_API_KEY"
  "FIREBASE_APP_ID"
  "FIREBASE_MESSAGING_SENDER_ID"
  "FIREBASE_PROJECT_ID"
  "FIREBASE_STORAGE_BUCKET"
  "FIREBASE_AUTH_DOMAIN"
)

for SECRET in "${SECRET_KEYS[@]}"; do
  if gcloud secrets describe ${SECRET} >/dev/null 2>&1; then
    echo "シークレット ${SECRET} は既に存在します。"
  else
    echo "シークレット ${SECRET} を作成しています..."
    gcloud secrets create ${SECRET} --replication-policy="automatic"
    echo "placeholder_value" | gcloud secrets versions add ${SECRET} --data-file=-
    echo "警告: ${SECRET} のプレースホルダーバージョンを作成しました。コンソールから更新してください。"
  fi
done

# --- 6. サービスアカウント ---
echo "--- サービスアカウントを設定しています ---"

# サービスアカウント定義は config.sh からロード済み
# ここで検証と作成を行う

SERVICE_ACCOUNTS=(
  "${BACKEND_SA_NAME}|Coco-Ai-Bidi-Streaming Backend SA"
  "${CLOUDBUILD_SA_NAME}|Coco-Ai-Bidi-Streaming Cloud Build SA"
)

for sa in "${SERVICE_ACCOUNTS[@]}"; do
  IFS='|' read -r name display_name <<< "$sa"
  email="${name}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
  
  if ! gcloud iam service-accounts describe ${email} >/dev/null 2>&1; then
    echo "サービスアカウントを作成しています: ${name}"
    gcloud iam service-accounts create ${name} --display-name="${display_name}"
  else
    echo "サービスアカウント ${name} は既に存在します。"
  fi
done

# --- 7. IAM ロール割り当て ---
echo "--- IAM ロールを割り当てています ---"

# プロジェクトIAMバインディングを安全に追加するヘルパー関数
add_iam_binding() {
  local member=$1
  local role=$2
  gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
    --member="${member}" \
    --role="${role}" >/dev/null
}

# --- バックエンドサービスアカウントのロール ---
echo "バックエンドSAのロールを設定中 (${SERVICE_ACCOUNT_EMAIL})..."
BACKEND_ROLES=(
  "roles/logging.logWriter"
  "roles/aiplatform.user"
  "roles/datastore.user"
)
for role in "${BACKEND_ROLES[@]}"; do add_iam_binding "serviceAccount:${SERVICE_ACCOUNT_EMAIL}" "$role"; done

# バックエンド用バケット固有ロール
gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET_NAME} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/storage.objectAdmin" >/dev/null

# --- Cloud Build サービスアカウントのロール ---
echo "Cloud Build SAのロールを設定中 (${CLOUDBUILD_SERVICE_ACCOUNT_EMAIL})..."
CLOUDBUILD_ROLES=(
  "roles/logging.logWriter"
  "roles/cloudbuild.builds.editor"
  "roles/run.admin"
  "roles/iam.serviceAccountUser"
  "roles/datastore.indexAdmin"
  "roles/firebaserules.admin"
  "roles/firebasehosting.admin"
  "roles/artifactregistry.writer"
  "roles/firebase.viewer"
  "roles/firebasestorage.admin"
  "roles/storage.objectAdmin"
  "roles/secretmanager.secretAccessor"
)
for role in "${CLOUDBUILD_ROLES[@]}"; do add_iam_binding "serviceAccount:${CLOUDBUILD_SERVICE_ACCOUNT_EMAIL}" "$role"; done

echo "✅ インフラストラクチャのセットアップが完了しました (冪等実行)。"
