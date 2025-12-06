"""
Database Test Helpers

Utilities for database operations in tests.
"""

import psycopg2
from typing import Optional, List, Dict, Any, Tuple
from contextlib import contextmanager


@contextmanager
def get_db_connection(
    host: str = 'localhost',
    port: int = 5432,
    database: str = 'app_db',
    user: str = 'postgres',
    password: str = 'postgres'
):
    """
    Context manager for database connection.
    
    Args:
        host: Database host
        port: Database port
        database: Database name
        user: Database user
        password: Database password
        
    Yields:
        Database connection
    """
    conn = psycopg2.connect(
        host=host,
        port=port,
        database=database,
        user=user,
        password=password
    )
    
    try:
        yield conn
    finally:
        conn.close()


def execute_query(
    conn,
    query: str,
    params: Optional[Tuple] = None,
    fetch: bool = True
) -> Optional[List[Tuple]]:
    """
    Execute SQL query.
    
    Args:
        conn: Database connection
        query: SQL query
        params: Query parameters
        fetch: Whether to fetch results
        
    Returns:
        Query results or None
    """
    with conn.cursor() as cursor:
        cursor.execute(query, params)
        
        if fetch:
            return cursor.fetchall()
        else:
            conn.commit()
            return None


def table_exists(conn, table_name: str, schema: str = 'public') -> bool:
    """
    Check if table exists.
    
    Args:
        conn: Database connection
        table_name: Table name
        schema: Schema name
        
    Returns:
        True if table exists
    """
    query = """
        SELECT EXISTS (
            SELECT FROM information_schema.tables 
            WHERE table_schema = %s 
            AND table_name = %s
        );
    """
    
    result = execute_query(conn, query, (schema, table_name))
    return result[0][0] if result else False


def get_table_count(conn, table_name: str, schema: str = 'public') -> int:
    """
    Get row count for table.
    
    Args:
        conn: Database connection
        table_name: Table name
        schema: Schema name
        
    Returns:
        Number of rows
    """
    query = f'SELECT COUNT(*) FROM {schema}.{table_name};'
    result = execute_query(conn, query)
    return result[0][0] if result else 0


def truncate_table(conn, table_name: str, schema: str = 'public', cascade: bool = False):
    """
    Truncate table.
    
    Args:
        conn: Database connection
        table_name: Table name
        schema: Schema name
        cascade: Whether to cascade
    """
    cascade_clause = 'CASCADE' if cascade else ''
    query = f'TRUNCATE TABLE {schema}.{table_name} {cascade_clause};'
    execute_query(conn, query, fetch=False)

