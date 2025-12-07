#!/bin/bash
#
# Populate MinIO with Test Data
#
# This script creates test buckets and uploads sample files to generate
# metrics and data for the MinIO Grafana dashboard.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   MinIO Test Data Population Script${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo

# Get MinIO credentials from docker-compose
echo -e "${YELLOW}📋 Extracting MinIO credentials...${NC}"
MINIO_ROOT_USER=${MINIO_ROOT_USER:-admin}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-changeme123}

echo -e "${GREEN}✓${NC} Using credentials: ${MINIO_ROOT_USER} / ********"
echo

# Function to check if MinIO is accessible
check_minio() {
    echo -e "${YELLOW}🔍 Checking MinIO connectivity...${NC}"
    
    # Check via nginx reverse proxy
    if curl -f -s -o /dev/null http://localhost/storage/minio/health/live; then
        echo -e "${GREEN}✓${NC} MinIO is accessible via nginx"
        MINIO_ENDPOINT="http://localhost/storage"
        return 0
    fi
    
    # Check if any minio container is running
    if ! docker ps | grep -q minio; then
        echo -e "${RED}✗${NC} MinIO cluster is not running"
        echo -e "${YELLOW}→${NC} Start it with: make all-up"
        exit 1
    fi
    
    # Try direct access to minio1 container
    if docker exec ai_infra_minio1 curl -f -s -o /dev/null http://localhost:9000/minio/health/live; then
        echo -e "${GREEN}✓${NC} MinIO is accessible directly"
        MINIO_ENDPOINT="http://minio1:9000"
        return 0
    fi
    
    echo -e "${RED}✗${NC} MinIO is not accessible"
    exit 1
}

# Function to create test data using Python boto3
create_test_data() {
    echo -e "${YELLOW}📦 Creating test data with Python boto3...${NC}"
    
    # Check if boto3 is available in venv
    if [ -f "./venv/bin/python" ]; then
        PYTHON_CMD="./venv/bin/python"
    elif command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    else
        echo -e "${RED}✗${NC} Python not found"
        exit 1
    fi
    
    # Install boto3 if not available
    if ! $PYTHON_CMD -c "import boto3" 2>/dev/null; then
        echo -e "${YELLOW}→${NC} Installing boto3..."
        $PYTHON_CMD -m pip install boto3 -q
    fi
    
    # Create Python script to populate data
    cat > /tmp/populate_minio.py << 'PYTHON_SCRIPT'
import boto3
import io
import random
import string
from datetime import datetime
from botocore.client import Config

# MinIO Configuration
MINIO_ENDPOINT = "http://localhost/storage"
ACCESS_KEY = "admin"
SECRET_KEY = "changeme123"

# Create S3 client
s3_client = boto3.client(
    's3',
    endpoint_url=MINIO_ENDPOINT,
    aws_access_key_id=ACCESS_KEY,
    aws_secret_access_key=SECRET_KEY,
    config=Config(signature_version='s3v4'),
    region_name='us-east-1'
)

def create_bucket(bucket_name):
    """Create a bucket if it doesn't exist"""
    try:
        s3_client.head_bucket(Bucket=bucket_name)
        print(f"  ℹ️  Bucket '{bucket_name}' already exists")
        return False
    except:
        try:
            s3_client.create_bucket(Bucket=bucket_name)
            print(f"  ✓ Created bucket: {bucket_name}")
            return True
        except Exception as e:
            print(f"  ✗ Failed to create bucket '{bucket_name}': {e}")
            return False

def generate_random_content(size_bytes):
    """Generate random content of specified size"""
    return ''.join(random.choices(string.ascii_letters + string.digits, k=size_bytes))

def upload_file(bucket_name, key, content):
    """Upload a file to MinIO"""
    try:
        s3_client.put_object(
            Bucket=bucket_name,
            Key=key,
            Body=content.encode('utf-8') if isinstance(content, str) else content
        )
        return True
    except Exception as e:
        print(f"  ✗ Failed to upload {key}: {e}")
        return False

def main():
    print("\n📦 Creating test buckets and uploading files...\n")
    
    # Define test buckets
    buckets = [
        'test-data',
        'backups-postgresql',
        'application-logs',
        'user-uploads',
        'analytics-data',
        'ml-models',
        'processed-data'
    ]
    
    # Create buckets
    print("1️⃣  Creating buckets:")
    for bucket in buckets:
        create_bucket(bucket)
    
    print("\n2️⃣  Uploading test files:")
    
    # Upload various sizes of files to generate metrics
    file_configs = [
        # test-data bucket - various files
        ('test-data', 'sample-1kb.txt', 1024),
        ('test-data', 'sample-10kb.txt', 10240),
        ('test-data', 'sample-100kb.txt', 102400),
        ('test-data', 'data/sample-1mb.bin', 1048576),
        ('test-data', 'nested/deep/file.txt', 5120),
        
        # backups-postgresql bucket - simulated backups
        ('backups-postgresql', f'backup-{datetime.now().strftime("%Y%m%d")}.sql.gz', 512000),
        ('backups-postgresql', 'backup-20231201.sql.gz', 498000),
        ('backups-postgresql', 'backup-20231202.sql.gz', 510000),
        
        # application-logs bucket - log files
        ('application-logs', 'app.log', 20480),
        ('application-logs', 'error.log', 5120),
        ('application-logs', 'access.log', 30720),
        
        # user-uploads bucket - simulated user files
        ('user-uploads', 'avatar-001.jpg', 51200),
        ('user-uploads', 'avatar-002.jpg', 48000),
        ('user-uploads', 'document.pdf', 204800),
        
        # analytics-data bucket
        ('analytics-data', 'metrics-2024.csv', 102400),
        ('analytics-data', 'events-2024.json', 204800),
        
        # ml-models bucket
        ('ml-models', 'model-v1.pkl', 1048576),
        ('ml-models', 'weights.h5', 2097152),
        
        # processed-data bucket
        ('processed-data', 'output-001.parquet', 524288),
        ('processed-data', 'output-002.parquet', 498000),
    ]
    
    uploaded = 0
    failed = 0
    
    for bucket, key, size in file_configs:
        # Generate random content
        content = generate_random_content(size)
        
        if upload_file(bucket, key, content):
            uploaded += 1
            print(f"  ✓ Uploaded: {bucket}/{key} ({size} bytes)")
        else:
            failed += 1
    
    print(f"\n3️⃣  Summary:")
    print(f"  • Buckets created: {len(buckets)}")
    print(f"  • Files uploaded: {uploaded}")
    if failed > 0:
        print(f"  • Failed uploads: {failed}")
    
    # Calculate total size
    total_size = sum(size for _, _, size in file_configs)
    print(f"  • Total data size: {total_size / 1024 / 1024:.2f} MB")
    
    print("\n✅ Test data population complete!")
    print("\n📊 View the data in:")
    print("  • MinIO Console: http://localhost/minio-console/")
    print("  • Grafana Dashboard: http://localhost/monitoring/grafana/d/minio-overview")

if __name__ == '__main__':
    main()
PYTHON_SCRIPT
    
    # Run the Python script
    echo
    $PYTHON_CMD /tmp/populate_minio.py
    
    # Cleanup
    rm -f /tmp/populate_minio.py
}

