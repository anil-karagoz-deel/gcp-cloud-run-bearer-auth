#!/bin/bash

# Deployment script for Google Cloud Run
# Usage: ./deploy.sh

set -e

# Configuration
PROJECT_ID=${GCP_PROJECT_ID:-"your-gcp-project-id"}
SERVICE_NAME="gcp-bearer-auth-service"
REGION="us-central1"
BEARER_TOKEN=${BEARER_TOKEN:-"your-secret-token-here"}

echo "🚀 Starting deployment to Google Cloud Run..."
echo "Project ID: $PROJECT_ID"
echo "Service Name: $SERVICE_NAME"
echo "Region: $REGION"

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ Error: gcloud CLI is not installed"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Check if project ID is set
if [ "$PROJECT_ID" = "your-gcp-project-id" ]; then
    echo "❌ Error: Please set GCP_PROJECT_ID environment variable"
    echo "Example: export GCP_PROJECT_ID=my-project-123"
    exit 1
fi

# Set the project
echo "📋 Setting GCP project..."
gcloud config set project $PROJECT_ID

# Build the container image using Cloud Build
echo "🔨 Building container image..."
gcloud builds submit --tag gcr.io/$PROJECT_ID/$SERVICE_NAME

# Deploy to Cloud Run
echo "🚢 Deploying to Cloud Run..."
gcloud run deploy $SERVICE_NAME \
  --image gcr.io/$PROJECT_ID/$SERVICE_NAME \
  --platform managed \
  --region $REGION \
  --allow-unauthenticated \
  --set-env-vars BEARER_TOKEN=$BEARER_TOKEN \
  --port 8080 \
  --memory 512Mi \
  --cpu 1 \
  --max-instances 10 \
  --min-instances 0 \
  --timeout 300

# Get the service URL
echo "✅ Deployment complete!"
echo ""
echo "📍 Service URL:"
gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)'
echo ""
echo "🔑 To test the service:"
echo "curl -H \"Authorization: Bearer $BEARER_TOKEN\" \$(gcloud run services describe $SERVICE_NAME --region $REGION --format 'value(status.url)')/api/secure"
