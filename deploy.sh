#!/bin/bash

# Strict error handling
set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Load environment variables from .env if it exists
if [ -f .env ]; then
    log_info "Loading environment variables from .env file"
    set -a
    source .env
    set +a
fi

# Required environment variables
REQUIRED_VARS=("PROJECT_ID" "REGION" "JWT_SECRET_KEY")

for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

# Optional environment variables with defaults
SERVICE_NAME="${SERVICE_NAME:-gcp-bearer-auth-service}"
JWT_SECRET_NAME="${JWT_SECRET_NAME:-jwt-secret-key}"
PORT="${PORT:-8080}"
MEMORY="${MEMORY:-512Mi}"
CPU="${CPU:-1}"
MAX_INSTANCES="${MAX_INSTANCES:-10}"
MIN_INSTANCES="${MIN_INSTANCES:-0}"
TIMEOUT="${TIMEOUT:-300}"
ALLOW_UNAUTHENTICATED="${ALLOW_UNAUTHENTICATED:-true}"

# Display configuration
log_info "Deployment Configuration:"
echo "  Project ID: ${PROJECT_ID}"
echo "  Region: ${REGION}"
echo "  Service Name: ${SERVICE_NAME}"
echo "  Memory: ${MEMORY}"
echo "  CPU: ${CPU}"
echo "  Max Instances: ${MAX_INSTANCES}"
echo "  Min Instances: ${MIN_INSTANCES}"
echo "  Timeout: ${TIMEOUT}s"
echo "  Allow Unauthenticated: ${ALLOW_UNAUTHENTICATED}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    log_error "gcloud CLI is not installed. Please install it first."
    exit 1
fi

# Set the active project
log_info "Setting active GCP project to ${PROJECT_ID}"
gcloud config set project "${PROJECT_ID}"

# Common gcloud project arguments
GCLOUD_PROJECT_ARGS=(--project="${PROJECT_ID}")

# Function to check and enable API if needed
ensure_api_enabled() {
    local api=$1
    local api_name=$2
    
    log_info "Checking if ${api_name} is enabled"
    if ! gcloud services list --enabled --filter="name:${api}" --format="value(name)" | grep -q "${api}"; then
        log_warning "${api_name} is not enabled. Enabling now..."
        gcloud services enable "${api}" "${GCLOUD_PROJECT_ARGS[@]}"
        log_info "${api_name} enabled successfully"
    else
        log_info "${api_name} is already enabled"
    fi
}

# Enable required APIs
ensure_api_enabled "cloudbuild.googleapis.com" "Cloud Build API"
ensure_api_enabled "run.googleapis.com" "Cloud Run API"
ensure_api_enabled "secretmanager.googleapis.com" "Secret Manager API"

# Store JWT secret in Secret Manager
log_info "Managing JWT secret in Secret Manager"

if gcloud secrets describe "${JWT_SECRET_NAME}" "${GCLOUD_PROJECT_ARGS[@]}" &>/dev/null; then
    log_info "Secret ${JWT_SECRET_NAME} already exists. Updating..."
    echo -n "${JWT_SECRET_KEY}" | gcloud secrets versions add "${JWT_SECRET_NAME}" \
        --data-file=- \
        "${GCLOUD_PROJECT_ARGS[@]}"
else
    log_info "Creating secret ${JWT_SECRET_NAME}"
    echo -n "${JWT_SECRET_KEY}" | gcloud secrets create "${JWT_SECRET_NAME}" \
        --data-file=- \
        --replication-policy="automatic" \
        "${GCLOUD_PROJECT_ARGS[@]}"
fi

# Build and submit to Cloud Build
log_info "Building container image with Cloud Build"

IMAGE_NAME="gcr.io/${PROJECT_ID}/${SERVICE_NAME}:latest"

gcloud builds submit \
    "${GCLOUD_PROJECT_ARGS[@]}" \
    --tag "${IMAGE_NAME}" \
    --timeout=600s

if [ $? -ne 0 ]; then
    log_error "Cloud Build failed"
    exit 1
fi

log_info "Container image built successfully: ${IMAGE_NAME}"

# Configure IAM permissions for the service account
log_info "Configuring service account permissions"
SERVICE_ACCOUNT="${SERVICE_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"

# Grant Cloud Run Viewer role to list services
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
  --member="serviceAccount:${SERVICE_ACCOUNT}" \
  --role="roles/run.viewer" \
  --condition=None 2>/dev/null || echo "Note: Service account permissions may need manual configuration"

# Deploy Cloud Run service
log_info "Deploying Cloud Run service ${SERVICE_NAME}"

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
  --set-env-vars "GCP_PROJECT_ID=${PROJECT_ID}"
  --set-env-vars "GCP_REGION=${REGION}"
)

# Add allow-unauthenticated flag if enabled
if [ "${ALLOW_UNAUTHENTICATED}" = "true" ]; then
    DEPLOY_ARGS+=(--allow-unauthenticated)
else
    DEPLOY_ARGS+=(--no-allow-unauthenticated)
fi

gcloud "${DEPLOY_ARGS[@]}"

if [ $? -ne 0 ]; then
    log_error "Cloud Run deployment failed"
    exit 1
fi

# Get the service URL
SERVICE_URL=$(gcloud run services describe "${SERVICE_NAME}" \
    --region="${REGION}" \
    "${GCLOUD_PROJECT_ARGS[@]}" \
    --format="value(status.url)")

log_info "═══════════════════════════════════════════════════════════════"
log_info "Deployment completed successfully!"
log_info "═══════════════════════════════════════════════════════════════"
echo ""
echo "Service URL: ${SERVICE_URL}"
echo ""
echo "To test the service:"
echo "  1. Generate a JWT token:"
echo "     python3 generate_jwt.py"
echo ""
echo "  2. Test the health endpoint:"
echo "     curl ${SERVICE_URL}/api/health"
echo ""
echo "  3. Test the secure endpoint:"
echo "     curl -H 'Authorization: Bearer <your-jwt-token>' ${SERVICE_URL}/api/secure"
echo ""
echo "  4. List Cloud Run services:"
echo "     curl -H 'Authorization: Bearer <your-jwt-token>' ${SERVICE_URL}/api/services"
echo ""
log_info "═══════════════════════════════════════════════════════════════"
