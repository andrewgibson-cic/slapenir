# SLAPENIR Performance Baselines

Performance characteristics and thresholds for production readiness.

## Overview

SLAPENIR is a zero-knowledge credential sanitization proxy designed for high-throughput, low-latency operation. This document establishes performance baselines, acceptable thresholds, and monitoring strategies.

## Performance Targets

### Latency Requirements

| Operation | p50 | p95 | p99 | Max | Status |
|-----------|-----|-----|-----|-----|--------|
| Health check | <5ms | <10ms | <20ms | <50ms | Required |
| Metrics scrape | <10ms | <25ms | <50ms | <100ms | Required |
| Small payload sanitization (<1KB) | <10ms | <25ms | <50ms | <100ms | Required |
| Medium payload sanitization (1-100KB) | <50ms | <100ms | <200ms | <500ms | Required |
| Large payload sanitization (>100KB) | <200ms | <500ms | <1000ms | <2000ms | Required |
| Proxy request (passthrough) | <20ms | <50ms | <100ms | <200ms | Required |

### Throughput Requirements

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Requests per second | >1000 req/s | TBD | Required |
| Concurrent connections | >1000 | TBD | Required |
| Data throughput | >10 MB/s | TBD | Required |
| Secrets sanitized/s | >10000 | TBD | Required |

### Resource Utilization

| Resource | Limit | Target | Critical | Status |
|----------|------|--------|----------|--------|
| CPU | 4 cores | <70% | <90% | Required |
| Memory | 2GB | <1.5GB | <1.8GB | Required |
| File descriptors | 65536 | <10000 | <30000 | Required |
| Network I/O | 1Gbps | <500Mbps | <800Mbps | Required |

### Availability & Reliability

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Uptime SLA | 99.9% | TBD | Required |
| Error rate | <0.1% | TBD | Required |
| Timeouts | <0.01% | TBD | Required |
| Successful requests | >99.9% | TBD | Required |

## Performance Baselines

### Benchmark Results

Run benchmarks locally:
```bash
cd proxy
cargo bench
```

Expected results (based on development environment):

#### Sanitization Performance
- **Small text (<100 bytes)**: ~1-5µs per operation
- **Medium text (1-10KB)**: ~50-200µs per operation
- **Large text (>100KB)**: ~1-5ms per operation
- **Throughput**: >10 MB/s

#### Injection Performance
- **Small text (<100 bytes)**: ~1-5µs per operation
- **Medium text (1-10KB)**: ~50-200µs per operation
- **Large text (>100KB)**: ~1-5ms per operation
- **Throughput**: >10 MB/s

#### Secret Map Creation
- **10 secrets**: ~50-100µs
- **100 secrets**: ~200-500µs
- **500 secrets**: ~1-2ms

#### Byte Sanitization
- **Binary data (1KB)**: ~10-50µs
- **Binary data (100KB)**: ~1-3ms
- **Binary data (1MB)**: ~10-30ms

### Load Test Results

Run load tests:
```bash
cd proxy/tests/load
./run_all_load_tests.sh
```

Expected results:

#### API Load Test
- **Concurrent users**: 100-200
- **p95 latency**: <200ms
- **p99 latency**: <500ms
- **Error rate**: <0.1%
- **Throughput**: >1000 req/s

#### Stress Test
- **Breaking point**: >500 concurrent users
- **Max sustainable load**: 75% of breaking point (~375 users)
- **Graceful degradation**: Linear latency increase up to breaking point

#### Soak Test (30 minutes)
- **Sustained load**: 100 VUs
- **Memory leak detection**: No increasing latency trend
- **Error rate**: <0.1%
- **Throughput**: Consistent >1.5 req/s

## Monitoring Strategy

### Key Metrics to Track

#### Application Metrics
- `http_request_duration_seconds` (histogram)
- `http_requests_total` (counter)
- `sanitization_operations_total` (counter)
- `secrets_sanitized_total` (counter)
- `active_connections` (gauge)

#### System Metrics
- CPU utilization
- Memory utilization
- Network I/O
- File descriptor count
- Tokio task/thread count

