# End-to-End (E2E) Tests

## Overview

E2E tests validate complete user workflows across the entire infrastructure stack. These tests require all services to be running and test real-world scenarios.

## Test Coverage

### 1. Full Stack Health (`test_full_stack_health.py`)
- ✅ Nginx accessibility and health
- ✅ Frontend application loading
- ✅ Grafana dashboard access
- ✅ Prometheus metrics collection
- ✅ Tempo tracing availability
- ✅ Loki logging availability
- ✅ Keycloak authentication service
- ✅ pgAdmin database management
- ✅ Service integration validation

### 2. Monitoring Stack (`test_monitoring_stack.py`)
- ✅ Prometheus configuration and targets
- ✅ Prometheus query execution
- ✅ Prometheus range queries
- ✅ Grafana health and API access
- ✅ Loki log query functionality
- ✅ Tempo trace collection
- ✅ Observability component integration
- ✅ Metrics scraping validation

### 3. Keycloak Authentication (`test_keycloak_auth.py`)
- ✅ Keycloak realm configuration
- ✅ OpenID Connect endpoints
- ✅ Authentication flow validation
- ✅ Admin console access
- ✅ Token endpoint functionality
- ✅ Database connection validation
- ✅ Nginx proxy integration

### 4. Database Stack (`test_database_stack.py`)
- ✅ pgAdmin web interface
- ✅ pgAdmin API endpoints
- ✅ PostgreSQL metrics in Prometheus
- ✅ Database connection metrics
- ✅ Keycloak-PostgreSQL integration
- ✅ Grafana-PostgreSQL integration

### 5. Nginx Routing (`test_nginx_routing.py`)
- ✅ Service routing validation
- ✅ Redirect behavior
- ✅ Subpath routing
- ✅ Header forwarding
- ✅ Gzip compression
- ✅ Response time validation
- ✅ Concurrent request handling

### 6. User Workflows (`test_user_workflows.py`)
- ✅ Basic user interactions
- ✅ Admin workflows
- ✅ DevOps workflows
- ✅ Multiple concurrent users
- ✅ Performance under load
- ✅ Error handling

## Running E2E Tests

### Prerequisites

1. **Start all services:**
   ```bash
   docker-compose up -d
   ```

2. **Wait for services to be ready:**
   ```bash
   # Check all services are up
   docker-compose ps
   
   # Wait for health checks
   curl http://localhost/health
   ```

3. **Ensure test environment is set up:**
   ```bash
   source venv/bin/activate
   ```

### Run All E2E Tests

```bash
# Using make
make test-e2e

# Using pytest directly
pytest tests/e2e -v

# With markers
pytest tests/e2e -m "e2e" -v
```

### Run Specific Test Suites

```bash
# Full stack health only
pytest tests/e2e/test_full_stack_health.py -v

# Monitoring stack only
pytest tests/e2e/test_monitoring_stack.py -v

# User workflows only
pytest tests/e2e/test_user_workflows.py -v

# Critical tests only
pytest tests/e2e -m "critical" -v

# Slow tests (with increased timeout)
pytest tests/e2e -m "slow" -v --timeout=600
```

### Run Specific Test Cases

```bash
# Single test
pytest tests/e2e/test_full_stack_health.py::TestFullStackHealth::test_nginx_is_accessible -v

# Test class
pytest tests/e2e/test_monitoring_stack.py::TestPrometheusStack -v

# Pattern matching
pytest tests/e2e -k "health" -v
pytest tests/e2e -k "prometheus" -v
```

## Test Markers

E2E tests use the following pytest markers:

- `@pytest.mark.e2e` - All E2E tests
- `@pytest.mark.critical` - Critical path tests that must always pass
- `@pytest.mark.slow` - Tests that take longer to execute
- `@pytest.mark.database` - Tests requiring database access
- `@pytest.mark.network` - Tests requiring network access

## Service Dependencies

E2E tests require these services to be running:

