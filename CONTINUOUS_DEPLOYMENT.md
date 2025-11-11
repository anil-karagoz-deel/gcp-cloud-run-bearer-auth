# Continuous Deployment Setup for Cloud Run

This guide explains how to set up automatic deployments to Google Cloud Run whenever you push code to GitHub.

## Overview

You have several options for continuous deployment:

### Option 1: Cloud Build Triggers (Recommended) ⭐
- Automatic deployment on git push
- Built-in integration with GitHub
- Free tier: 120 build-minutes/day
- Managed by Google Cloud

### Option 2: GitHub Actions
- More flexible workflow control
- Runs in GitHub's infrastructure
- Good for multi-cloud deployments

### Option 3: Manual Deployment
- Run `./deploy.sh` manually
- Full control over timing
- Good for testing/development

---

## Option 1: Cloud Build Triggers Setup

### Prerequisites
- GitHub repository created ✓ (anil-karagoz-deel/gcp-cloud-run-bearer-auth)
- `cloudbuild.yaml` file ✓ (already in your repo)
- Admin access to GCP project (to grant permissions)

### Step 1: Configure Cloud Build Permissions

Run the setup script:
```bash
./setup-cd.sh
```

This script will:
- Enable Cloud Build API
- Grant necessary IAM roles to Cloud Build service account:
  - `roles/run.admin` - Deploy to Cloud Run
  - `roles/iam.serviceAccountUser` - Act as service account
  - `roles/secretmanager.secretAccessor` - Access JWT secret

### Step 2: Connect GitHub Repository

You have two options:

#### Option A: Using gcloud CLI (Automated)
```bash
# Create GitHub connection
gcloud builds connections create github "github-connection" \
  --region="us-central1" \
  --project="it-automation-training"

# This will open a browser to authorize GitHub access
# Follow the prompts to connect your GitHub account

# Create the trigger
gcloud builds triggers create github \
  --name="deploy-gcp-bearer-auth-service" \
  --repo-name="gcp-cloud-run-bearer-auth" \
  --repo-owner="anil-karagoz-deel" \
  --branch-pattern="^main$" \
  --build-config="cloudbuild.yaml" \
  --region="us-central1" \
  --project="it-automation-training"
```

#### Option B: Using Cloud Console (Manual)
1. Go to: https://console.cloud.google.com/cloud-build/triggers?project=it-automation-training
2. Click **"CREATE TRIGGER"**
3. Configure:
   - **Name**: `deploy-gcp-bearer-auth-service`
   - **Event**: Push to a branch
   - **Source**: Connect Repository → GitHub → Authorize
   - **Repository**: `anil-karagoz-deel/gcp-cloud-run-bearer-auth`
   - **Branch**: `^main$`
   - **Configuration**: Cloud Build configuration file (yaml or json)
   - **Location**: `/cloudbuild.yaml`
4. Click **CREATE**

### Step 3: Test the Pipeline

```bash
# Make a small change
echo "# Test deployment" >> README.md

# Commit and push
git add README.md
git commit -m "test: trigger cloud build deployment"
git push origin main
```

Watch the build:
```bash
# View builds in real-time
gcloud builds list --project=it-automation-training --limit=5

# Stream logs for the latest build
gcloud builds log $(gcloud builds list --limit=1 --format="value(id)") \
  --project=it-automation-training --stream
```

Or view in console:
https://console.cloud.google.com/cloud-build/builds?project=it-automation-training

---

## Option 2: GitHub Actions Setup

If you prefer GitHub Actions instead of Cloud Build:

### Step 1: Create Service Account Key

```bash
# Create service account for GitHub Actions
gcloud iam service-accounts create github-actions-deployer \
  --display-name="GitHub Actions Deployer" \
  --project=it-automation-training

# Grant necessary roles
SA_EMAIL="github-actions-deployer@it-automation-training.iam.gserviceaccount.com"

gcloud projects add-iam-policy-binding it-automation-training \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/run.admin"

gcloud projects add-iam-policy-binding it-automation-training \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/iam.serviceAccountUser"

gcloud projects add-iam-policy-binding it-automation-training \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.admin"

# Create and download key (keep this secure!)
gcloud iam service-accounts keys create ~/github-actions-key.json \
  --iam-account="${SA_EMAIL}" \
  --project=it-automation-training

# Display the key (copy this for GitHub secrets)
cat ~/github-actions-key.json
```

### Step 2: Add GitHub Secrets

1. Go to: https://github.com/anil-karagoz-deel/gcp-cloud-run-bearer-auth/settings/secrets/actions
2. Add secrets:
   - `GCP_PROJECT_ID`: `it-automation-training`
   - `GCP_SA_KEY`: (paste the JSON key from above)
   - `JWT_SECRET_KEY`: (your JWT secret)

### Step 3: Create GitHub Actions Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Cloud Run

on:
  push:
    branches:
      - main

env:
  PROJECT_ID: ${{ secrets.GCP_PROJECT_ID }}
  SERVICE_NAME: gcp-bearer-auth-service
  REGION: us-central1

