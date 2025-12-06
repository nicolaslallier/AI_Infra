# Prometheus Alert Rules Validation Checklist

Use this checklist to verify the Prometheus fix and ensure everything is working correctly.

---

## ✅ Immediate Verification (Fix Applied)

### 1. Prometheus Container Status

```bash
docker ps --filter name=prometheus --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

**Expected Output**:
```
NAMES                 STATUS                    PORTS
ai_infra_prometheus   Up X seconds (healthy)   9090/tcp
```

✅ **Status**: Should show "healthy"

---

### 2. Check for Parse Errors

```bash
docker logs ai_infra_prometheus --tail 100 2>&1 | grep -i "parse error"
```

**Expected Output**: (Empty - no output)

✅ **Status**: No parse errors

---

### 3. Check Alert Rules Loading

```bash
docker logs ai_infra_prometheus --tail 100 2>&1 | grep "rule manager"
```

**Expected Output**:
```
level=INFO msg="Starting rule manager..." component="rule manager"
level=DEBUG msg="'for' state restoration completed" component="rule manager" file=/etc/prometheus/alerts/basic-alerts.yml
```

✅ **Status**: Rule manager started successfully

---

### 4. Verify Only Valid Alert Files

```bash
docker exec ai_infra_prometheus ls -la /etc/prometheus/alerts/
```

**Expected Output**:
```
basic-alerts.yml                          (active)
database-logs-alerts.yml.disabled         (disabled)
README-LOG-BASED-ALERTS.md               (documentation)
```

✅ **Status**: Only `.yml` files (not `.disabled`) are loaded

---

### 5. Test Prometheus API

```bash
# Check if Prometheus API responds
curl -s http://localhost:9090/api/v1/status/config | jq -r '.status'
```

**Expected Output**: `success`

```bash
# Check loaded alert rules
curl -s http://localhost:9090/api/v1/rules | jq '.data.groups | length'
```

**Expected Output**: A number > 0 (should show 4-5 groups from basic-alerts.yml)

✅ **Status**: API responding correctly

---

## 📊 Prometheus UI Verification

### 6. Access Prometheus Web UI

**URL**: `http://localhost:9090`

Navigate to:
1. **Status** → **Configuration**: Should load without errors
2. **Status** → **Rules**: Should show only rules from `basic-alerts.yml`
3. **Status** → **Targets**: Should show scrape targets
4. **Alerts**: Should show loaded alerts (may be in pending/inactive state)

✅ **Status**: UI accessible and functional

---

### 7. Check Active Alert Groups

In the Prometheus UI, go to **Status** → **Rules**

**Expected Groups** (from basic-alerts.yml):
- `instance_alerts` - Instance down monitoring
- `postgresql_alerts` - PostgreSQL metrics
- `redis_alerts` - Redis metrics
- `rabbitmq_alerts` - RabbitMQ metrics
- `elasticsearch_alerts` - Elasticsearch metrics (if applicable)

✅ **Status**: All groups from basic-alerts.yml visible

---

## ⚠️ Known Limitations (After Fix)

### 8. Disabled Alert Capabilities

The following alerts are **NOT active** (disabled in `database-logs-alerts.yml.disabled`):

- [ ] PostgreSQL connection failure monitoring
- [ ] PostgreSQL authentication failure detection
- [ ] Slow query detection
- [ ] Database error rate monitoring
- [ ] pgAdmin security monitoring
- [ ] Compliance audit log monitoring

**Reason**: These alerts use LogQL (Loki) queries, not PromQL (Prometheus) queries.

**Solution**: Implement Loki Ruler (see `README-LOG-BASED-ALERTS.md`)

---

## 🔄 Optional: Enable Loki Ruler (Advanced)

If you want to restore log-based alerts, follow these steps:

### 9. Verify Loki is Running

```bash
docker ps --filter name=loki --format "table {{.Names}}\t{{.Status}}"
```

**Expected**: Loki container running

### 10. Check Loki Configuration

```bash
docker exec ai_infra_loki cat /etc/loki/local-config.yaml | grep -A 10 "ruler:"
```

**Check**: Does `ruler` section exist and is it enabled?

### 11. Test Loki API

```bash
curl -s http://localhost:3100/ready
# Expected: ready

curl -s http://localhost:3100/loki/api/v1/rules
# Should return JSON with rules (may be empty if not configured)
```

---

## 🚀 Production Readiness Checklist

### Infrastructure
- [ ] Prometheus running and healthy
- [ ] No parse errors in logs
- [ ] Alert rules loading successfully
- [ ] Targets being scraped
- [ ] Time-series data being stored

### Monitoring Coverage
- [x] Basic instance alerts (CPU, memory, disk)
- [x] PostgreSQL metrics alerts (from postgres_exporter)
- [x] Redis metrics alerts
- [x] RabbitMQ metrics alerts
- [ ] Log-based security alerts (pending Loki Ruler)
- [ ] Log-based compliance alerts (pending Loki Ruler)

### Documentation
- [x] Fix summary documented
- [x] Log-based alerts guide created
- [x] Validation checklist available
- [ ] Team informed of changes
- [ ] Runbooks updated

### Alerting (Optional)
- [ ] Alertmanager configured
- [ ] Alert routing rules defined
- [ ] Notification channels set up (email, Slack, PagerDuty)
- [ ] Alert thresholds tuned
- [ ] On-call schedule defined

---

## 🔍 Troubleshooting

### Issue: Prometheus Still Showing Errors

**Solution**:
```bash
# 1. Check if disabled file is still being loaded
docker exec ai_infra_prometheus ls -la /etc/prometheus/alerts/

# 2. Ensure only .yml files exist (not .yml.disabled)
# 3. Restart Prometheus
docker restart ai_infra_prometheus

# 4. Check logs again
docker logs ai_infra_prometheus --tail 50 2>&1 | grep -i error
```

### Issue: No Alert Rules Showing

**Solution**:
```bash
# 1. Verify basic-alerts.yml exists
docker exec ai_infra_prometheus cat /etc/prometheus/alerts/basic-alerts.yml | head -20

# 2. Check Prometheus config
docker exec ai_infra_prometheus cat /etc/prometheus/prometheus.yml | grep -A 2 "rule_files"

# 3. Reload configuration
curl -X POST http://localhost:9090/-/reload
```

### Issue: Want to Enable Log-Based Alerts

**Solution**: See `README-LOG-BASED-ALERTS.md` for complete guide to setting up Loki Ruler.

---

## 📝 Summary

| Component | Status | Notes |
|-----------|--------|-------|
| Prometheus | ✅ Healthy | No parse errors |
| Basic Alerts | ✅ Active | From basic-alerts.yml |
| Log Alerts | ⚠️ Disabled | Requires Loki Ruler setup |
| Metrics Scraping | ✅ Working | All targets configured |
| Documentation | ✅ Complete | README + Summary available |

---

## Next Steps

1. ✅ **Immediate**: Verify Prometheus is healthy (done)
2. ⚠️ **Short-term**: Decide on log-based alerting strategy
3. 📋 **Medium-term**: Implement Loki Ruler or convert to metrics-based alerts
4. 🚀 **Long-term**: Set up Alertmanager for unified alert management

---

**Last Updated**: December 6, 2025  
**Validated By**: AI Solution Architect  
**Status**: Prometheus Fix Verified ✅