# Function to verify data
verify_data() {
    echo
    echo -e "${YELLOW}🔍 Verifying test data...${NC}"
    
    # Wait a moment for metrics to be collected
    echo -e "${YELLOW}→${NC} Waiting 10 seconds for Prometheus to scrape metrics..."
    sleep 10
    
    # Check if buckets exist via Prometheus
    echo -e "${YELLOW}→${NC} Checking Prometheus metrics..."
    
    BUCKET_COUNT=$(curl -s "http://localhost/monitoring/prometheus/api/v1/query?query=count(count%20by%20(bucket)%20(minio_bucket_usage_total_bytes))" | grep -o '"value":\[[^]]*\]' | grep -o '[0-9.]*$' || echo "0")
    
    if [ "$BUCKET_COUNT" != "0" ]; then
        echo -e "${GREEN}✓${NC} Found $BUCKET_COUNT buckets in Prometheus"
    else
        echo -e "${YELLOW}⚠${NC}  No bucket metrics yet (may take up to 30 seconds)"
    fi
}

# Function to show next steps
show_next_steps() {
    echo
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}   Next Steps${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo
    echo -e "1. ${GREEN}View MinIO Console${NC}"
    echo -e "   ${BLUE}http://localhost/minio-console/${NC}"
    echo -e "   Login: admin / changeme123"
    echo
    echo -e "2. ${GREEN}View Grafana Dashboard${NC}"
    echo -e "   ${BLUE}http://localhost/monitoring/grafana/d/minio-overview${NC}"
    echo -e "   Login: admin / admin"
    echo
    echo -e "3. ${GREEN}Generate More Activity${NC}"
    echo -e "   Run this script again to upload more files"
    echo -e "   Or use: ${YELLOW}make validate-minio-dashboard${NC}"
    echo
    echo -e "4. ${GREEN}Monitor Metrics${NC}"
    echo -e "   Prometheus: ${BLUE}http://localhost/monitoring/prometheus${NC}"
    echo -e "   Query: ${YELLOW}minio_bucket_usage_total_bytes${NC}"
    echo
}

# Main execution
main() {
    check_minio
    create_test_data
    verify_data
    show_next_steps
}

main

