"""
Authentication Test Helpers

Utilities for authentication and authorization in tests.
"""

import jwt
import requests
from typing import Dict, Optional
from datetime import datetime, timedelta


def get_keycloak_token(
    keycloak_url: str,
    realm: str,
    client_id: str,
    username: str,
    password: str,
    client_secret: Optional[str] = None
) -> Optional[Dict]:
    """
    Get access token from Keycloak.
    
    Args:
        keycloak_url: Keycloak base URL
        realm: Realm name
        client_id: Client ID
        username: Username
        password: Password
        client_secret: Client secret (if required)
        
    Returns:
        Token response dictionary or None if failed
    """
    token_url = f"{keycloak_url}/realms/{realm}/protocol/openid-connect/token"
    
    data = {
        'grant_type': 'password',
        'client_id': client_id,
        'username': username,
        'password': password,
    }
    
    if client_secret:
        data['client_secret'] = client_secret
    
    try:
        response = requests.post(token_url, data=data, verify=False)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        print(f"Failed to get token: {e}")
        return None


def create_test_user(
    keycloak_url: str,
    realm: str,
    admin_token: str,
    username: str,
    email: str,
    password: str,
    first_name: Optional[str] = None,
    last_name: Optional[str] = None
) -> bool:
    """
    Create test user in Keycloak.
    
    Args:
        keycloak_url: Keycloak base URL
        realm: Realm name
        admin_token: Admin access token
        username: Username
        email: Email address
        password: Password
        first_name: First name
        last_name: Last name
        
    Returns:
        True if successful
    """
    users_url = f"{keycloak_url}/admin/realms/{realm}/users"
    
    user_data = {
        'username': username,
        'email': email,
        'enabled': True,
        'emailVerified': True,
        'credentials': [
            {
                'type': 'password',
                'value': password,
                'temporary': False
            }
        ]
    }
    
    if first_name:
        user_data['firstName'] = first_name
    if last_name:
        user_data['lastName'] = last_name
    
    headers = {'Authorization': f'Bearer {admin_token}', 'Content-Type': 'application/json'}
    
    try:
        response = requests.post(users_url, json=user_data, headers=headers, verify=False)
        return response.status_code == 201
    except requests.exceptions.RequestException:
        return False


def validate_jwt_token(token: str, verify: bool = False) -> Optional[Dict]:
    """
    Decode and validate JWT token.
    
    Args:
        token: JWT token string
        verify: Whether to verify signature
        
    Returns:
        Decoded token payload or None if invalid
    """
    try:
        # For testing, we often don't verify signature
        payload = jwt.decode(token, options={"verify_signature": verify})
        return payload
    except jwt.InvalidTokenError:
        return None


def is_token_expired(token: str) -> bool:
    """
    Check if JWT token is expired.
    
    Args:
        token: JWT token string
        
    Returns:
        True if expired
    """
    payload = validate_jwt_token(token)
    if not payload:
        return True
    
    exp = payload.get('exp')
    if not exp:
        return False
    
    return datetime.fromtimestamp(exp) < datetime.now()

