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

echo "--- Loading Configuration ---"
# Load shared configuration
source "$(dirname "$0")/config.sh"

echo "--- Configuration Summary ---"
echo "Project: $GOOGLE_CLOUD_PROJECT"
echo "Location: $GOOGLE_CLOUD_LOCATION"
echo "Registry: $ARTIFACT_REGISTRY_REPO"
echo "Backend Svc: $BACKEND_SERVICE_NAME"
echo "Generated Images Bucket: $GCS_BUCKET_NAME"
echo "-------------------"

# Set current project
gcloud config set project ${GOOGLE_CLOUD_PROJECT}

# --- 1. Enable Required APIs ---
echo "--- Enabling Required APIs ---"
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
     echo "API ${API} is already enabled."
  else
     echo "Enabling API: ${API}..."
     gcloud services enable ${API}
  fi
done

# --- 2. Create/Configure Cloud Storage Buckets ---
echo "--- Configuring Cloud Storage Buckets ---"

create_bucket_if_not_exists() {
  local bucket_name=$1
  if gcloud storage buckets describe gs://${bucket_name} >/dev/null 2>&1; then
    echo "Bucket gs://${bucket_name} already exists."
  else
    echo "Creating bucket gs://${bucket_name}..."
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
# 1. Firebase コンソール > Storage を開く
# 2. 「バケットを追加」>「既存の Google Cloud Storage バケットをインポートする」を選択
# 3. 作成したバケットを選択してインポート

# Apply CORS configurations
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
echo "--- Configuring Artifact Registry: ${ARTIFACT_REGISTRY_REPO} ---"
if gcloud artifacts repositories describe ${ARTIFACT_REGISTRY_REPO} --location=${GOOGLE_CLOUD_LOCATION} >/dev/null 2>&1; then
  echo "Repository ${ARTIFACT_REGISTRY_REPO} already exists."
else
  echo "Creating repository ${ARTIFACT_REGISTRY_REPO}..."
  gcloud artifacts repositories create ${ARTIFACT_REGISTRY_REPO} \
    --repository-format=docker \
    --location=${GOOGLE_CLOUD_LOCATION} \
    --description="Docker repository for Coco-AI-Bidi-Streaming"
fi

# --- 4. Firestore ---
echo "--- Configuring Firestore ---"
if ! gcloud firestore databases describe --project=${GOOGLE_CLOUD_PROJECT} >/dev/null 2>&1; then
  echo "Creating Firestore database in Native mode..."
  gcloud firestore databases create --location=${GOOGLE_CLOUD_LOCATION} --project=${GOOGLE_CLOUD_PROJECT}
else
  echo "Firestore database already exists."
fi

# --- 5. Secret Manager ---
echo "--- Configuring Secret Manager ---"
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
    echo "Secret ${SECRET} already exists."
  else
    echo "Creating secret ${SECRET}..."
    gcloud secrets create ${SECRET} --replication-policy="automatic"
    echo "placeholder_value" | gcloud secrets versions add ${SECRET} --data-file=-
    echo "Warning: Created placeholder version for ${SECRET}. Please update via Console."
  fi
done

# --- 6. Service Accounts ---
echo "--- Configuring Service Accounts ---"

# Service Account definitions are loaded from config.sh
# We verify and create them here.

SERVICE_ACCOUNTS=(
  "${BACKEND_SA_NAME}|Coco-Ai-Bidi-Streaming Backend SA"
  "${CLOUDBUILD_SA_NAME}|Coco-Ai-Bidi-Streaming Cloud Build SA"
)

for sa in "${SERVICE_ACCOUNTS[@]}"; do
  IFS='|' read -r name display_name <<< "$sa"
  email="${name}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
  
  if ! gcloud iam service-accounts describe ${email} >/dev/null 2>&1; then
    echo "Creating service account: ${name}"
    gcloud iam service-accounts create ${name} --display-name="${display_name}"
  else
    echo "Service account ${name} already exists."
  fi
done

# --- 7. IAM Role Assignment ---
echo "--- Assigning IAM Roles ---"

# Helper to add project IAM binding safely
add_iam_binding() {
  local member=$1
  local role=$2
  gcloud projects add-iam-policy-binding ${GOOGLE_CLOUD_PROJECT} \
    --member="${member}" \
    --role="${role}" >/dev/null
}

# --- Backend Service Account Roles ---
echo "Configuring Backend SA Roles (${SERVICE_ACCOUNT_EMAIL})..."
BACKEND_ROLES=(
  "roles/logging.logWriter"
  "roles/aiplatform.user"
  "roles/datastore.user"
)
for role in "${BACKEND_ROLES[@]}"; do add_iam_binding "serviceAccount:${SERVICE_ACCOUNT_EMAIL}" "$role"; done

# Bucket specific roles for Backend
gcloud storage buckets add-iam-policy-binding gs://${GCS_BUCKET_NAME} --member="serviceAccount:${SERVICE_ACCOUNT_EMAIL}" --role="roles/storage.objectAdmin" >/dev/null

# --- Cloud Build Service Account Roles ---
echo "Configuring Cloud Build SA Roles (${CLOUDBUILD_SERVICE_ACCOUNT_EMAIL})..."
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

echo "✅ Infrastructure setup complete (Idempotent run)."
