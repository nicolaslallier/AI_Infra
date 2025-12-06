"""
Wait and Retry Helpers

Utilities for waiting and retrying operations in tests.
"""

import time
from typing import Callable, Any, Optional
from functools import wraps


def wait_for_condition(
    condition_func: Callable[[], bool],
    timeout: int = 60,
    check_interval: float = 1,
    error_message: str = "Condition not met within timeout"
) -> bool:
    """
    Wait for a condition to become true.
    
    Args:
        condition_func: Function that returns True when condition is met
        timeout: Maximum time to wait in seconds
        check_interval: Time between checks in seconds
        error_message: Error message if timeout
        
    Returns:
        True if condition met, False if timeout
        
    Raises:
        TimeoutError: If timeout and raise_on_timeout=True
    """
    start_time = time.time()
    
    while time.time() - start_time < timeout:
        if condition_func():
            return True
        time.sleep(check_interval)
    
    return False


def wait_for_service(
    check_func: Callable[[], bool],
    service_name: str,
    timeout: int = 60,
    check_interval: float = 2
) -> bool:
    """
    Wait for a service to become available.
    
    Args:
        check_func: Function to check service availability
        service_name: Name of service for error messages
        timeout: Maximum time to wait
        check_interval: Time between checks
        
    Returns:
        True if service available, False if timeout
    """
    print(f"Waiting for {service_name} to become available...")
    
    result = wait_for_condition(
        check_func,
        timeout=timeout,
        check_interval=check_interval,
        error_message=f"{service_name} did not become available within {timeout} seconds"
    )
    
    if result:
        print(f"✓ {service_name} is available")
    else:
        print(f"✗ {service_name} not available after {timeout} seconds")
    
    return result


def retry_on_exception(
    max_attempts: int = 3,
    delay: float = 1,
    backoff: float = 2,
    exceptions: tuple = (Exception,)
):
    """
    Decorator to retry function on exception.
    
    Args:
        max_attempts: Maximum number of attempts
        delay: Initial delay between attempts
        backoff: Backoff multiplier
        exceptions: Tuple of exceptions to catch
        
    Returns:
        Decorator function
    """
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            current_delay = delay
            
            for attempt in range(max_attempts):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    if attempt == max_attempts - 1:
                        raise
                    
                    print(f"Attempt {attempt + 1}/{max_attempts} failed: {e}. Retrying in {current_delay}s...")
                    time.sleep(current_delay)
                    current_delay *= backoff
            
        return wrapper
    return decorator


def exponential_backoff(attempt: int, base_delay: float = 1, max_delay: float = 60) -> float:
    """
    Calculate exponential backoff delay.
    
    Args:
        attempt: Current attempt number (0-indexed)
        base_delay: Base delay in seconds
        max_delay: Maximum delay in seconds
        
    Returns:
        Delay in seconds
    """
    delay = base_delay * (2 ** attempt)
    return min(delay, max_delay)

