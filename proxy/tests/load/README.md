# Load Testing Suite

Comprehensive load testing suite for SLAPENIR proxy using k6.

## Prerequisites

Install k6:
```bash
# macOS
brew install k6

# Linux
sudo apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com 80557F4C69463590
sudo add-apt-repository 'deb [arch=amd64] https://dl.bintray.com/loadimpact/deb stable main'
sudo apt-get update && sudo apt-get install k6

# Windows
choco install k6
```

## Test Scenarios

### 1. API Load Test (`api_load.js`)
Tests basic API endpoints under load.

**Configuration:**
- 100 RPS constant load for 2 minutes
- Ramping from 10 → 100 → 500 → 10 users
- p95 latency threshold: <500ms
- p99 latency threshold: <1000ms
- Error rate threshold: <1%

**Run:**
```bash
PROXY_URL=http://localhost:3000 k6 run api_load.js
```

### 2. Proxy Sanitization Test (`proxy_sanitization.js`)
Tests the core sanitization functionality with realistic payloads.

**Configuration:**
- Ramps from 50 → 100 → 200 → 0 users
- 8-minute total duration
- Tests secret injection and sanitization
- p95 latency threshold: <200ms
- p99 latency threshold: <500ms
- Error rate threshold: <0.1%

**Run:**
```bash
PROXY_URL=http://localhost:3000 k6 run proxy_sanitization.js
```

### 3. Stress Test (`stress_test.js`)
Finds the system's breaking point.

**Configuration:**
- Progressive load: 100 → 250 → 500 → 750 → 1000 VUs
- 14-minute total duration
- Identifies max concurrent users
- Determines recommended max load (75% of breaking point)

**Run:**
```bash
PROXY_URL=http://localhost:3000 k6 run stress_test.js
```

### 4. Soak Test (`soak_test.js`)
Tests long-running stability and memory leaks.

**Configuration:**
- 100 constant VUs for 30 minutes
- Detects memory leaks (increasing latency over time)
- p95 latency threshold: <300ms
- Error rate threshold: <0.1%

**Run:**
```bash
PROXY_URL=http://localhost:3000 k6 run soak_test.js
```

## Running All Tests

```bash
# Run all tests sequentially
./run_all_load_tests.sh

# Or individually
k6 run api_load.js
k6 run proxy_sanitization.js
k6 run stress_test.js
k6 run soak_test.js
```

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:

```yaml
- name: Run load tests
  run: |
    k6 run proxy/tests/load/api_load.js --out json=load-test-results.json
  continue-on-error: true
```

## Performance Baselines

Based on expected performance targets:

| Metric | Target | Description |
|--------|--------|-------------|
| p95 Latency | <200ms | 95% of requests under 200ms |
| p99 Latency | <500ms | 99% of requests under 500ms |
| Throughput | >1000 req/s | Requests per second |
| Error Rate | <0.1% | Less than 1 in 1000 requests fail |
| Max Concurrent Users | 500+ | Concurrent connections supported |
| Memory Growth | <10%/hour | No significant memory leaks |

## Output Files

Each test generates JSON results:
- `api-load-results.json` - API load test metrics
- `proxy-sanitization-results.json` - Sanitization performance
- `stress-test-results.json` - Breaking point analysis
- `soak-test-results.json` - Long-running stability metrics

## Interpreting Results

### Good Results
- p95 latency < threshold
- Error rate < threshold
- No memory leaks detected
- Throughput meets or exceeds targets

### Warning Signs
- Increasing latency over time (memory leak)
- Error rate approaching threshold
- Throughput degradation
- High variance in response times

### Action Required
- Error rate exceeds threshold
- Latency exceeds thresholds
- Breaking point below 200 concurrent users
- Memory leak detected in soak test

## Troubleshooting

### "Too many open files"
Increase system limits:
```bash
ulimit -n 65536
```

### Connection refused
Ensure proxy is running:
```bash
curl http://localhost:3000/health
```

### High latency
Check:
- Network conditions
- Proxy configuration (buffer sizes, timeouts)
- Backend service performance
- System resources (CPU, memory)

## Test Data

Tests use randomized data to simulate realistic traffic:
- Random payload sizes (100-5000 bytes)
- Random secret patterns
- Random request metadata
- Realistic header combinations

## Customization

Adjust thresholds in test files:

```javascript
thresholds: {
  http_req_duration: ['p(95)<200'],  // Adjust latency threshold
  http_req_failed: ['rate<0.001'],   // Adjust error rate threshold
}
```

Adjust load patterns:

```javascript
stages: [
  { duration: '1m', target: 100 },  // Adjust duration and target VUs
]
```
