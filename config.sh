#!/bin/bash
#
# config.sh
# Shared configuration for initial_setup_infra.sh
#

# --- Basic Settings ---
export GOOGLE_CLOUD_LOCATION="asia-northeast1"

# --- Service Names ---
export BACKEND_SERVICE_NAME="coco-ai-bidi-streaming-backend"

# --- Service Account Names ---
export BACKEND_SA_NAME="coco-ai-bidi-backend-sa"
export CLOUDBUILD_SA_NAME="coco-ai-bidi-cloudbuild-sa"

# --- Resource Names ---
export IMAGE_JOBS_COLLECTION="image_jobs"
export USERS_COLLECTION="users"
export CHATS_COLLECTION="chats"
export MESSAGES_COLLECTION="messages"
export ARTIFACT_REGISTRY_REPO="coco-ai-bidi-streaming"

# --- Buckets ---
if [ -n "$GOOGLE_CLOUD_PROJECT" ]; then
    export GCS_BUCKET_NAME="${GOOGLE_CLOUD_PROJECT}-generated-images"

    # Derived Service Account Emails
    export SERVICE_ACCOUNT_EMAIL="${BACKEND_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
    export CLOUDBUILD_SERVICE_ACCOUNT_EMAIL="${CLOUDBUILD_SA_NAME}@${GOOGLE_CLOUD_PROJECT}.iam.gserviceaccount.com"
fi
