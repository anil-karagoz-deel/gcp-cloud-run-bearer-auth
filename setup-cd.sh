#!/bin/bash

# Setup Continuous Deployment for GCP Cloud Run
# This script configures Cloud Build to automatically deploy on git push

set -euo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Load environment variables
if [ -f .env ]; then
    log_info "Loading environment from .env"
    set -a
    source .env
    set +a
fi

# Check required variables
REQUIRED_VARS=("PROJECT_ID" "REGION")
for var in "${REQUIRED_VARS[@]}"; do
    if [ -z "${!var:-}" ]; then
        log_error "Required environment variable $var is not set"
        exit 1
    fi
done

GITHUB_REPO="${GITHUB_REPO:-anil-karagoz-deel/gcp-cloud-run-bearer-auth}"
SERVICE_NAME="${SERVICE_NAME:-gcp-bearer-auth-service}"

log_info "═══════════════════════════════════════════════════════"
log_info "Setting up Continuous Deployment for Cloud Run"
log_info "═══════════════════════════════════════════════════════"
echo ""
echo "Project ID: ${PROJECT_ID}"
echo "Region: ${REGION}"
echo "Service: ${SERVICE_NAME}"
echo "GitHub Repo: ${GITHUB_REPO}"
echo ""

# Ensure Cloud Build API is enabled
log_info "Checking Cloud Build API"
if ! gcloud services list --enabled --filter="name:cloudbuild.googleapis.com" --format="value(name)" --project="${PROJECT_ID}" | grep -q "cloudbuild.googleapis.com"; then
    log_warning "Enabling Cloud Build API"
    gcloud services enable cloudbuild.googleapis.com --project="${PROJECT_ID}"
fi

# Grant Cloud Build service account necessary permissions
log_info "Configuring Cloud Build service account permissions"
PROJECT_NUMBER=$(gcloud projects describe "${PROJECT_ID}" --format="value(projectNumber)")
CLOUD_BUILD_SA="${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com"

# Grant Cloud Run Admin role to Cloud Build
log_info "Granting Cloud Run Admin role to Cloud Build service account"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${CLOUD_BUILD_SA}" \
    --role="roles/run.admin" \
    --condition=None 2>/dev/null || log_warning "Role may already exist"

# Grant Service Account User role (required to deploy as service account)
log_info "Granting Service Account User role to Cloud Build service account"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${CLOUD_BUILD_SA}" \
    --role="roles/iam.serviceAccountUser" \
    --condition=None 2>/dev/null || log_warning "Role may already exist"

# Grant Secret Manager Secret Accessor to Cloud Build (to deploy with secrets)
log_info "Granting Secret Manager access to Cloud Build service account"
gcloud projects add-iam-policy-binding "${PROJECT_ID}" \
    --member="serviceAccount:${CLOUD_BUILD_SA}" \
    --role="roles/secretmanager.secretAccessor" \
    --condition=None 2>/dev/null || log_warning "Role may already exist"

# Connect GitHub repository to Cloud Build (interactive)
log_info "═══════════════════════════════════════════════════════"
log_info "Next Steps: Connect GitHub Repository"
log_info "═══════════════════════════════════════════════════════"
echo ""
echo "To set up continuous deployment, you need to:"
echo ""
echo "1. Connect your GitHub repository to Cloud Build:"
echo "   gcloud builds triggers create github \\"
echo "     --name=\"deploy-${SERVICE_NAME}\" \\"
echo "     --repo-name=\"gcp-cloud-run-bearer-auth\" \\"
echo "     --repo-owner=\"anil-karagoz-deel\" \\"
echo "     --branch-pattern=\"^main$\" \\"
echo "     --build-config=\"cloudbuild.yaml\" \\"
echo "     --region=\"${REGION}\" \\"
echo "     --project=\"${PROJECT_ID}\""
echo ""
echo "2. Or use the Cloud Console:"
echo "   https://console.cloud.google.com/cloud-build/triggers?project=${PROJECT_ID}"
echo "   - Click 'Connect Repository'"
echo "   - Select GitHub and authorize"
echo "   - Choose your repository: ${GITHUB_REPO}"
echo "   - Create trigger with cloudbuild.yaml"
echo ""
echo "3. Once connected, every push to 'main' branch will automatically deploy!"
echo ""
log_info "═══════════════════════════════════════════════════════"

# Check if GitHub App is already connected
log_info "Checking for existing GitHub connections..."
CONNECTIONS=$(gcloud builds connections list --region="${REGION}" --project="${PROJECT_ID}" --format="value(name)" 2>/dev/null || echo "")

if [ -z "$CONNECTIONS" ]; then
    log_warning "No GitHub connections found. You'll need to connect GitHub first."
    echo ""
    echo "Run this command to connect GitHub (it will open a browser):"
    echo ""
    echo "gcloud builds connections create github \"github-connection\" \\"
    echo "  --region=\"${REGION}\" \\"
    echo "  --project=\"${PROJECT_ID}\""
    echo ""
else
    log_info "Found existing connections:"
    echo "${CONNECTIONS}"
fi

log_info "═══════════════════════════════════════════════════════"
log_info "Setup complete! Cloud Build service account configured."
log_info "═══════════════════════════════════════════════════════"
