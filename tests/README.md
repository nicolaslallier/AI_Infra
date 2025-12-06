# Test Suite Documentation

## Quick Reference

### Run Tests
```bash
make test              # All tests
make test-unit         # Unit tests
make test-integration  # Integration tests
make test-e2e          # End-to-end tests
```

### Test Structure

- `unit/` - Fast, isolated service tests
- `integration/` - Service interaction tests
- `e2e/` - Complete user workflows
- `performance/` - Load and stress tests
- `api/` - API contract tests
- `regression/` - Prevent breaking changes
- `utils/` - Shared testing utilities
- `fixtures/` - Test data
- `config/` - Test configuration

### Coverage Goals

- Unit tests: **95%+**
- Integration: **100% critical paths**
- E2E: **All user journeys**

### Writing Tests

Follow the examples in `tests/unit/nginx/` for structure and style.

Use utilities from `tests/utils/` for common operations.

Mark tests with appropriate pytest markers:
- `@pytest.mark.unit`
- `@pytest.mark.integration`
- `@pytest.mark.e2e`
- `@pytest.mark.slow`
- `@pytest.mark.docker`

### Reports

Generated in `tests/reports/`:
- Coverage: `coverage-html/index.html`
- Test results: `*-tests.html`
- JUnit XML: `junit-*.xml`
