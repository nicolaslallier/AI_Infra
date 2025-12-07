"""
E2E Tests for MinIO PostgreSQL Backup Integration
Tests the backup and restore workflow.
"""
import pytest
import boto3
from botocore.exceptions import ClientError
from botocore.client import Config
import os
import subprocess
from datetime import datetime

# Configuration
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost/storage")
MINIO_ACCESS_KEY = os.getenv("MINIO_BACKUP_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_BACKUP_SECRET_KEY", "changeme123")
BACKUP_BUCKET = "backups-postgresql"


@pytest.fixture(scope="module")
def s3_client():
    """Create S3 client for MinIO backup operations."""
    try:
        client = boto3.client(
            's3',
            endpoint_url=MINIO_ENDPOINT,
            aws_access_key_id=MINIO_ACCESS_KEY,
            aws_secret_access_key=MINIO_SECRET_KEY,
            config=Config(signature_version='s3v4'),
            region_name='us-east-1'
        )
        return client
    except Exception as e:
        pytest.skip(f"Failed to create S3 client: {str(e)}")


class TestMinIOBackupBucket:
    """Test suite for backup bucket configuration."""
    
    def test_backup_bucket_exists(self, s3_client):
        """Test that backups-postgresql bucket exists."""
        try:
            s3_client.head_bucket(Bucket=BACKUP_BUCKET)
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == '404':
                pytest.skip(f"Backup bucket {BACKUP_BUCKET} not found. Run init-buckets.sh first.")
            else:
                pytest.fail(f"Error accessing backup bucket: {str(e)}")
    
    def test_backup_bucket_accessible(self, s3_client):
        """Test that we can list objects in backup bucket."""
        try:
            response = s3_client.list_objects_v2(Bucket=BACKUP_BUCKET, MaxKeys=1)
            # Should not raise an exception
            assert 'Contents' in response or 'KeyCount' in response
        except ClientError as e:
            pytest.fail(f"Cannot access backup bucket: {str(e)}")
    
    def test_backup_bucket_has_lifecycle_policy(self, s3_client):
        """Test that backup bucket has lifecycle policy configured."""
        try:
            response = s3_client.get_bucket_lifecycle_configuration(Bucket=BACKUP_BUCKET)
            assert 'Rules' in response
            assert len(response['Rules']) > 0
            
            # Check for expiration rule
            has_expiration = any(
                'Expiration' in rule and 'Days' in rule['Expiration']
                for rule in response['Rules']
            )
            assert has_expiration, "No expiration rule found in lifecycle policy"
            
        except ClientError as e:
            error_code = e.response['Error']['Code']
            if error_code == 'NoSuchLifecycleConfiguration':
                pytest.fail("Backup bucket has no lifecycle policy configured")
            else:
                pytest.fail(f"Error checking lifecycle policy: {str(e)}")


class TestMinIOBackupOperations:
    """Test suite for backup upload and retrieval."""
    
    def test_can_upload_backup_file(self, s3_client):
        """Test that we can upload a backup file to MinIO."""
        key = f"test_backup_{datetime.now().strftime('%Y%m%d%H%M%S')}.sql.gz"
        content = b"MOCK BACKUP CONTENT - This simulates a compressed database dump"
        
        try:
            s3_client.put_object(
                Bucket=BACKUP_BUCKET,
                Key=key,
                Body=content,
                ContentType='application/gzip',
                Metadata={
                    'backup-type': 'test',
                    'database': 'test_db',
                    'timestamp': datetime.now().isoformat()
                }
            )
            
            # Verify upload
            response = s3_client.head_object(Bucket=BACKUP_BUCKET, Key=key)
            assert response['ContentLength'] == len(content)
            assert response['Metadata'].get('backup-type') == 'test'
            
            # Cleanup
            s3_client.delete_object(Bucket=BACKUP_BUCKET, Key=key)
            
        except ClientError as e:
            pytest.fail(f"Failed to upload test backup: {str(e)}")
    
    def test_can_download_backup_file(self, s3_client):
        """Test that we can download a backup file from MinIO."""
        key = f"test_download_{datetime.now().strftime('%Y%m%d%H%M%S')}.sql.gz"
        content = b"MOCK BACKUP FOR DOWNLOAD TEST"
        
        try:
            # Upload test file
            s3_client.put_object(
                Bucket=BACKUP_BUCKET,
                Key=key,
                Body=content
            )
            
            # Download it
            response = s3_client.get_object(Bucket=BACKUP_BUCKET, Key=key)
            downloaded_content = response['Body'].read()
            
            assert downloaded_content == content, "Downloaded content doesn't match"
            
            # Cleanup
            s3_client.delete_object(Bucket=BACKUP_BUCKET, Key=key)
            
        except ClientError as e:
            pytest.fail(f"Failed to download test backup: {str(e)}")
    
    def test_can_list_backups(self, s3_client):
        """Test that we can list backup files in the bucket."""
        prefix = f"test_list_{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        try:
            # Upload a few test backups
            for i in range(3):
                s3_client.put_object(
                    Bucket=BACKUP_BUCKET,
                    Key=f"{prefix}_backup_{i}.sql.gz",
                    Body=f"Backup {i}".encode()
                )
            
            # List them
            response = s3_client.list_objects_v2(
                Bucket=BACKUP_BUCKET,
                Prefix=prefix
            )
            
            assert 'Contents' in response
            assert len(response['Contents']) == 3
            
            # Cleanup
            for obj in response['Contents']:
                s3_client.delete_object(Bucket=BACKUP_BUCKET, Key=obj['Key'])
            
        except ClientError as e:
            pytest.fail(f"Failed to list backups: {str(e)}")


class TestMinIOBackupScripts:
    """Test suite for backup/restore scripts."""
    
    def test_backup_script_exists(self):
        """Test that backup script exists and is executable."""
        script_path = "scripts/backup/postgres-to-minio-backup.sh"
        assert os.path.exists(script_path), f"Backup script not found: {script_path}"
        assert os.access(script_path, os.X_OK), f"Backup script not executable: {script_path}"
    
    def test_restore_script_exists(self):
        """Test that restore script exists and is executable."""
        script_path = "scripts/backup/restore-from-minio.sh"
        assert os.path.exists(script_path), f"Restore script not found: {script_path}"
        assert os.access(script_path, os.X_OK), f"Restore script not executable: {script_path}"


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

