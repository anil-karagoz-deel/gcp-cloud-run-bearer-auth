"""
Google Cloud Run service with Bearer token authentication.
Responds to authorized GET requests with a success message.
"""
import os
from flask import Flask, request, jsonify

app = Flask(__name__)

# Get the bearer token from environment variable
BEARER_TOKEN = os.environ.get('BEARER_TOKEN', 'default-secret-token')


def verify_bearer_token():
    """Verify the Bearer token from the Authorization header."""
    auth_header = request.headers.get('Authorization')
    
    if not auth_header:
        return False, "Missing Authorization header"
    
    if not auth_header.startswith('Bearer '):
        return False, "Invalid Authorization header format"
    
    token = auth_header.replace('Bearer ', '', 1)
    
    if token != BEARER_TOKEN:
        return False, "Invalid token"
    
    return True, "Token valid"


@app.route('/', methods=['GET'])
def health_check():
    """Health check endpoint for Cloud Run."""
    return jsonify({
        "status": "healthy",
        "service": "GCP Cloud Run Service"
    }), 200


@app.route('/api/secure', methods=['GET'])
def secure_endpoint():
    """Secure endpoint that requires Bearer token authentication."""
    is_valid, message = verify_bearer_token()
    
    if not is_valid:
        return jsonify({
            "error": "Unauthorized",
            "message": message
        }), 401
    
    return jsonify({
        "success": True,
        "message": "Request authorized successfully!",
        "data": "This is your secure response data."
    }), 200


@app.route('/api/health', methods=['GET'])
def api_health():
    """API health check endpoint."""
    return jsonify({
        "status": "ok",
        "message": "Service is running"
    }), 200


if __name__ == '__main__':
    # Cloud Run sets the PORT environment variable
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
