# GCP Cloud Run Bearer Auth Service

A production-ready Python Flask service deployed on Google Cloud Run that demonstrates JWT (JSON Web Token) authentication for secure API endpoints.

## Features

- ✅ JWT-based authentication with signature verification
- ✅ Secure bearer token validation (tokens start with `eyJ`)
- ✅ RESTful API endpoints
- ✅ Production-ready with Gunicorn
- ✅ Docker containerization optimized for Cloud Run
- ✅ Automated deployment script with Secret Manager integration
- ✅ Cloud Run service listing endpoint
- ✅ Comprehensive error handling

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

### 4. List Cloud Run Services (Requires JWT Authentication)
```bash
GET /api/services
Authorization: Bearer <your-jwt-token>
```
Returns detailed information about all Cloud Run services in the project.

**Success Response (200):**
```json
{
  "status": "success",
  "count": 2,
  "services": [
    {
      "name": "bearer-auth-service",
      "url": "https://bearer-auth-service-abc123-uc.a.run.app",
      "description": "JWT authenticated API service",
      "created": "2024-01-15T10:00:00.000000Z",
      "updated": "2024-01-15T12:30:00.000000Z",
      "creator": "user@example.com",
      "health": "Ready",
      "ingress": "INGRESS_TRAFFIC_ALL",
      "traffic": [
        {
          "type": "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST",
          "percent": 100
        }
      ],
      "scaling": {
        "minInstances": 0,
        "maxInstances": 10
      }
    }
  ]
}
```

**Error Response (403) - Insufficient Permissions:**
```json
{
  "error": "permission_denied",
  "message": "Service account lacks permission to list Cloud Run services"
}
```

**Required IAM Permissions:**
The Cloud Run service account needs `roles/run.viewer` to list services. The deployment script automatically configures this permission.

## Testing the API

### 1. Generate a JWT Token

```bash
# Generate a token that expires in 1 hour (default)
python3 generate_jwt.py

# Generate a token with custom expiration (in seconds)
python3 generate_jwt.py --expires-in 7200  # 2 hours
```

### 2. Test the Endpoints

```bash
# Test health endpoint (no auth required)
curl https://YOUR_SERVICE_URL/api/health

# Test secure endpoint (requires JWT)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://YOUR_SERVICE_URL/api/secure

# List all Cloud Run services (requires JWT)
curl -H "Authorization: Bearer YOUR_JWT_TOKEN" \
     https://YOUR_SERVICE_URL/api/services
```

### Example Responses

#### Success (Secure Endpoint):
```json
{
  "status": "success",
  "message": "Authenticated successfully!",
  "timestamp": "2024-01-15T10:30:00.123456"
}
```

#### Success (Services Endpoint):
```json
{
  "status": "success",
  "count": 3,
  "services": [
    {
      "name": "bearer-auth-service",
      "url": "https://bearer-auth-service-abc123-uc.a.run.app",
      "description": "JWT authenticated API service",
      "created": "2024-01-15T10:00:00.000000Z",
      "updated": "2024-01-15T12:30:00.000000Z",
      "creator": "user@example.com",
      "health": "Ready",
      "ingress": "INGRESS_TRAFFIC_ALL",
      "traffic": [
        {
          "type": "TRAFFIC_TARGET_ALLOCATION_TYPE_LATEST",
          "percent": 100
        }
      ],
      "scaling": {
        "minInstances": 0,
        "maxInstances": 10
      }
    }
  ]
}
```

#### Unauthorized (no token):
```json
{
  "error": "unauthorized",
  "message": "Authorization header required"
}
```

#### Unauthorized (invalid token):
```json
{
  "error": "unauthorized",
  "message": "Invalid or expired token"
}
```

## Prerequisites

- Google Cloud SDK (gcloud CLI)
- Python 3.11+
- Docker (for local testing)
- Active GCP project with billing enabled
- Required GCP APIs (automatically enabled by deployment script):
  - Cloud Run API
  - Cloud Build API
  - Secret Manager API

## Setup

### 1. Clone the Repository

```bash
git clone https://github.com/anil-karagoz-deel/gcp-cloud-run-bearer-auth.git
cd gcp-cloud-run-bearer-auth
```

### 2. Configure Environment

```bash
# Copy the example env file
cp .env.example .env

# Edit .env with your configuration
nano .env
```

Required configuration:
```bash
PROJECT_ID=your-gcp-project-id
REGION=us-central1
JWT_SECRET_KEY=your-super-secret-jwt-key-here
GCP_PROJECT_ID=your-gcp-project-id
GCP_REGION=us-central1
```

### 3. Generate a Secure JWT Secret

