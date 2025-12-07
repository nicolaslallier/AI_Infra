"""
E2E Tests for MinIO S3 API Operations
Tests basic S3 operations (PUT, GET, DELETE) using boto3.
Requires MinIO credentials to be set in environment variables.
"""
import pytest
import boto3
from botocore.exceptions import ClientError, EndpointConnectionError
from botocore.client import Config
import os
import io
from datetime import datetime

# MinIO configuration
MINIO_ENDPOINT = os.getenv("MINIO_ENDPOINT", "http://localhost/storage")
MINIO_ACCESS_KEY = os.getenv("MINIO_ACCESS_KEY", "admin")
MINIO_SECRET_KEY = os.getenv("MINIO_SECRET_KEY", "changeme123")
TEST_BUCKET = os.getenv("TEST_BUCKET", "test-bucket")


@pytest.fixture(scope="module")
def s3_client():
    """Create S3 client for MinIO."""
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


@pytest.fixture(scope="module")
def test_bucket(s3_client):
    """Create test bucket if it doesn't exist."""
    try:
        # Check if bucket exists
        s3_client.head_bucket(Bucket=TEST_BUCKET)
    except ClientError as e:
        error_code = e.response['Error']['Code']
        if error_code == '404':
            # Bucket doesn't exist, create it
            try:
                s3_client.create_bucket(Bucket=TEST_BUCKET)
            except ClientError:
                pytest.skip(f"Failed to create test bucket: {TEST_BUCKET}")
        else:
            pytest.skip(f"Error accessing bucket: {str(e)}")
    
    yield TEST_BUCKET
    
    # Cleanup: Delete test objects (but keep the bucket)
    try:
        response = s3_client.list_objects_v2(Bucket=TEST_BUCKET, Prefix="test-")
        if 'Contents' in response:
            objects_to_delete = [{'Key': obj['Key']} for obj in response['Contents']]
            if objects_to_delete:
                s3_client.delete_objects(
                    Bucket=TEST_BUCKET,
                    Delete={'Objects': objects_to_delete}
                )
    except Exception:
        pass  # Cleanup is best effort


class TestMinIOConnection:
    """Test suite for MinIO S3 connection."""
    
    def test_s3_client_can_connect(self, s3_client):
        """Test that S3 client can connect to MinIO."""
        try:
            # List buckets to verify connection
            response = s3_client.list_buckets()
            assert 'Buckets' in response, "Failed to list buckets"
        except EndpointConnectionError:
            pytest.fail("Cannot connect to MinIO endpoint")
        except ClientError as e:
            pytest.fail(f"S3 client connection failed: {str(e)}")


class TestMinIOBucketOperations:
    """Test suite for bucket operations."""
    
    def test_list_buckets(self, s3_client):
        """Test listing buckets."""
        try:
            response = s3_client.list_buckets()
            assert 'Buckets' in response
            assert isinstance(response['Buckets'], list)
        except ClientError as e:
            pytest.fail(f"Failed to list buckets: {str(e)}")
    
    def test_bucket_exists(self, s3_client, test_bucket):
        """Test that test bucket exists."""
        try:
            s3_client.head_bucket(Bucket=test_bucket)
        except ClientError as e:
            pytest.fail(f"Test bucket {test_bucket} does not exist: {str(e)}")


