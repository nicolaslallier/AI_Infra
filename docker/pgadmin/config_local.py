"""
pgAdmin4 Local Configuration
AI Infrastructure Project - Logging Configuration

This configuration enables JSON structured logging and audit trails
for pgAdmin administrative actions.
"""

import os
import json
import logging
from datetime import datetime

# ============================================
# LOGGING CONFIGURATION
# ============================================

# Set log level from environment variable
LOG_LEVEL = os.environ.get('PGADMIN_LOG_LEVEL', 'INFO').upper()

# Map string levels to logging constants
LOG_LEVEL_MAP = {
    'DEBUG': logging.DEBUG,
    'INFO': logging.INFO,
    'WARNING': logging.WARNING,
    'ERROR': logging.ERROR,
    'CRITICAL': logging.CRITICAL
}

# Configure logging to stdout for container log collection
CONSOLE_LOG_LEVEL = LOG_LEVEL_MAP.get(LOG_LEVEL, logging.INFO)
FILE_LOG_LEVEL = LOG_LEVEL_MAP.get(LOG_LEVEL, logging.INFO)

# Log to /dev/null - we use stdout/stderr for container log collection
# This prevents permission errors with /var/log/pgadmin
LOG_FILE = '/dev/null'

# Enable enhanced logging
ENHANCED_COOKIE_PROTECTION = True

# ============================================
# AUDIT LOGGING
# ============================================

# Enable audit logging for administrative actions
AUDIT_LOG_ENABLED = True

# Log format - JSON structured for parsing by Promtail
LOG_FORMAT = json.dumps({
    "timestamp": "%(asctime)s",
    "level": "%(levelname)s",
    "source": "pgadmin",
    "message": "%(message)s",
    "module": "%(module)s",
    "function": "%(funcName)s",
    "line": "%(lineno)d"
})

# ============================================
# SESSION AND SECURITY
# ============================================

# Session timeout (in minutes)
SESSION_EXPIRATION_TIME = 60

# Enhanced cookie security
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SECURE = False  # Set to True when using HTTPS
SESSION_COOKIE_SAMESITE = 'Lax'

# ============================================
# QUERY LOGGING
# ============================================

# Log query execution for audit purposes
LOG_QUERY_EXECUTION = True

# Maximum query length to log (to avoid excessive log size)
MAX_QUERY_LENGTH = 1000

# ============================================
# AUTHENTICATION LOGGING
# ============================================

# Log authentication attempts (success and failures)
LOG_AUTHENTICATION = True

# Log user actions
LOG_USER_ACTIONS = True

# ============================================
# PERFORMANCE SETTINGS
# ============================================

# Limit the number of records returned by default
MAX_QUERY_RESULTS = 1000

# ============================================
# CUSTOM LOGGING HANDLER
# ============================================

class JSONFormatter(logging.Formatter):
    """Custom JSON formatter for structured logging"""
    
    def format(self, record):
        log_data = {
            "timestamp": datetime.utcnow().isoformat() + "Z",
            "level": record.levelname,
            "source": "pgadmin",
            "message": record.getMessage(),
            "module": record.module,
            "function": record.funcName,
            "line": record.lineno,
            "environment": os.environ.get('ENVIRONMENT', 'development')
        }
        
        # Add user information if available
        if hasattr(record, 'user'):
            log_data['user'] = record.user
        
        # Add database information if available
        if hasattr(record, 'database'):
            log_data['database'] = record.database
        
        # Add request ID for correlation if available
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id
        
        # Add error information if present
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
        
        return json.dumps(log_data)

# Configure logging
LOGGING_CONFIG = {
    'version': 1,
    'disable_existing_loggers': False,
    'formatters': {
        'json': {
            '()': JSONFormatter
        }
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'json',
            'level': LOG_LEVEL,
            'stream': 'ext://sys.stdout'
        }
    },
    'root': {
        'level': LOG_LEVEL,
        'handlers': ['console']
    },
    'loggers': {
        'pgadmin': {
            'level': LOG_LEVEL,
            'handlers': ['console'],
            'propagate': False
        },
        'werkzeug': {
            'level': 'WARNING',
            'handlers': ['console'],
            'propagate': False
        }
    }
}

# ============================================
# AUTHENTICATION CONFIGURATION
# ============================================

# Authentication sources - support both internal and OAuth2 (Keycloak)
# Users can choose to login with internal credentials or Keycloak SSO
# Note: This must be a Python list, not a string
AUTHENTICATION_SOURCES = ['internal', 'oauth2']

