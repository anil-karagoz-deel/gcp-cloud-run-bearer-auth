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
- Cloud Run API enabled

### Deploy

1. Set your GCP project ID:
```bash
export GCP_PROJECT_ID="your-gcp-project-id"
```

2. Set your Bearer token:
```bash
export BEARER_TOKEN="your-secret-token"
```

3. Run the deployment script:
```bash
./deploy.sh
```

The script will:
- Build the container image using Google Cloud Build
- Deploy to Cloud Run in the `us-central1` region
- Configure the service with your Bearer token
- Output the service URL

### Manual Deployment

If you prefer manual deployment:

```bash
# Build and push the image
gcloud builds submit --tag gcr.io/YOUR_PROJECT_ID/gcp-bearer-auth-service

# Deploy to Cloud Run
gcloud run deploy gcp-bearer-auth-service \
  --image gcr.io/YOUR_PROJECT_ID/gcp-bearer-auth-service \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars BEARER_TOKEN=your-secret-token
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

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------||
| `BEARER_TOKEN` | Secret token for authentication | `default-secret-token` |
| `PORT` | Port the service listens on | `8080` |
| `GCP_PROJECT_ID` | Your GCP project ID (for deployment) | - |

## Security Considerations

- **Always use strong, randomly generated tokens in production**
- Store tokens securely (use Google Secret Manager for production)
- Use HTTPS (Cloud Run provides this automatically)
- Consider implementing token rotation
- Monitor access logs for suspicious activity

## License

MIT