class TestMinIOObjectOperations:
    """Test suite for object operations (PUT, GET, DELETE)."""
    
    def test_put_object(self, s3_client, test_bucket):
        """Test uploading an object to MinIO."""
        key = f"test-object-{datetime.now().strftime('%Y%m%d%H%M%S')}.txt"
        content = b"This is a test object for MinIO E2E testing."
        
        try:
            s3_client.put_object(
                Bucket=test_bucket,
                Key=key,
                Body=content,
                ContentType='text/plain'
            )
            
            # Verify object exists
            response = s3_client.head_object(Bucket=test_bucket, Key=key)
            assert response['ContentLength'] == len(content)
            
        except ClientError as e:
            pytest.fail(f"Failed to put object: {str(e)}")
    
    def test_get_object(self, s3_client, test_bucket):
        """Test downloading an object from MinIO."""
        key = f"test-get-{datetime.now().strftime('%Y%m%d%H%M%S')}.txt"
        content = b"Test content for GET operation."
        
        try:
            # First, put an object
            s3_client.put_object(
                Bucket=test_bucket,
                Key=key,
                Body=content
            )
            
            # Then, get it back
            response = s3_client.get_object(Bucket=test_bucket, Key=key)
            retrieved_content = response['Body'].read()
            
            assert retrieved_content == content, "Retrieved content doesn't match"
            
        except ClientError as e:
            pytest.fail(f"Failed to get object: {str(e)}")
    
    def test_delete_object(self, s3_client, test_bucket):
        """Test deleting an object from MinIO."""
        key = f"test-delete-{datetime.now().strftime('%Y%m%d%H%M%S')}.txt"
        content = b"This object will be deleted."
        
        try:
            # Put an object
            s3_client.put_object(
                Bucket=test_bucket,
                Key=key,
                Body=content
            )
            
            # Delete it
            s3_client.delete_object(Bucket=test_bucket, Key=key)
            
            # Verify it's gone
            with pytest.raises(ClientError) as exc_info:
                s3_client.head_object(Bucket=test_bucket, Key=key)
            
            assert exc_info.value.response['Error']['Code'] == '404'
            
        except ClientError as e:
            pytest.fail(f"Failed to delete object: {str(e)}")
    
    def test_list_objects(self, s3_client, test_bucket):
        """Test listing objects in a bucket."""
        # Put a few test objects
        prefix = f"test-list-{datetime.now().strftime('%Y%m%d%H%M%S')}"
        
        try:
            for i in range(3):
                s3_client.put_object(
                    Bucket=test_bucket,
                    Key=f"{prefix}-{i}.txt",
                    Body=f"Object {i}".encode()
                )
            
            # List objects
            response = s3_client.list_objects_v2(
                Bucket=test_bucket,
                Prefix=prefix
            )
            
            assert 'Contents' in response
            assert len(response['Contents']) == 3
            
        except ClientError as e:
            pytest.fail(f"Failed to list objects: {str(e)}")


class TestMinIOMultipartUpload:
    """Test suite for multipart upload functionality."""
    
    def test_multipart_upload(self, s3_client, test_bucket):
        """Test multipart upload for large files."""
        key = f"test-multipart-{datetime.now().strftime('%Y%m%d%H%M%S')}.bin"
        part_size = 5 * 1024 * 1024  # 5MB per part
        num_parts = 2
        
        try:
            # Initiate multipart upload
            response = s3_client.create_multipart_upload(
                Bucket=test_bucket,
                Key=key
            )
            upload_id = response['UploadId']
            
            # Upload parts
            parts = []
            for i in range(num_parts):
                part_data = os.urandom(part_size)
                part_response = s3_client.upload_part(
                    Bucket=test_bucket,
                    Key=key,
                    PartNumber=i + 1,
                    UploadId=upload_id,
                    Body=part_data
                )
                parts.append({
                    'PartNumber': i + 1,
                    'ETag': part_response['ETag']
                })
            
            # Complete multipart upload
            s3_client.complete_multipart_upload(
                Bucket=test_bucket,
                Key=key,
                UploadId=upload_id,
                MultipartUpload={'Parts': parts}
            )
            
            # Verify object exists
            response = s3_client.head_object(Bucket=test_bucket, Key=key)
            assert response['ContentLength'] == part_size * num_parts
            
        except ClientError as e:
            pytest.fail(f"Multipart upload failed: {str(e)}")


if __name__ == "__main__":
    pytest.main([__file__, "-v"])

