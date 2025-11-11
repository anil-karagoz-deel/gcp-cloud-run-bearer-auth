# GCP Cloud Run Service - Bearer Auth

A lightweight Python Flask service deployed to Google Cloud Run that responds to Bearer token-authorized GET requests.

## Features

- ✅ Bearer token authentication
- ✅ RESTful API endpoints
- ✅ Health check endpoints
- ✅ Docker containerized
- ✅ Ready for Google Cloud Run deployment
- ✅ Environment-based configuration

## API Endpoints

### 1. Root Health Check
```bash
GET /
```
Public endpoint to verify service is running.

### 2. API Health Check
```bash
GET /api/health
```
Returns service health status.

### 3. Secure Endpoint (Requires Authentication)
```bash
GET /api/secure
Authorization: Bearer <your-token>
```
Protected endpoint that requires valid Bearer token.

**Success Response (200):**
```json
{
  "success": true,
  "message": "Request authorized successfully!",
  "data": "This is your secure response data."
}
```

**Error Response (401):**
```json
{
  "error": "Unauthorized",
  "message": "Invalid token"
}
```

## Local Development

### Prerequisites
- Python 3.11 or higher
- pip

### Setup
1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Set the Bearer token (optional, defaults to 'default-secret-token'):
```bash
export BEARER_TOKEN="your-secret-token"
```

3. Run the service:
```bash
python main.py
```

The service will start on `http://localhost:8080`

### Test Locally
```bash
# Test without auth (should fail)
curl http://localhost:8080/api/secure

# Test with auth (should succeed)
curl -H "Authorization: Bearer your-secret-token" http://localhost:8080/api/secure
```

## Docker

### Build the image
```bash
docker build -t gcp-bearer-auth-service .
```

### Run the container
```bash
docker run -p 8080:8080 -e BEARER_TOKEN="your-secret-token" gcp-bearer-auth-service
```

## Google Cloud Run Deployment

### Prerequisites
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- A GCP project with billing enabled
- Authenticated with gcloud: `gcloud auth login`

### Deploy

The deployment script automatically:
- Enables required Google Cloud APIs (Secret Manager, Cloud Build, Cloud Run)
- Stores the Bearer token securely in Secret Manager
- Builds the container image using Cloud Build
- Deploys to Cloud Run with the configured settings

#### Option 1: Using Environment Variables

```bash
export PROJECT_ID="your-gcp-project-id"
export REGION="us-central1"
export BEARER_TOKEN="your-secret-token"
./deploy.sh
```

#### Option 2: Using a .env File (Recommended)

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` with your configuration:
```bash
PROJECT_ID=my-gcp-project-123
REGION=us-central1
BEARER_TOKEN=$(openssl rand -base64 32)  # Generate secure token
```

3. Run the deployment script:
```bash
./deploy.sh
```

The script will:
- Validate all required environment variables
- Enable necessary Google Cloud APIs
- Store the Bearer token in Secret Manager (not as plain environment variable)
- Build the container image using Google Cloud Build
- Deploy to Cloud Run with optimal settings
- Output the service URL and test commands

### Configuration Options

The deployment script supports various configuration options via environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PROJECT_ID` | ✅ Yes | - | Your GCP project ID |
| `REGION` | ✅ Yes | - | GCP region for deployment |
| `BEARER_TOKEN` | ✅ Yes | - | Secret token for API authentication |
| `SERVICE_NAME` | No | `gcp-bearer-auth-service` | Cloud Run service name |
| `BEARER_TOKEN_SECRET_NAME` | No | `bearer-token` | Secret Manager secret name |
| `PORT` | No | `8080` | Container port |
| `MEMORY` | No | `512Mi` | Memory allocation |
| `CPU` | No | `1` | CPU allocation |
| `MAX_INSTANCES` | No | `10` | Maximum autoscaling instances |
| `MIN_INSTANCES` | No | `0` | Minimum instances (0 = scale to zero) |
| `TIMEOUT` | No | `300` | Request timeout in seconds |
| `ALLOW_UNAUTHENTICATED` | No | `true` | Allow public access to service |

### Manual Deployment

If you prefer manual deployment:

```bash
# Enable required APIs
gcloud services enable secretmanager.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable run.googleapis.com

# Create secret for bearer token
echo -n "your-secret-token" | gcloud secrets create bearer-token \
  --replication-policy=automatic \
  --data-file=-

# Build and push the image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/gcp-bearer-auth-service

# Deploy to Cloud Run
gcloud run deploy gcp-bearer-auth-service \
  --image gcr.io/YOUR_PROJECT_ID/gcp-bearer-auth-service \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --update-secrets BEARER_TOKEN=bearer-token:latest \
  --memory 512Mi \
  --cpu 1
```

## Testing the Deployed Service

After deployment, test your service:

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe gcp-bearer-auth-service --region us-central1 --format 'value(status.url)')

# Test the health endpoint
curl $SERVICE_URL/api/health

# Test the secure endpoint with authentication
curl -H "Authorization: Bearer your-secret-token" $SERVICE_URL/api/secure
```

## Runtime Configuration

### Environment Variables (Application)

| Variable | Description | Default |
|----------|-------------|---------||
| `BEARER_TOKEN` | Secret token for authentication (provided via Secret Manager) | `default-secret-token` |
| `PORT` | Port the service listens on | `8080` |

## Security Considerations

- ✅ **Secrets in Secret Manager**: The deployment script automatically stores the Bearer token in Google Secret Manager, not as a plain environment variable
- ✅ **HTTPS by default**: Cloud Run provides automatic HTTPS for all services
- ✅ **Strong tokens**: Generate secure tokens using `openssl rand -base64 32`
- ✅ **IAM integration**: Control access using Google Cloud IAM roles and service accounts
- 🔄 **Token rotation**: Update tokens by running the deployment script with a new `BEARER_TOKEN` value
- 📊 **Monitoring**: Use Cloud Logging and Cloud Monitoring to track access patterns
- 🔒 **Network security**: Consider using VPC ingress controls for additional protection

### Generating a Secure Token

```bash
# Generate a random 32-byte token (base64 encoded)
openssl rand -base64 32

# Or use Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## License

MIT