### Alerting Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| p95 latency | >300ms | >500ms | Investigate performance degradation |
| p99 latency | >800ms | >1000ms | Immediate investigation required |
| Error rate | >0.5% | >1% | Check logs, possible service degradation |
| CPU usage | >80% | >90% | Scale horizontally |
| Memory usage | >1.8GB | >1.9GB | Check for memory leaks |
| Connection count | >800 | >950 | Prepare to scale |

### Grafana Dashboard Panels

1. **Request Rate** (QPS)
2. **Latency Percentiles** (p50, p95, p99)
3. **Error Rate** (%)
4. **Active Connections**
5. **CPU/Memory Usage**
6. **Sanitization Rate**
7. **Throughput** (bytes/sec)

## Performance Testing Schedule

### Pre-Production
- Run full benchmark suite before each release
- Execute load tests on staging environment
- Verify performance baselines maintained

### Production
- Continuous performance monitoring via Prometheus
- Daily automated load tests during low-traffic periods
- Monthly stress tests to verify breaking point hasn't degraded

### Regression Testing
- Automated performance regression tests in CI
- Alert on >10% latency increase from baseline
- Alert on >5% throughput decrease from baseline

## Capacity Planning

### Current Capacity (per instance)
- **Concurrent users**: 200-500
- **Requests/second**: 1000-2000
- **Data throughput**: 10-50 MB/s

### Scaling Strategy

#### Vertical Scaling (increase instance size)
- Increase CPU: 4 → 8 cores
- Increase Memory: 2GB → 4GB
- Expected improvement: 1.5-2x capacity

#### Horizontal Scaling (add instances)
- Add proxy instances behind load balancer
- Expected improvement: Linear with instance count
- Recommended: 2-3 instances for HA

### Auto-Scaling Rules

| Condition | Action | Cooldown |
|-----------|--------|----------|
| CPU > 80% for 2 min | Add 1 instance | 5 min |
| Connections > 800 for 1 min | Add 1 instance | 3 min |
| p95 latency > 400ms for 3 min | Add 1 instance | 5 min |
| CPU < 30% for 10 min | Remove 1 instance | 10 min |

## Optimization Guidelines

### When Performance Degrades

1. **Check network latency**
   ```bash
   ping -c 100 backend-service
   ```

2. **Verify no resource contention**
   ```bash
   top -p $(pgrep slapenir-proxy)
   ```

3. **Review sanitization patterns**
   - Ensure patterns are compiled efficiently
   - Check for pathological inputs

4. **Analyze slow requests**
   - Enable debug logging
   - Trace request lifecycle

### Common Performance Issues

| Issue | Symptoms | Solution |
|-------|----------|----------|
| Memory leak | Increasing memory over time | Check for unbounded collections, run soak test |
| CPU spike | Intermittent high CPU | Profile with `perf`, check for inefficient patterns |
| Slow sanitization | High latency on large payloads | Optimize Aho-Corasick automaton |
| Connection leak | FD exhaustion | Verify connection cleanup in error paths |
| Lock contention | High latency under load | Reduce lock scope, use lock-free structures |

## Performance Regression Prevention

### CI/CD Checks

```yaml
performance-tests:
  script:
    - cargo bench -- --save-baseline main
    - cargo bench -- --baseline main
  allow_failure: false
```

### Pre-commit Hooks

```bash
#!/bin/bash
# Run quick performance sanity check
cargo bench --bench performance -- --sample-size 10
```

## Reporting

### Performance Report Template

```markdown
# Performance Report - [Date]

## Summary
- Test duration: X minutes
- Max concurrent users: X
- Overall result: PASS/FAIL

## Key Metrics
| Metric | Baseline | Actual | Delta | Status |
|--------|----------|--------|-------|--------|
| p95 latency | 200ms | Xms | ±X% | ✅/❌ |
| p99 latency | 500ms | Xms | ±X% | ✅/❌ |
| Throughput | 1000 req/s | X req/s | ±X% | ✅/❌ |
| Error rate | 0.1% | X% | ±X% | ✅/❌ |

## Issues Found
- [List any performance issues]

## Recommendations
- [List optimization recommendations]
```

## References

- [k6 Documentation](https://k6.io/docs/)
- [Criterion User Guide](https://bheisler.github.io/criterion.rs/book/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Rust Performance Book](https://nnethercote.github.io/perf-book/)

---

**Last Updated**: 2026-03-27  
**Maintainer**: Andrew Gibson (andrew.gibson-cic@ibm.com)
