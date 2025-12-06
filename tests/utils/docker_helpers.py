"""
Docker Test Helpers

Utilities for interacting with Docker containers during tests.
"""

import time
import docker
from typing import Optional, Dict, Any, List
from docker.models.containers import Container


def get_docker_client() -> docker.DockerClient:
    """Get Docker client instance."""
    return docker.from_env()


def get_container_by_name(name: str) -> Optional[Container]:
    """
    Get container by name.
    
    Args:
        name: Container name
        
    Returns:
        Container object or None if not found
    """
    client = get_docker_client()
    try:
        return client.containers.get(name)
    except docker.errors.NotFound:
        return None
    finally:
        client.close()


def wait_for_container_healthy(
    container_name: str,
    timeout: int = 60,
    check_interval: int = 2
) -> bool:
    """
    Wait for container to become healthy.
    
    Args:
        container_name: Name of the container
        timeout: Maximum time to wait in seconds
        check_interval: Time between checks in seconds
        
    Returns:
        True if healthy, False if timeout
    """
    client = get_docker_client()
    start_time = time.time()
    
    try:
        while time.time() - start_time < timeout:
            try:
                container = client.containers.get(container_name)
                health = container.attrs.get('State', {}).get('Health', {})
                status = health.get('Status', '')
                
                if status == 'healthy':
                    return True
                elif status == 'unhealthy':
                    return False
                    
            except docker.errors.NotFound:
                pass
                
            time.sleep(check_interval)
            
        return False
    finally:
        client.close()


def get_container_logs(
    container_name: str,
    tail: int = 100,
    since: Optional[int] = None
) -> str:
    """
    Get container logs.
    
    Args:
        container_name: Name of the container
        tail: Number of lines from the end
        since: Only return logs since this time (Unix timestamp)
        
    Returns:
        Container logs as string
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        logs = container.logs(tail=tail, since=since)
        return logs.decode('utf-8')
    except docker.errors.NotFound:
        return ""
    finally:
        client.close()


def exec_in_container(
    container_name: str,
    command: str | List[str],
    user: Optional[str] = None,
    workdir: Optional[str] = None
) -> tuple[int, str]:
    """
    Execute command in container.
    
    Args:
        container_name: Name of the container
        command: Command to execute
        user: User to run as
        workdir: Working directory
        
    Returns:
        Tuple of (exit_code, output)
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        result = container.exec_run(
            command,
            user=user,
            workdir=workdir
        )
        return result.exit_code, result.output.decode('utf-8')
    except docker.errors.NotFound:
        return 1, f"Container {container_name} not found"
    finally:
        client.close()


def get_container_status(container_name: str) -> Optional[str]:
    """
    Get container status.
    
    Args:
        container_name: Name of the container
        
    Returns:
        Status string or None if not found
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        return container.status
    except docker.errors.NotFound:
        return None
    finally:
        client.close()


def get_container_ip(container_name: str, network: str = 'bridge') -> Optional[str]:
    """
    Get container IP address on specified network.
    
    Args:
        container_name: Name of the container
        network: Network name
        
    Returns:
        IP address or None
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        networks = container.attrs.get('NetworkSettings', {}).get('Networks', {})
        network_info = networks.get(network, {})
        return network_info.get('IPAddress')
    except docker.errors.NotFound:
        return None
    finally:
        client.close()


def stop_container(container_name: str, timeout: int = 10) -> bool:
    """
    Stop a container.
    
    Args:
        container_name: Name of the container
        timeout: Timeout in seconds
        
    Returns:
        True if stopped successfully
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        container.stop(timeout=timeout)
        return True
    except docker.errors.NotFound:
        return False
    finally:
        client.close()


def start_container(container_name: str) -> bool:
    """
    Start a container.
    
    Args:
        container_name: Name of the container
        
    Returns:
        True if started successfully
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        container.start()
        return True
    except docker.errors.NotFound:
        return False
    finally:
        client.close()


def restart_container(container_name: str, timeout: int = 10) -> bool:
    """
    Restart a container.
    
    Args:
        container_name: Name of the container
        timeout: Timeout in seconds
        
    Returns:
        True if restarted successfully
    """
    client = get_docker_client()
    try:
        container = client.containers.get(container_name)
        container.restart(timeout=timeout)
        return True
    except docker.errors.NotFound:
        return False
    finally:
        client.close()

