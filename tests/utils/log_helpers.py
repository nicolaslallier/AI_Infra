"""
Log Test Helpers

Utilities for parsing and validating logs.
"""

import re
import json
from typing import List, Dict, Optional
from datetime import datetime


def parse_json_log(log_line: str) -> Optional[Dict]:
    """
    Parse JSON-formatted log line.
    
    Args:
        log_line: Log line string
        
    Returns:
        Parsed log dict or None if not valid JSON
    """
    try:
        return json.loads(log_line)
    except json.JSONDecodeError:
        return None


def filter_logs_by_level(logs: List[str], level: str) -> List[str]:
    """
    Filter logs by log level.
    
    Args:
        logs: List of log lines
        level: Log level (ERROR, WARN, INFO, DEBUG)
        
    Returns:
        Filtered logs
    """
    return [log for log in logs if level.upper() in log.upper()]


def extract_timestamps(logs: List[str], pattern: str = r'\d{4}-\d{2}-\d{2}[T\s]\d{2}:\d{2}:\d{2}') -> List[str]:
    """
    Extract timestamps from logs.
    
    Args:
        logs: List of log lines
        pattern: Regex pattern for timestamp
        
    Returns:
        List of timestamps
    """
    timestamps = []
    for log in logs:
        match = re.search(pattern, log)
        if match:
            timestamps.append(match.group())
    return timestamps


def count_log_occurrences(logs: List[str], pattern: str) -> int:
    """
    Count occurrences of pattern in logs.
    
    Args:
        logs: List of log lines
        pattern: Pattern to search for
        
    Returns:
        Number of occurrences
    """
    count = 0
    for log in logs:
        if re.search(pattern, log, re.IGNORECASE):
            count += 1
    return count

