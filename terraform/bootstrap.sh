#!/usr/bin/env bash
# One-time: create a versioned, private GCS bucket for Terraform state.
set -euo pipefail

PROJECT_ID="${1:?usage: bootstrap.sh <project-id> [region]}"
REGION="${2:-us-east1}"
BUCKET="${PROJECT_ID}-tfstate"

gcloud config set project "$PROJECT_ID"
gcloud services enable storage.googleapis.com

if ! gcloud storage buckets describe "gs://${BUCKET}" >/dev/null 2>&1; then
  gcloud storage buckets create "gs://${BUCKET}" \
    --location="$REGION" \
    --uniform-bucket-level-access \
    --public-access-prevention
  gcloud storage buckets update "gs://${BUCKET}" --versioning
fi

echo "State bucket ready: ${BUCKET}"
echo "Run: cd envs/dev && terraform init -backend-config=\"bucket=${BUCKET}\""
