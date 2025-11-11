# GCP Cloud Run Service - JWT Bearer Auth

A lightweight Python Flask service deployed to Google Cloud Run that responds to JWT Bearer token-authorized GET requests.

## Features

- ✅ **JWT (JSON Web Token) authentication** - Tokens start with `eyJ`
- ✅ Token expiration validation
- ✅ RESTful API endpoints
- ✅ Health check endpoints
- ✅ Docker containerized
- ✅ Ready for Google Cloud Run deployment
- ✅ Environment-based configuration
- ✅ Secure secret management with Google Secret Manager

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

### 3. Secure Endpoint (Requires JWT Authentication)
```bash
GET /api/secure
Authorization: Bearer <your-jwt-token>
```
Protected endpoint that requires valid JWT Bearer token (starts with `eyJ`).

**Success Response (200):**
```json
{
  "success": true,
  "message": "Request authorized successfully!",
  "data": "This is your secure response data."
}
```

**Error Response (401) - Invalid Token:**
```json
{
  "error": "Unauthorized",
  "message": "Invalid token: Signature verification failed"
}
```

**Error Response (401) - Expired Token:**
```json
{
  "error": "Unauthorized",
  "message": "Token has expired"
}
```

## Generating JWT Tokens

### Using the Token Generator Script

The project includes a helper script to generate JWT tokens:

```bash
# Install dependencies first
pip install -r requirements.txt

# Generate a JWT token with a new secret key
python3 generate_jwt.py

# Generate a token with a specific secret key
python3 generate_jwt.py --secret "your-secret-key"

# Generate a token with custom expiration (default is 365 days)
python3 generate_jwt.py --secret "your-secret-key" --days 30

# Just generate a secret key without a token
python3 generate_jwt.py --generate-secret
```

The script will output:
- The secret key (save this in your `.env` file as `JWT_SECRET_KEY`)
- The JWT token starting with `eyJ` (use this in your API requests)

### Manual JWT Generation

You can also generate tokens manually with Python:

```python
import jwt
from datetime import datetime, timedelta, timezone

secret_key = "your-secret-key"
payload = {
    'sub': 'cloud-run-service',
    'iat': datetime.now(timezone.utc),
    'exp': datetime.now(timezone.utc) + timedelta(days=365)
}
token = jwt.encode(payload, secret_key, algorithm='HS256')
print(token)  # Starts with eyJ
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

2. Generate a secret key and JWT token:
```bash
python3 generate_jwt.py
# Save the JWT_SECRET_KEY in your environment
```

3. Set the JWT secret key:
```bash
export JWT_SECRET_KEY="your-secret-key-from-generator"
```

4. Run the service:
```bash
python main.py
```

The service will start on `http://localhost:8080`

### Test Locally
```bash
# Generate a JWT token
JWT_TOKEN=$(python3 generate_jwt.py --secret "your-secret-key" | grep "eyJ" | awk '{print $1}')

# Test without auth (should fail)
curl http://localhost:8080/api/secure

# Test with JWT auth (should succeed)
curl -H "Authorization: Bearer $JWT_TOKEN" http://localhost:8080/api/secure
```

## Docker

### Build the image
```bash
docker build -t gcp-bearer-auth-service .
```

### Run the container
```bash
docker run -p 8080:8080 -e JWT_SECRET_KEY="your-secret-key" gcp-bearer-auth-service
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
export JWT_SECRET_KEY=$(openssl rand -base64 32)  # Generate secure secret key
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
JWT_SECRET_KEY=$(openssl rand -base64 32)  # Generate secure secret key
```

3. Run the deployment script:
```bash
./deploy.sh
```

The script will:
- Validate all required environment variables
- Enable necessary Google Cloud APIs
- Store the JWT secret key in Secret Manager (not as plain environment variable)
- Build the container image using Google Cloud Build
- Deploy to Cloud Run with optimal settings
- Output the service URL and test commands

#### After Deployment: Generate JWT Tokens

Once deployed, generate JWT tokens to test the service:

