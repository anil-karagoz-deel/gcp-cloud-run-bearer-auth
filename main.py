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

def verify_jwt_token(token):
    """Verify JWT token and return decoded payload."""
    try:
        payload = jwt.decode(
            token,
            JWT_SECRET_KEY,
            algorithms=['HS256']
        )
        return payload
    except jwt.ExpiredSignatureError:
        return None
    except jwt.InvalidTokenError:
        return None

def require_jwt_auth(f):
    """Decorator to require JWT authentication."""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')
        
        if not auth_header:
            return jsonify({
                'error': 'unauthorized',
                'message': 'Authorization header required'
            }), 401
        
        try:
            scheme, token = auth_header.split()
            if scheme.lower() != 'bearer':
                return jsonify({
                    'error': 'unauthorized',
                    'message': 'Invalid authentication scheme'
                }), 401
        except ValueError:
            return jsonify({
                'error': 'unauthorized',
                'message': 'Invalid Authorization header format'
            }), 401
        
        payload = verify_jwt_token(token)
        if not payload:
            return jsonify({
                'error': 'unauthorized',
                'message': 'Invalid or expired token'
            }), 401
        
        # Add payload to request context if needed
        request.jwt_payload = payload
        return f(*args, **kwargs)
    
    return decorated_function

@app.route('/')
def health_check():
    return jsonify({
        'status': 'healthy',
        'message': 'Service is running'
    })

@app.route('/api/health')
def api_health():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.route('/api/secure')
@require_jwt_auth
def secure_endpoint():
    return jsonify({
        'status': 'success',
        'message': 'Authenticated successfully!',
        'timestamp': datetime.now(timezone.utc).isoformat()
    })

@app.route('/api/services')
@require_jwt_auth
def list_cloud_run_services():
    """List all Cloud Run services in the project."""
    try:
        if not GCP_PROJECT_ID:
            return jsonify({
                'error': 'configuration_error',
                'message': 'GCP_PROJECT_ID environment variable not set'
            }), 500
        
        # Initialize Cloud Run client
        client = run_v2.ServicesClient()
        
        # Construct the parent path
        parent = f"projects/{GCP_PROJECT_ID}/locations/{GCP_REGION}"
        
        # List all services
        services_list = []
        request = run_v2.ListServicesRequest(parent=parent)
        
        for service in client.list_services(request=request):
            # Extract service information
            service_info = {
                'name': service.name.split('/')[-1],  # Get just the service name
                'url': service.uri if service.uri else None,
                'description': service.description if service.description else None,
                'created': service.create_time.isoformat() if service.create_time else None,
                'updated': service.update_time.isoformat() if service.update_time else None,
                'creator': service.creator if service.creator else None,
            }
            
            # Get health status from conditions
            if service.conditions:
                for condition in service.conditions:
                    if condition.type == 'Ready':
                        service_info['health'] = condition.state.name
                        break
            
            # Get ingress settings
            if service.ingress:
                service_info['ingress'] = service.ingress.name
            
            # Get traffic information
            if service.traffic:
                service_info['traffic'] = [
                    {
                        'type': t.type_.name,
                        'percent': t.percent
                    }
                    for t in service.traffic
                ]
            
            # Get scaling information
            if service.template and service.template.scaling:
                service_info['scaling'] = {
                    'minInstances': service.template.scaling.min_instance_count,
                    'maxInstances': service.template.scaling.max_instance_count
                }
            
            services_list.append(service_info)
        
        return jsonify({
            'status': 'success',
            'count': len(services_list),
            'services': services_list
        })
    
    except google_exceptions.PermissionDenied as e:
        return jsonify({
            'error': 'permission_denied',
            'message': 'Service account lacks permission to list Cloud Run services',
            'details': str(e)
        }), 403
    
    except google_exceptions.NotFound as e:
        return jsonify({
            'error': 'not_found',
            'message': f'Project or region not found: {GCP_PROJECT_ID}/{GCP_REGION}',
            'details': str(e)
        }), 404
    
    except Exception as e:
        return jsonify({
            'error': 'internal_error',
            'message': 'Failed to list Cloud Run services',
            'details': str(e)
        }), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port, debug=False)
