"""
Metrics Test Helpers

Utilities for validating Prometheus metrics.
"""

import requests
from typing import Dict, List, Optional, Any


def query_prometheus(
    prometheus_url: str,
    query: str,
    time: Optional[str] = None
) -> Optional[Dict]:
    """
    Query Prometheus API.
    
    Args:
        prometheus_url: Prometheus base URL
        query: PromQL query
        time: Optional timestamp
        
    Returns:
        Query result or None if failed
    """
    url = f"{prometheus_url}/api/v1/query"
    params = {'query': query}
    
    if time:
        params['time'] = time
    
    try:
        response = requests.get(url, params=params, verify=False)
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException:
        return None


def get_metric_value(
    prometheus_url: str,
    metric_name: str,
    labels: Optional[Dict[str, str]] = None
) -> Optional[float]:
    """
    Get current value of a metric.
    
    Args:
        prometheus_url: Prometheus base URL
        metric_name: Metric name
        labels: Label selectors
        
    Returns:
        Metric value or None
    """
    query = metric_name
    
    if labels:
        label_str = ','.join([f'{k}="{v}"' for k, v in labels.items()])
        query = f'{metric_name}{{{label_str}}}'
    
    result = query_prometheus(prometheus_url, query)
    
    if result and result.get('status') == 'success':
        data = result.get('data', {}).get('result', [])
        if data:
            return float(data[0].get('value', [None, None])[1])
    
    return None


def metric_exists(prometheus_url: str, metric_name: str) -> bool:
    """
    Check if metric exists in Prometheus.
    
    Args:
        prometheus_url: Prometheus base URL
        metric_name: Metric name
        
    Returns:
        True if metric exists
    """
    result = query_prometheus(prometheus_url, metric_name)
    
    if result and result.get('status') == 'success':
        data = result.get('data', {}).get('result', [])
        return len(data) > 0
    
    return False

