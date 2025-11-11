#!/usr/bin/env bash

# Deployment script for Google Cloud Run Bearer Auth Service
# Usage: ./deploy.sh

set -euo pipefail

# Load environment variables from .env if it exists
if [[ -f ".env" ]]; then
  echo "▶ Loading environment from .env"
  set -a
  # shellcheck disable=SC1091
  source ".env"
  set +a
fi

# Utility function to check for required commands
require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "❌ Missing required command: $1" >&2
    exit 1
  fi
}

require_command gcloud

# Required environment variables
: "${PROJECT_ID:?Set PROJECT_ID in your environment or .env file}"
: "${REGION:?Set REGION in your environment or .env file}"
: "${JWT_SECRET_KEY:?Set JWT_SECRET_KEY to your secret key value}"

# Optional overrides
SERVICE_NAME="${SERVICE_NAME:-gcp-bearer-auth-service}"
IMAGE_NAME="${IMAGE_NAME:-gcr.io/${PROJECT_ID}/${SERVICE_NAME}}"
JWT_SECRET_NAME="${JWT_SECRET_NAME:-jwt-secret-key}"
PORT="${PORT:-8080}"
MEMORY="${MEMORY:-512Mi}"
CPU="${CPU:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-10}"
MIN_INSTANCES="${MIN_INSTANCES:-0}"
TIMEOUT="${TIMEOUT:-300}"
ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED:-true}"

GCLOUD_PROJECT_ARGS=(--project "${PROJECT_ID}")

echo "🚀 Starting deployment to Google Cloud Run"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Project ID: ${PROJECT_ID}"
echo "Service Name: ${SERVICE_NAME}"
echo "Region: ${REGION}"
echo "Image: ${IMAGE_NAME}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Function to ensure a Google Cloud API is enabled
ensure_api_enabled() {
  local api="$1"
  if ! gcloud "${GCLOUD_PROJECT_ARGS[@]}" services list --enabled --format="value(config.name)" | grep -qx "${api}"; then
    echo "▶ Enabling API ${api}"
    gcloud "${GCLOUD_PROJECT_ARGS[@]}" services enable "${api}"
  else
    echo "✔ API ${api} already enabled"
  fi
}

echo ""
echo "▶ Verifying required Google APIs"
ensure_api_enabled secretmanager.googleapis.com
ensure_api_enabled cloudbuild.googleapis.com
ensure_api_enabled run.googleapis.com

echo ""
echo "▶ Managing JWT secret key in Secret Manager"
if gcloud "${GCLOUD_PROJECT_ARGS[@]}" secrets describe "${JWT_SECRET_NAME}" >/dev/null 2>&1; then
  echo "✔ Secret ${JWT_SECRET_NAME} exists, updating with new version"
  printf "%s" "${JWT_SECRET_KEY}" | gcloud "${GCLOUD_PROJECT_ARGS[@]}" secrets versions add "${JWT_SECRET_NAME}" --data-file=-
else
  echo "✔ Creating new secret ${JWT_SECRET_NAME}"
  printf "%s" "${JWT_SECRET_KEY}" | gcloud "${GCLOUD_PROJECT_ARGS[@]}" secrets create "${JWT_SECRET_NAME}" --replication-policy=automatic --data-file=-
fi

echo ""
echo "▶ Building container image ${IMAGE_NAME}"
gcloud "${GCLOUD_PROJECT_ARGS[@]}" builds submit --tag "${IMAGE_NAME}"

echo ""
echo "▶ Deploying Cloud Run service ${SERVICE_NAME}"

DEPLOY_ARGS=(
  "${GCLOUD_PROJECT_ARGS[@]}"
  run deploy "${SERVICE_NAME}"
  --image "${IMAGE_NAME}"
  --platform managed
  --region "${REGION}"
  --port "${PORT}"
  --memory "${MEMORY}"
  --cpu "${CPU}"
  --max-instances "${MAX_INSTANCES}"
  --min-instances "${MIN_INSTANCES}"
  --timeout "${TIMEOUT}"
  --update-secrets "JWT_SECRET_KEY=${JWT_SECRET_NAME}:latest"
)

if [[ "${ALLOW_UNAUTHENTICATED}" == "true" ]]; then
  DEPLOY_ARGS+=(--allow-unauthenticated)
else
  DEPLOY_ARGS+=(--no-allow-unauthenticated)
fi

gcloud "${DEPLOY_ARGS[@]}"

echo ""
echo "✅ Deployment complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

SERVICE_URL=$(gcloud "${GCLOUD_PROJECT_ARGS[@]}" run services describe "${SERVICE_NAME}" --region "${REGION}" --format 'value(status.url)')

echo ""
echo "📍 Service URL:"
echo "   ${SERVICE_URL}"
echo ""
echo "🔑 Test the service:"
echo "   # Health check (public)"
echo "   curl ${SERVICE_URL}/api/health"
echo ""
echo "   # Generate a JWT token first:"
echo "   python3 generate_jwt.py --secret ${JWT_SECRET_KEY}"
echo ""
echo "   # Then test secure endpoint with JWT (use token from generator):"
echo "   curl -H \"Authorization: Bearer YOUR_JWT_TOKEN\" ${SERVICE_URL}/api/secure"
echo ""
echo "ℹ️  JWT secret key stored in Secret Manager: ${JWT_SECRET_NAME}"
