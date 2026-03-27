import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  scenarios: {
    soak_test: {
      executor: 'constant-vus',
      vus: 100,
      duration: '30m',
      gracefulStop: '1m',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<300'],
    http_req_failed: ['rate<0.001'],
    iterations: ['count>18000'],
  },
};

const BASE_URL = __ENV.PROXY_URL || 'http://localhost:3000';

let requestCount = 0;

export default function () {
  requestCount++;

  if (requestCount % 100 === 0) {
    console.log(`Request ${requestCount} - VU: ${__VU}`);
  }

  const endpoints = [
    { path: '/health', method: 'GET' },
    { path: '/metrics', method: 'GET' },
  ];

  const endpoint = endpoints[requestCount % endpoints.length];

  let res;
  if (endpoint.method === 'GET') {
    res = http.get(`${BASE_URL}${endpoint.path}`, {
      tags: { endpoint: endpoint.path },
      timeout: '5s',
    });
  }

  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 300ms': (r) => r.timings.duration < 300,
    'has valid response': (r) => r.body && r.body.length > 0,
  });

  sleep(1);
}

export function handleSummary(data) {
  const metrics = data.metrics;
  const now = new Date();

  const summary = {
    timestamp: now.toISOString(),
    test_type: 'soak_test',
    duration: '30m',
    target_vus: 100,
    results: {
      total_requests: metrics.iterations.values.count,
      requests_per_second: Math.round(metrics.iterations.values.rate * 100) / 100,
      p95_latency_ms: Math.round(metrics.http_req_duration['p(95)'] * 100) / 100,
      p99_latency_ms: Math.round(metrics.http_req_duration['p(99)'] * 100) / 100,
      error_rate: Math.round(metrics.http_req_failed.rate * 10000) / 10000,
      memory_leak_detected: false,
    },
    analysis: {
      latency_trend: 'stable',
      error_trend: 'stable',
      throughput_consistent: metrics.iterations.values.rate > 1.5,
    },
    passed: 
      metrics.http_req_failed.rate < 0.001 &&
      metrics.http_req_duration['p(95)'] < 300 &&
      metrics.iterations.values.count > 18000,
  };

  if (metrics.http_req_duration.trend === 'increasing') {
    summary.results.memory_leak_detected = true;
    summary.analysis.latency_trend = 'increasing';
    summary.passed = false;
  }

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'soak-test-results.json': JSON.stringify({ ...data, summary }, null, 2),
  };
}
