# Log-Based Alerts - Configuration Guide

## Issue Summary

The `database-logs-alerts.yml` file was originally created with **LogQL (Loki Query Language)** expressions, but was placed in the **Prometheus alerts** directory. This caused Prometheus to fail with parse errors because:

1. **Prometheus uses PromQL** for querying metrics (time-series data)
2. **Loki uses LogQL** for querying logs (text/JSON log entries)
3. These are **incompatible query languages** for different data types

### Error Example

```
parse error: unexpected character: '|'
```

This error occurs when Prometheus encounters LogQL pipe operators like `| json | unwrap`.

## Why This Matters

### Prometheus (PromQL)
- **Data Type**: Time-series metrics (numbers over time)
- **Example Query**: `rate(http_requests_total[5m]) > 100`
- **Use Case**: System metrics, application metrics, resource utilization
- **Alert on**: CPU usage, memory pressure, request rates, error rates from metrics

### Loki (LogQL)
- **Data Type**: Log streams (text/JSON logs)
- **Example Query**: `sum(rate({source="postgres", level="ERROR"}[5m])) > 50`
- **Use Case**: Log analysis, text pattern matching, log aggregation
- **Alert on**: Log messages, authentication failures, error logs, audit events

## Solution Options

### Option 1: Enable Loki Ruler (Recommended for Log-Based Alerts)

Loki has its own alerting component called the **Ruler** that can evaluate LogQL queries and send alerts to Alertmanager.

#### Step 1: Configure Loki Ruler

Edit `docker/loki/loki.yml` to enable the ruler:

```yaml
ruler:
  storage:
    type: local
    local:
      directory: /loki/rules
  rule_path: /tmp/loki/rules-temp
  alertmanager_url: http://alertmanager:9093  # If you have Alertmanager
  ring:
    kvstore:
      store: inmemory
  enable_api: true
  enable_alertmanager_v2: true
```

#### Step 2: Create Loki Rules Directory

```bash
mkdir -p docker/loki/rules
```

#### Step 3: Move Log-Based Alerts to Loki

Rename and move the alert file:

```bash
mv docker/prometheus/alerts/database-logs-alerts.yml.disabled \
   docker/loki/rules/database-logs-alerts.yml
```

#### Step 4: Update docker-compose.yml

Add the rules volume mount to Loki service:

```yaml
loki:
  # ... existing config ...
  volumes:
    - ./docker/loki/loki.yml:/etc/loki/local-config.yaml:ro
    - ./docker/loki/rules:/loki/rules:ro  # Add this line
    - loki-data:/loki
```

#### Step 5: Restart Services

```bash
docker-compose restart loki
```

### Option 2: Convert to Prometheus Metrics-Based Alerts

If you prefer Prometheus-native alerting, you need to:

1. **Use a metrics exporter** that converts logs to metrics
2. **Create alerts based on those metrics**

#### Example: PostgreSQL Connection Failures (Prometheus Style)

Instead of querying logs directly, use metrics from postgres_exporter:

```yaml
groups:
  - name: postgres_metrics_alerts
    interval: 1m
    rules:
      - alert: PostgreSQLConnectionFailures
        expr: |
          rate(pg_stat_database_xact_rollback{datname!~"template.*|postgres"}[5m]) > 10
        for: 5m
        labels:
          severity: warning
          component: postgres
        annotations:
          summary: "High database transaction rollback rate"
          description: "Database {{ $labels.datname }} has {{ $value }} rollbacks per second"
```

**Pros**: Native Prometheus, better performance for time-series data
**Cons**: Limited to metrics that exporters provide, can't query arbitrary log messages

### Option 3: Hybrid Approach (Best of Both)

Use **both** Loki and Prometheus alerting:

- **Prometheus**: For metrics-based alerts (CPU, memory, request rates, response times)
- **Loki Ruler**: For log-based alerts (authentication failures, error patterns, audit events)
- **Alertmanager**: Centralized alert routing and notification (both send alerts here)

```
┌─────────────┐     ┌──────────────┐     ┌────────────────┐
│ Prometheus  │────▶│ Alertmanager │────▶│ Notifications  │
│ (PromQL)    │     │              │     │ (Email, Slack) │
└─────────────┘     └──────────────┘     └────────────────┘
                           ▲
                           │
┌─────────────┐           │
│ Loki Ruler  │───────────┘
│ (LogQL)     │
└─────────────┘
```

## Current Status

The file `database-logs-alerts.yml.disabled` contains valuable alert definitions but cannot be used with Prometheus as-is. It has been disabled to prevent errors.

### Alerts Currently Disabled

All alerts in `database-logs-alerts.yml.disabled` are log-based:

1. **Connection Alerts**: PostgreSQL auth failures, connection spikes
2. **Performance Alerts**: Slow query detection, query percentiles
3. **Error Alerts**: High error rates, critical errors, disk space warnings
4. **Availability Alerts**: Database down detection
5. **Security Alerts**: Suspicious activity, unauthorized access attempts
6. **pgAdmin Alerts**: Admin interface monitoring, security events
7. **Compliance Alerts**: Audit log gaps, privilege operations

### Next Steps

Choose one of the options above and implement it. For a production system, I recommend:

1. **Short term**: Use Option 1 (Loki Ruler) to keep the existing log-based alerts
2. **Long term**: Implement Option 3 (Hybrid) for comprehensive monitoring

## Alertmanager Setup (Optional but Recommended)

If you don't have Alertmanager yet, add it to your stack:

```yaml
# docker-compose.yml
alertmanager:
  image: prom/alertmanager:latest
  container_name: ai_infra_alertmanager
  ports:
    - "9093:9093"
  volumes:
    - ./docker/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
  networks:
    - monitoring-net
  restart: unless-stopped
```

Then configure it in both Prometheus and Loki to send alerts there.

## Testing Alerts

### Test Prometheus Alerts

```bash
# Check if alerts are loaded
curl http://localhost:9090/api/v1/rules

# Check active alerts
curl http://localhost:9090/api/v1/alerts
```

### Test Loki Ruler (after setup)

```bash
# Check if rules are loaded
curl http://localhost:3100/loki/api/v1/rules

# Check active alerts
curl http://localhost:3100/prometheus/api/v1/alerts
```

## References

- [Prometheus Alerting](https://prometheus.io/docs/prometheus/latest/configuration/alerting_rules/)
- [Loki Ruler Documentation](https://grafana.com/docs/loki/latest/rules/)
- [LogQL Documentation](https://grafana.com/docs/loki/latest/logql/)
- [PromQL Documentation](https://prometheus.io/docs/prometheus/latest/querying/basics/)

## Architecture Decision

**Decision**: Keep log-based alerts disabled in Prometheus until Loki Ruler is properly configured.

**Rationale**:
- Prevents Prometheus startup errors
- Maintains clear separation between metrics and logs alerting
- Allows for proper implementation of log-based alerting in Loki
- Follows observability best practices

**Impact**: No log-based alerts are currently active. Only metrics-based alerts from `basic-alerts.yml` are active.