# Alternative: read from environment if set, otherwise use default list
import ast
_auth_sources_env = os.environ.get('PGADMIN_AUTHENTICATION_SOURCES', '')
if _auth_sources_env:
    try:
        # Try to parse as Python literal (list)
        AUTHENTICATION_SOURCES = ast.literal_eval(_auth_sources_env)
    except (ValueError, SyntaxError):
        # Fallback: split comma-separated string and strip quotes
        AUTHENTICATION_SOURCES = [s.strip().strip("'\"") for s in _auth_sources_env.split(',')]

# OAuth2 Configuration (Keycloak)
# Note: pgAdmin must access Keycloak through nginx reverse proxy (http://nginx/auth)
# because Keycloak is configured with KC_PROXY=edge and expects proxied requests
OAUTH2_AUTO_CREATE_USER = True

# Determine the Keycloak URL for OAuth2
# Internal container-to-container communication must go through nginx
_keycloak_base_url = 'http://nginx/auth'
_keycloak_realm = os.environ.get('KEYCLOAK_REALM', 'infra-admin')

OAUTH2_CONFIG = [{
    'OAUTH2_NAME': os.environ.get('PGADMIN_OAUTH2_NAME', 'Keycloak'),
    'OAUTH2_DISPLAY_NAME': os.environ.get('PGADMIN_OAUTH2_DISPLAY_NAME', 'Login with Keycloak'),
    'OAUTH2_CLIENT_ID': os.environ.get('PGADMIN_OAUTH2_CLIENT_ID', 'pgadmin-client'),
    'OAUTH2_CLIENT_SECRET': os.environ.get('PGADMIN_OAUTH2_CLIENT_SECRET', ''),
    'OAUTH2_TOKEN_URL': f'{_keycloak_base_url}/realms/{_keycloak_realm}/protocol/openid-connect/token',
    'OAUTH2_AUTHORIZATION_URL': f'{_keycloak_base_url}/realms/{_keycloak_realm}/protocol/openid-connect/auth',
    'OAUTH2_API_BASE_URL': f'{_keycloak_base_url}/realms/{_keycloak_realm}/protocol/',
    'OAUTH2_USERINFO_ENDPOINT': f'{_keycloak_base_url}/realms/{_keycloak_realm}/protocol/openid-connect/userinfo',
    'OAUTH2_SERVER_METADATA_URL': f'{_keycloak_base_url}/realms/{_keycloak_realm}/.well-known/openid-configuration',
    'OAUTH2_SCOPE': os.environ.get('PGADMIN_OAUTH2_SCOPE', 'openid email profile'),
    'OAUTH2_ICON': 'fa-lock',
    'OAUTH2_BUTTON_COLOR': '#0066cc',
}]

# Role mapping from Keycloak to pgAdmin
# Map Keycloak roles to pgAdmin admin status
def OAUTH2_CLAIM_ADMIN_ROLE(user_data):
    """
    Determine if the user should have admin privileges in pgAdmin
    based on their Keycloak roles.
    """
    # Extract roles from token
    realm_access = user_data.get('realm_access', {})
    roles = realm_access.get('roles', [])
    groups = user_data.get('groups', [])
    
    # Grant admin if user has ROLE_DBA or is in DBAs group
    if 'ROLE_DBA' in roles or '/DBAs' in groups:
        return True
    
    # ROLE_DEVOPS gets admin access too
    if 'ROLE_DEVOPS' in roles or '/DevOps' in groups:
        return True
    
    # Default to non-admin (read-only)
    return False

# Username extraction from OAuth2 token
def OAUTH2_USERNAME_MAPPER(user_data):
    """Extract username from OAuth2 user data."""
    return user_data.get('preferred_username', user_data.get('email', 'unknown'))

# Email extraction from OAuth2 token
def OAUTH2_EMAIL_MAPPER(user_data):
    """Extract email from OAuth2 user data."""
    return user_data.get('email', '')

# ============================================
# SECURITY AND COMPLIANCE
# ============================================

# Mask sensitive data in logs
MASK_PASSWORD_IN_LOGS = True

# PII minimization - avoid logging full email addresses
MASK_EMAIL_IN_LOGS = True

# Data retention compliance (logs will be managed by Loki)
# This configuration just ensures we don't store sensitive data unnecessarily

