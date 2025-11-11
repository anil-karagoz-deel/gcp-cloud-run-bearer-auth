"""
Google Cloud Run service with JWT Bearer token authentication.
Responds to authorized GET requests with a success message.
Provides status information for all Cloud Run services in the project.
Version: 1.0.2
"""
import os
import jwt
from datetime import datetime
from flask import Flask, request, jsonify
from google.cloud import run_v2
from google.api_core import exceptions as google_exceptions

app = Flask(__name__)

# Get the JWT secret key from environment variable
JWT_SECRET_KEY = os.environ.get('JWT_SECRET_KEY', 'default-secret-key')

# Get GCP project and region from environment
GCP_PROJECT_ID = os.environ.get('GCP_PROJECT_ID', None)
GCP_REGION = os.environ.get('GCP_REGION', 'us-central1')


def verify_jwt_token():
    """Verify the JWT Bearer token from the Authorization header."""
    auth_header = request.headers.get('Authorization')
    
    if not auth_header:
        return False, "Missing Authorization header"
    
    if not auth_header.startswith('Bearer '):
        return False, "Invalid Authorization header format. Use: Bearer <token>"
    
    token = auth_header.split(' ')[1]
    
    if not token.startswith('eyJ'):
        return False, "Invalid JWT token format. JWT tokens must start with 'eyJ'"
    
    try:
        payload = jwt.decode(token, JWT_SECRET_KEY, algorithms=['HS256'])
        return True, payload
    except jwt.ExpiredSignatureError:
        return False, "Token has expired"
    except jwt.InvalidTokenError as e:
        return False, f"Invalid token: {str(e)}"


@app.route('/', methods=['GET'])
def health_check():
    """Basic health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'service': 'gcp-bearer-auth-service',
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/health', methods=['GET'])
def api_health():
    """API health check endpoint."""
    return jsonify({
        'status': 'healthy',
        'message': 'API is running',
        'timestamp': datetime.utcnow().isoformat()
    })


@app.route('/api/secure', methods=['GET'])
def secure_endpoint():
    """Secured endpoint that requires JWT Bearer token authentication."""
    is_valid, result = verify_jwt_token()
    
    if not is_valid:
        return jsonify({
            'error': 'Unauthorized',
            'message': result
        }), 401
    
    return jsonify({
        'success': True,
        'message': 'Request authorized successfully!',
        'data': 'This is your secure response data.',
        'version': '1.0.2'
    })


@app.route('/api/services', methods=['GET'])
def list_services():
    """List all Cloud Run services in the project.
    
    Requires JWT Bearer token authentication.
    Returns detailed information about all services including:
    - Service name and URL
    - Description
    - Creation and update times
    - Creator email
    - Health status
    - Traffic routing
    - Scaling configuration
    """
    # Verify JWT token
    is_valid, result = verify_jwt_token()
    if not is_valid:
        return jsonify({
            'error': 'unauthorized',
            'message': result
        }), 401
    
    # Check if project ID is configured
    if not GCP_PROJECT_ID:
        return jsonify({
            'error': 'configuration_error',
            'message': 'GCP_PROJECT_ID environment variable is not set'
        }), 500
    
    try:
        # Initialize Cloud Run client
        client = run_v2.ServicesClient()
        
        # List all services in the project
        parent = f"projects/{GCP_PROJECT_ID}/locations/-"
        request_obj = run_v2.ListServicesRequest(parent=parent)
        
        services = []
        page_result = client.list_services(request=request_obj)
        
        for service in page_result:
            # Extract service information
            service_info = {
                'name': service.name.split('/')[-1],
                'url': service.uri,
                'description': service.description or 'No description provided',
                'created': service.create_time.isoformat() if service.create_time else None,
                'updated': service.update_time.isoformat() if service.update_time else None,
                'creator': service.creator or 'Unknown',
                'region': service.name.split('/')[3],
            }
            
            # Get latest revision info
            if service.latest_ready_revision:
                service_info['latest_revision'] = service.latest_ready_revision.split('/')[-1]
            
            # Get condition status
            if service.conditions:
                ready_condition = next((c for c in service.conditions if c.type == 'Ready'), None)
                if ready_condition:
                    service_info['health'] = ready_condition.state.name
                    if ready_condition.message:
                        service_info['health_message'] = ready_condition.message
            
            # Get ingress settings
            if service.ingress:
                service_info['ingress'] = service.ingress.name
            
            # Get traffic routing
            if service.traffic:
                service_info['traffic'] = [
                    {
                        'type': t.type_.name if hasattr(t.type_, 'name') else str(t.type_),
                        'percent': t.percent,
                        'revision': t.revision.split('/')[-1] if t.revision else None
                    }
                    for t in service.traffic
                ]
            
            # Get scaling configuration
            if service.template and service.template.scaling:
                service_info['scaling'] = {
                    'minInstances': service.template.scaling.min_instance_count,
                    'maxInstances': service.template.scaling.max_instance_count
                }
            
            services.append(service_info)
        
        return jsonify({
            'status': 'success',
            'count': len(services),
            'services': services
        })
        
    except google_exceptions.PermissionDenied as e:
        return jsonify({
            'error': 'permission_denied',
            'message': 'Service account lacks permission to list Cloud Run services',
            'details': str(e)
        }), 403
    except Exception as e:
        return jsonify({
            'error': 'internal_error',
            'message': f'Failed to list services: {str(e)}'
        }), 500


if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
