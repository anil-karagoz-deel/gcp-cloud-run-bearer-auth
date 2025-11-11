#!/usr/bin/env python3
"""
JWT Token Generator for GCP Cloud Run Bearer Auth Service

Usage:
    python3 generate_jwt.py [--secret YOUR_SECRET] [--days EXPIRATION_DAYS]

Example:
    python3 generate_jwt.py --secret my-secret-key --days 365
"""

import jwt
import secrets
import argparse
from datetime import datetime, timedelta, timezone


def generate_jwt_token(secret_key: str, expiration_days: int = 365) -> str:
    """
    Generate a JWT token with the specified secret key and expiration.
    
    Args:
        secret_key: Secret key for signing the JWT
        expiration_days: Number of days until token expires
    
    Returns:
        JWT token string
    """
    now = datetime.now(timezone.utc)
    
    payload = {
        'sub': 'cloud-run-service',  # Subject
        'iat': now,  # Issued at
        'exp': now + timedelta(days=expiration_days),  # Expiration
        'iss': 'gcp-bearer-auth-service',  # Issuer
    }
    
    token = jwt.encode(payload, secret_key, algorithm='HS256')
    return token


def main():
    parser = argparse.ArgumentParser(
        description='Generate JWT tokens for the GCP Cloud Run service'
    )
    parser.add_argument(
        '--secret',
        type=str,
        help='Secret key for signing the JWT (will generate one if not provided)'
    )
    parser.add_argument(
        '--days',
        type=int,
        default=365,
        help='Number of days until token expires (default: 365)'
    )
    parser.add_argument(
        '--generate-secret',
        action='store_true',
        help='Only generate a new secret key without creating a token'
    )
    
    args = parser.parse_args()
    
    # Generate secret if not provided
    if not args.secret:
        secret_key = secrets.token_urlsafe(32)
        print("🔑 Generated new secret key:")
        print(f"   {secret_key}")
        print()
    else:
        secret_key = args.secret
    
    if args.generate_secret:
        return
    
    # Generate JWT token
    token = generate_jwt_token(secret_key, args.days)
    
    print("✅ JWT Token generated successfully!")
    print("━" * 60)
    print()
    print("🔐 Secret Key:")
    print(f"   {secret_key}")
    print()
    print("🎫 JWT Token (starts with 'eyJ'):")
    print(f"   {token}")
    print()
    print(f"⏰ Expires in: {args.days} days")
    print()
    print("💡 Usage:")
    print(f'   curl -H "Authorization: Bearer {token}" https://your-service-url/api/secure')
    print()
    print("⚠️  Save the secret key in your .env file as JWT_SECRET_KEY")
    print("   The service needs this to verify tokens!")


if __name__ == '__main__':
    main()
