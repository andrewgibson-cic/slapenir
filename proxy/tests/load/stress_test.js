import http from 'k6/http';
import { check, sleep, fail } from 'k6';

export const options = {
  stages: [
    { duration: '2m', target: 100 },
    { duration: '2m', target: 250 },
    { duration: '2m', target: 500 },
    { duration: '2m', target: 750 },
    { duration: '2m', target: 1000 },
    { duration: '2m', target: 1000 },
    { duration: '2m', target: 0 },
  ],
  thresholds: {
    http_req_failed: ['rate<0.1'],
  },
};

const BASE_URL = __ENV.PROXY_URL || 'http://localhost:3000';

let breakingPoint = null;
let lastVUs = 0;

export default function () {
  const currentVUs = __VU;

  if (breakingPoint && currentVUs > breakingPoint) {
    fail(`Breaking point reached at ${breakingPoint} VUs`);
  }

  const res = http.get(`${BASE_URL}/health`, {
    timeout: '5s',
    tags: { test_type: 'stress' },
  });

  const success = check(res, {
    'status is 200': (r) => r.status === 200,
    'response time < 1000ms': (r) => r.timings.duration < 1000,
    'response time < 2000ms': (r) => r.timings.duration < 2000,
  });

  if (!success && !breakingPoint) {
    breakingPoint = currentVUs;
    console.log(`Breaking point detected at ${breakingPoint} VUs`);
  }

  if (lastVUs !== currentVUs) {
    console.log(`Current VUs: ${currentVUs}, Response time: ${res.timings.duration}ms`);
    lastVUs = currentVUs;
  }

  sleep(0.1);
}

export function handleSummary(data) {
  const metrics = data.metrics;
  
  const summary = {
    timestamp: new Date().toISOString(),
    test_type: 'stress_test',
    results: {
      max_vus: Math.max(...Object.values(metrics.vus.values)),
      breaking_point: breakingPoint,
      total_requests: metrics.iterations.values.count,
      p95_latency_ms: Math.round(metrics.http_req_duration['p(95)'] * 100) / 100,
      p99_latency_ms: Math.round(metrics.http_req_duration['p(99)'] * 100) / 100,
      max_latency_ms: Math.round(metrics.http_req_duration.max * 100) / 100,
      error_rate: Math.round(metrics.http_req_failed.rate * 10000) / 10000,
      requests_per_second_at_peak: Math.round(metrics.iterations.values.rate * 100) / 100,
    },
    conclusions: {
      max_concurrent_users: breakingPoint || 'Did not reach breaking point',
      recommended_max_users: breakingPoint ? Math.floor(breakingPoint * 0.75) : 750,
      system_stable: metrics.http_req_failed.rate < 0.1,
    },
  };

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'stress-test-results.json': JSON.stringify({ ...data, summary }, null, 2),
  };
}
