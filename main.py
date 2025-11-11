import os
from flask import Flask, request, jsonify
import jwt
from datetime import datetime, timezone
from functools import wraps
from google.cloud import run_v2
from google.api_core import exceptions as google_exceptions

app = Flask(__name__)

# Configuration
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'default-secret-key')
GCP_PROJECT_ID = os.environ.get('GCP_PROJECT_ID')
GCP_REGION = os.environ.get('GCP_REGION', 'us-central1')

def verify_jwt_token():
    """Verify JWT token from Authorization header."""
    auth_header = request.headers.get('Authorization')
    
    if not auth_header:
        return False, "Authorization header required"
    
    try:
        # Extract token from "Bearer <token>" format
        scheme, token = auth_header.split()
        if scheme.lower() != 'bearer':
            return False, "Invalid authentication scheme"
    except ValueError:
        return False, "Invalid Authorization header format"
    
    try:
        # Verify and decode the JWT token
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=['HS256']
        )
        return True, payload
    except jwt.ExpiredSignatureError:
        return False, "Token has expired"
    except jwt.InvalidSignatureError:
        return False, "Invalid token: Signature verification failed"
    except jwt.DecodeError as e:
        return False, f"Invalid token: {str(e)}"
    except Exception as e:
        return False, f"Token validation error: {str(e)}"

@app.route('/')
def root():
    """Root endpoint for basic health check."""
    return jsonify({
        "status": "ok",
        "message": "GCP Cloud Run Bearer Auth Service",
        "endpoints": {
            "health": "/api/health",
            "secure": "/api/secure (requires JWT)"
        }
    }), 200

@app.route('/api/secure')
def secure_endpoint():
    """Secure endpoint that requires JWT Bearer token authentication."""
    is_valid, message = verify_jwt_token()
    
    if not is_valid:
        return jsonify({
            "error": "Unauthorized",
            "message": message
        }), 401
    
    return jsonify({
        "success": True,
        "message": "Request authorized successfully!",
        "data": "This is your secure response data.",
        "version": "1.0.1"
    }), 200

@app.route('/api/health')
def health():
    """Health check endpoint."""
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "service": "gcp-bearer-auth-service"
    }), 200

@app.route('/api/services')
def list_services():
    """List all Cloud Run services in the project (requires JWT authentication)."""
    is_valid, message = verify_jwt_token()
    
    if not is_valid:
        return jsonify({
            "error": "Unauthorized",
            "message": message
        }), 401
    
    if not GCP_PROJECT_ID:
        return jsonify({
            "error": "Configuration Error",
            "message": "GCP_PROJECT_ID environment variable not set"
        }), 500
    
    try:
        # Initialize Cloud Run client
        client = run_v2.ServicesClient()
        
        # Build the parent path
        parent = f"projects/{GCP_PROJECT_ID}/locations/{GCP_REGION}"
        
        # List services
        services = []
        for service in client.list_services(parent=parent):
            service_info = {
                "name": service.name.split('/')[-1],
                "full_name": service.name,
                "uri": service.uri if service.uri else None,
                "description": service.description if service.description else None,
                "created_time": service.create_time.isoformat() if service.create_time else None,
                "updated_time": service.update_time.isoformat() if service.update_time else None,
                "creator": service.creator if service.creator else None,
                "last_modifier": service.last_modifier if service.last_modifier else None,
                "generation": service.generation,
            }
            
            # Add conditions (health status)
            if service.conditions:
                service_info["conditions"] = [
                    {
                        "type": condition.type,
                        "state": str(condition.state),
                        "message": condition.message if condition.message else None,
                        "last_transition_time": condition.last_transition_time.isoformat() if condition.last_transition_time else None,
                        "severity": str(condition.severity) if condition.severity else None
                    }
                    for condition in service.conditions
                ]
                
                # Determine overall status
                ready_condition = next((c for c in service.conditions if c.type == "Ready"), None)
                if ready_condition:
                    service_info["status"] = "ready" if str(ready_condition.state) == "4" else "not_ready"
                else:
                    service_info["status"] = "unknown"
            
            # Add ingress settings
            if service.ingress:
                service_info["ingress"] = str(service.ingress)
            
            # Add traffic information
            if service.traffic:
                service_info["traffic"] = [
                    {
                        "type": str(t.type_),
                        "revision": t.revision if t.revision else None,
                        "percent": t.percent,
                        "tag": t.tag if t.tag else None
                    }
                    for t in service.traffic
                ]
            
            # Add scaling configuration
            if service.template and service.template.scaling:
                service_info["scaling"] = {
                    "min_instances": service.template.scaling.min_instance_count,
                    "max_instances": service.template.scaling.max_instance_count
                }
            
            services.append(service_info)
        
        return jsonify({
            "success": True,
            "project_id": GCP_PROJECT_ID,
            "region": GCP_REGION,
            "service_count": len(services),
            "services": services
        }), 200
        
    except google_exceptions.PermissionDenied as e:
        return jsonify({
            "error": "Permission Denied",
            "message": "Service account does not have permission to list Cloud Run services",
            "details": str(e)
        }), 403
    
    except google_exceptions.NotFound as e:
        return jsonify({
            "error": "Not Found",
            "message": f"Project or region not found: {GCP_PROJECT_ID}/{GCP_REGION}",
            "details": str(e)
        }), 404
    
    except Exception as e:
        return jsonify({
            "error": "Internal Server Error",
            "message": "Failed to list Cloud Run services",
            "details": str(e)
        }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