```bash
# Option 1: Using openssl
openssl rand -base64 32

# Option 2: Using Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"

# Option 3: Using the helper script
python3 generate_jwt.py --generate-secret
```

### 4. Deploy to Cloud Run

```bash
# Make the deployment script executable
chmod +x deploy.sh

# Run the deployment
./deploy.sh
```

The deployment script will:
- Enable required GCP APIs
- Store JWT secret in Secret Manager
- Build the container image using Cloud Build
- Deploy to Cloud Run with proper configuration
- Configure service account with Cloud Run viewer permissions
- Output the service URL

## JWT Authentication

### How It Works

1. **Token Generation**: Use `generate_jwt.py` to create a JWT token signed with your secret key
2. **Token Format**: Tokens are in JWT format (start with `eyJ`)
3. **Token Verification**: The service validates:
   - Token signature using the shared secret key
   - Token expiration timestamp
   - Token structure and format

### Token Generation

The included `generate_jwt.py` script provides easy token generation:

```bash
# Generate token with default 1-hour expiration
python3 generate_jwt.py

# Generate token with custom expiration
python3 generate_jwt.py --expires-in 3600  # 1 hour in seconds

# Generate a new secret key
python3 generate_jwt.py --generate-secret
```

### Using Tokens

Include the JWT token in the Authorization header:

```bash
curl -H "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGc..." \
     https://your-service-url/api/secure
```

## Local Development

### Using Python Virtual Environment

```bash
# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set environment variables
export JWT_SECRET_KEY="your-secret-key"
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"

# Run the application
python main.py
```

### Using Docker

```bash
# Build the image
docker build -t bearer-auth-service .

# Run the container
docker run -p 8080:8080 \
  -e JWT_SECRET_KEY="your-secret-key" \
  -e GCP_PROJECT_ID="your-project-id" \
  -e GCP_REGION="us-central1" \
  bearer-auth-service
```

## Project Structure

```
.
├── main.py              # Flask application with JWT authentication
├── requirements.txt     # Python dependencies
├── Dockerfile          # Container image definition
├── deploy.sh           # Automated deployment script
├── generate_jwt.py     # JWT token generator utility
├── .env.example        # Environment variables template
├── .gitignore         # Git ignore patterns
└── README.md          # This file
```

## Security Best Practices

1. **Secret Management**: JWT secrets are stored in Google Secret Manager, never in code
2. **Token Expiration**: Tokens expire after a configurable time period
3. **Signature Verification**: All tokens are cryptographically verified
4. **HTTPS Only**: Cloud Run automatically provides TLS/SSL
5. **IAM Permissions**: Service account uses least-privilege principle
6. **Environment Variables**: Sensitive data never committed to repository

## Configuration Options

All configuration can be set via environment variables in `.env`:

| Variable | Description | Default |
|----------|-------------|--------|
| `PROJECT_ID` | GCP Project ID | Required |
| `REGION` | Cloud Run region | Required |
| `JWT_SECRET_KEY` | Secret key for JWT signing | Required |
| `GCP_PROJECT_ID` | Project ID for Cloud Run API | Required |
| `GCP_REGION` | Region for Cloud Run API | us-central1 |
| `SERVICE_NAME` | Cloud Run service name | gcp-bearer-auth-service |
| `JWT_SECRET_NAME` | Secret Manager secret name | jwt-secret-key |
| `PORT` | Application port | 8080 |
| `MEMORY` | Container memory limit | 512Mi |
| `CPU` | Container CPU allocation | 1 |
| `MAX_INSTANCES` | Maximum service instances | 10 |
| `MIN_INSTANCES` | Minimum service instances | 0 |
| `TIMEOUT` | Request timeout (seconds) | 300 |
| `ALLOW_UNAUTHENTICATED` | Allow public access | true |

## Troubleshooting

### Common Issues

**Token doesn't start with "eyJ":**
- Tokens are JWT format and should start with `eyJ`
- Use the provided `generate_jwt.py` script to generate tokens

**401 Unauthorized Error:**
- Verify token is included in Authorization header
- Check token hasn't expired
- Ensure JWT_SECRET_KEY matches between token generation and service

**403 Permission Denied (services endpoint):**
- Verify service account has `roles/run.viewer` role
- Check GCP_PROJECT_ID and GCP_REGION are set correctly

**Deployment Fails:**
- Verify billing is enabled on GCP project
- Check gcloud CLI is authenticated: `gcloud auth login`
- Ensure required APIs are enabled

### Viewing Logs

```bash
# View Cloud Run logs
gcloud run services logs read bearer-auth-service \
  --region=us-central1 \
  --project=your-project-id
```

## License

MIT License - See LICENSE file for details

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