| Service | Port | Health Check |
|---------|------|--------------|
| Nginx | 80 | http://localhost/health |
| Frontend | (via Nginx) | http://localhost/ |
| Prometheus | (via Nginx) | http://localhost/monitoring/prometheus/-/healthy |
| Grafana | (via Nginx) | http://localhost/monitoring/grafana/api/health |
| Tempo | (via Nginx) | http://localhost/monitoring/tempo/ready |
| Loki | (via Nginx) | http://localhost/monitoring/loki/ready |
| Keycloak | (via Nginx) | http://localhost/auth/realms/master |
| pgAdmin | (via Nginx) | http://localhost/pgadmin/ |
| PostgreSQL | 5432 | (internal) |

## Expected Test Duration

- **Fast tests** (health checks): ~30 seconds
- **Standard tests** (full suite): ~2-3 minutes  
- **Slow tests** (with load testing): ~5-10 minutes

## Troubleshooting

### Tests Fail with Connection Errors

**Problem**: `Connection refused` or timeout errors

**Solution**:
```bash
# Check if services are running
docker-compose ps

# Start services if needed
docker-compose up -d

# Wait for health checks
sleep 30

# Verify services are accessible
curl http://localhost/health
```

### Tests Fail with "Service not ready"

**Problem**: Services are starting but not yet healthy

**Solution**:
```bash
# Check service logs
docker-compose logs grafana
docker-compose logs prometheus

# Wait longer for services
sleep 60

# Run tests with increased timeout
pytest tests/e2e -v --timeout=600
```

### Intermittent Test Failures

**Problem**: Tests pass sometimes, fail others

**Solution**:
```bash
# Run tests with retries
pytest tests/e2e -v --reruns 3 --reruns-delay 5

# Increase wait times in conftest.py
# Edit: tests/e2e/conftest.py
# Change: max_retries = 30 to max_retries = 60
```

### Performance Tests Fail

**Problem**: Response times too slow

**Solution**:
```bash
# Check system resources
docker stats

# Check for resource constraints
docker-compose logs | grep -i "error\|warn"

# Restart services
docker-compose restart

# Run performance tests separately
pytest tests/e2e -m "slow" -v
```

## Writing New E2E Tests

### Template

```python
import pytest
import requests

@pytest.mark.e2e
class TestMyFeature:
    """Test complete workflow for my feature."""
    
    def test_my_workflow(self, base_url, wait_for_services):
        """Test that users can complete my workflow."""
        # Step 1: Access the feature
        response = requests.get(f"{base_url}/my-feature", timeout=10)
        assert response.status_code == 200
        
        # Step 2: Interact with the feature
        # ... add your test steps
        
        # Step 3: Verify expected outcome
        assert "expected content" in response.text
```

### Best Practices

1. **Use descriptive test names** that explain the scenario
2. **Test complete workflows** from user perspective
3. **Use appropriate timeouts** (default: 10 seconds)
4. **Add retries** for flaky network operations
5. **Clean up after tests** if they create data
6. **Use fixtures** for common setup/teardown
7. **Mark tests appropriately** (e2e, slow, critical, etc.)
8. **Test both happy paths and error cases**

## CI/CD Integration

E2E tests are designed to run in CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: E2E Tests

on: [push, pull_request]

jobs:
  e2e-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Start services
        run: docker-compose up -d
      
      - name: Wait for services
        run: sleep 60
      
      - name: Run E2E tests
        run: |
          source venv/bin/activate
          pytest tests/e2e -v --junitxml=test-results.xml
      
      - name: Upload results
        uses: actions/upload-artifact@v2
        with:
          name: test-results
          path: test-results.xml
```

## Coverage Goals

Current E2E test coverage:
- ✅ Infrastructure health: 100%
- ✅ Service routing: 100%
- ✅ Monitoring stack: 90%
- ✅ Authentication: 80%
- ✅ Database access: 70%
- ✅ User workflows: 80%

**Overall E2E Coverage**: ~85%

## Next Steps

1. Add authentication flow tests with actual login
2. Add database CRUD operation tests
3. Add frontend interaction tests with Selenium/Playwright
4. Add API contract tests
5. Add chaos engineering tests (service failure scenarios)

## Support

For issues or questions:
1. Check service logs: `docker-compose logs [service-name]`
2. Review test output: `pytest tests/e2e -v -s`
3. Check health endpoints manually
4. Review `HOW_TO_RUN_TESTS.md` for general testing guidance

