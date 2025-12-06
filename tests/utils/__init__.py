"""
Test Utilities

Shared utilities for all tests.
"""

from .docker_helpers import (
    get_container_by_name,
    wait_for_container_healthy,
    get_container_logs,
    exec_in_container,
)

from .http_helpers import (
    make_request,
    wait_for_url,
    check_http_status,
    make_authenticated_request,
)

from .wait_helpers import (
    wait_for_condition,
    wait_for_service,
    retry_on_exception,
)

from .db_helpers import (
    get_db_connection,
    execute_query,
    table_exists,
    get_table_count,
)

from .auth_helpers import (
    get_keycloak_token,
    create_test_user,
    validate_jwt_token,
)

__all__ = [
    # Docker helpers
    'get_container_by_name',
    'wait_for_container_healthy',
    'get_container_logs',
    'exec_in_container',
    # HTTP helpers
    'make_request',
    'wait_for_url',
    'check_http_status',
    'make_authenticated_request',
    # Wait helpers
    'wait_for_condition',
    'wait_for_service',
    'retry_on_exception',
    # Database helpers
    'get_db_connection',
    'execute_query',
    'table_exists',
    'get_table_count',
    # Auth helpers
    'get_keycloak_token',
    'create_test_user',
    'validate_jwt_token',
]