jobs:
  deploy:
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout code
      uses: actions/checkout@v3
    
    - name: Authenticate to Google Cloud
      uses: google-github-actions/auth@v1
      with:
        credentials_json: ${{ secrets.GCP_SA_KEY }}
    
    - name: Set up Cloud SDK
      uses: google-github-actions/setup-gcloud@v1
    
    - name: Configure Docker for GCR
      run: gcloud auth configure-docker
    
    - name: Build Docker image
      run: |
        docker build -t gcr.io/$PROJECT_ID/$SERVICE_NAME:$GITHUB_SHA .
    
    - name: Push to Container Registry
      run: |
        docker push gcr.io/$PROJECT_ID/$SERVICE_NAME:$GITHUB_SHA
    
    - name: Deploy to Cloud Run
      run: |
        gcloud run deploy $SERVICE_NAME \
          --image gcr.io/$PROJECT_ID/$SERVICE_NAME:$GITHUB_SHA \
          --region $REGION \
          --platform managed \
          --allow-unauthenticated \
          --set-env-vars "JWT_SECRET_KEY=${{ secrets.JWT_SECRET_KEY }}" \
          --set-env-vars "GCP_PROJECT_ID=$PROJECT_ID" \
          --set-env-vars "GCP_REGION=$REGION"
```

---

## Current cloudbuild.yaml Configuration

Your `cloudbuild.yaml` is configured to:
1. Build Docker image with commit SHA tag
2. Push to Google Container Registry (GCR)
3. Deploy to Cloud Run with:
   - Secret Manager integration for JWT_SECRET_KEY
   - Environment variables for GCP_PROJECT_ID and GCP_REGION
   - Allow unauthenticated access

---

## Monitoring Deployments

### View Build History
```bash
# List recent builds
gcloud builds list --limit=10 --project=it-automation-training

# View specific build details
gcloud builds describe BUILD_ID --project=it-automation-training

# Stream logs
gcloud builds log BUILD_ID --project=it-automation-training --stream
```

### View Cloud Run Deployments
```bash
# List services
gcloud run services list --project=it-automation-training --region=us-central1

# View service details
gcloud run services describe gcp-bearer-auth-service \
  --project=it-automation-training \
  --region=us-central1

# View recent revisions
gcloud run revisions list --service=gcp-bearer-auth-service \
  --project=it-automation-training \
  --region=us-central1
```

---

## Rollback Strategy

If a deployment fails or has issues:

### Option 1: Rollback via Console
1. Go to Cloud Run service page
2. Click "REVISIONS AND TRAFFIC" tab
3. Select previous working revision
4. Click "MANAGE TRAFFIC"
5. Shift 100% traffic to that revision

### Option 2: Rollback via CLI
```bash
# List revisions
gcloud run revisions list --service=gcp-bearer-auth-service \
  --region=us-central1 \
  --project=it-automation-training

# Rollback to specific revision
PREVIOUS_REVISION="gcp-bearer-auth-service-00001-abc"
gcloud run services update-traffic gcp-bearer-auth-service \
  --to-revisions="${PREVIOUS_REVISION}=100" \
  --region=us-central1 \
  --project=it-automation-training
```

### Option 3: Revert Git Commit
```bash
# Revert the problematic commit
git revert HEAD
git push origin main

# This will trigger a new deployment with the previous code
```

---

## Best Practices

### 1. Use Branch Protection
- Require pull request reviews before merging to main
- Run tests in CI before deployment
- Enable status checks

### 2. Environment-Specific Deployments
Consider different triggers for:
- `main` branch → Production
- `staging` branch → Staging environment
- `dev` branch → Development environment

### 3. Add Health Checks
Update `cloudbuild.yaml` to verify deployment:
```yaml
- name: 'gcr.io/cloud-builders/curl'
  args: 
    - '-f'
    - 'https://gcp-bearer-auth-service-abc123-uc.a.run.app/api/health'
```

### 4. Notifications
Set up build notifications:
```bash
# Create a Pub/Sub topic for build notifications
gcloud pubsub topics create cloud-builds --project=it-automation-training

# Subscribe to notifications (can integrate with Slack, email, etc.)
```

---

## Troubleshooting

### Build Fails with Permission Errors
- Verify Cloud Build service account has required roles
- Run `./setup-cd.sh` again to reapply permissions

### Secret Manager Access Denied
- Ensure Cloud Build SA has `secretmanager.secretAccessor` role
- Verify the secret exists: `gcloud secrets describe jwt-secret-key`

### Deployment Succeeds but Service Doesn't Work
- Check Cloud Run logs: `gcloud run services logs read gcp-bearer-auth-service`
- Verify environment variables are set correctly
- Check service account has permissions to access Cloud Run API

### GitHub Connection Issues
- Revoke and reconnect GitHub app in Cloud Build settings
- Verify repository permissions in GitHub

---

## Cost Considerations

### Cloud Build Pricing
- **Free tier**: 120 build-minutes/day
- **After free tier**: $0.003/build-minute
- Typical build time: 1-2 minutes
- **Estimate**: ~$3-5/month for active development

### Cloud Run Pricing
- Pay only when running (per request)
- Free tier: 2 million requests/month
- **Estimate**: Free for development/testing

### Storage (Container Registry)
- $0.026/GB/month
- Typical image size: 200-300 MB
- **Estimate**: $0.50-1/month

**Total estimated cost: $4-7/month for active development**

---

## Next Steps

1. **Run setup script**: `./setup-cd.sh`
2. **Connect GitHub**: Follow prompts in console
3. **Test deployment**: Push a change to main branch
4. **Monitor**: Watch build in Cloud Console
5. **Iterate**: Make changes and let CD handle deployments!