```bash
# Use the same secret key from your .env file
python3 generate_jwt.py --secret "your-jwt-secret-key-value"

# This will output a JWT token starting with eyJ
# Use this token to make authenticated requests
```

### Configuration Options

The deployment script supports various configuration options via environment variables:

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `PROJECT_ID` | ✅ Yes | - | Your GCP project ID |
| `REGION` | ✅ Yes | - | GCP region for deployment |
| `JWT_SECRET_KEY` | ✅ Yes | - | Secret key for JWT signing and verification |
| `SERVICE_NAME` | No | `gcp-bearer-auth-service` | Cloud Run service name |
| `JWT_SECRET_NAME` | No | `jwt-secret-key` | Secret Manager secret name |
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

# Create secret for JWT secret key
echo -n "your-jwt-secret-key" | gcloud secrets create jwt-secret-key \
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
  --update-secrets JWT_SECRET_KEY=jwt-secret-key:latest \
  --memory 512Mi \
  --cpu 1
```

## Testing the Deployed Service

After deployment, test your service:

```bash
# Get your service URL
SERVICE_URL=$(gcloud run services describe gcp-bearer-auth-service --region us-central1 --format 'value(status.url)')

# Test the health endpoint (public)
curl $SERVICE_URL/api/health

# Generate a JWT token (use the same secret key from deployment)
python3 generate_jwt.py --secret "your-jwt-secret-key"

# Test the secure endpoint with JWT authentication
# Replace YOUR_JWT_TOKEN with the token from the generator (starts with eyJ)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" $SERVICE_URL/api/secure

# Example with actual JWT token:
curl -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..." $SERVICE_URL/api/secure
```

## Runtime Configuration

### Environment Variables (Application)

| Variable | Description | Default |
|----------|-------------|---------||
| `JWT_SECRET_KEY` | Secret key for JWT signing/verification (provided via Secret Manager) | `default-secret-key` |
| `PORT` | Port the service listens on | `8080` |

### JWT Token Structure

The service expects JWT tokens with the following structure:

```json
{
  "sub": "cloud-run-service",
  "iat": 1699123456,
  "exp": 1730659456,
  "iss": "gcp-bearer-auth-service"
}
```

- `sub` (subject): Identifies the token purpose
- `iat` (issued at): When the token was created
- `exp` (expiration): When the token expires
- `iss` (issuer): Token issuer identifier

Tokens are signed with the HS256 algorithm using the `JWT_SECRET_KEY`.

## Security Considerations

- ✅ **JWT Authentication**: Uses industry-standard JSON Web Tokens with signature verification
- ✅ **Token Expiration**: Tokens automatically expire (default 365 days, configurable)
- ✅ **Secrets in Secret Manager**: JWT secret keys stored in Google Secret Manager, not as plain environment variables
- ✅ **HTTPS by default**: Cloud Run provides automatic HTTPS for all services
- ✅ **Strong secret keys**: Generate cryptographically secure keys using `openssl rand -base64 32`
- ✅ **Signature verification**: Every JWT is verified for authenticity and integrity
- ✅ **IAM integration**: Control access using Google Cloud IAM roles and service accounts
- 🔄 **Secret rotation**: Update keys by running the deployment script with a new `JWT_SECRET_KEY`
- 📊 **Monitoring**: Use Cloud Logging and Cloud Monitoring to track access patterns
- 🔒 **Network security**: Consider using VPC ingress controls for additional protection

### JWT Security Best Practices

1. **Keep secret keys secure**: Never commit `JWT_SECRET_KEY` to version control
2. **Use strong secret keys**: Minimum 32 bytes of random data
3. **Set appropriate expiration**: Balance security and convenience (shorter = more secure)
4. **Rotate keys regularly**: Update the secret key periodically
5. **Monitor token usage**: Track failed authentication attempts
6. **Use HTTPS only**: JWT tokens should only be transmitted over secure connections

### Generating a Secure Secret Key

```bash
# Generate a random 32-byte secret key (base64 encoded)
openssl rand -base64 32

# Or use the built-in generator
python3 generate_jwt.py --generate-secret
```

## License

MIT
