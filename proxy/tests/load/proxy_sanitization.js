import http from 'k6/http';
import { check, sleep } from 'k6';
import { randomString, randomIntBetween } from 'k6/data';

export const options = {
  stages: [
    { duration: '1m', target: 50 },
    { duration: '3m', target: 100 },
    { duration: '1m', target: 200 },
    { duration: '2m', target: 200 },
    { duration: '1m', target: 0 },
  ],
  thresholds: {
    http_req_duration: ['p(95)<200', 'p(99)<500'],
    http_req_failed: ['rate<0.001'],
    iterations: ['count>1000'],
  },
};

const BASE_URL = __ENV.PROXY_URL || 'http://localhost:3000';
const TARGET_URL = __ENV.TARGET_URL || 'http://httpbin.org';

const DUMMY_SECRETS = [
  'DUMMY_API_KEY',
  'DUMMY_TOKEN',
  'DUMMY_SECRET',
  'DUMMY_PASSWORD',
  'DUMMY_CREDENTIAL',
];

export default function () {
  const secret = DUMMY_SECRETS[randomIntBetween(0, DUMMY_SECRETS.length - 1)];
  const payloadSize = randomIntBetween(100, 5000);
  
  const payload = JSON.stringify({
    data: randomString(payloadSize),
    metadata: {
      credential_token: secret,
      timestamp: new Date().toISOString(),
      request_id: randomString(16),
    },
    config: {
      api_key: secret,
      endpoint: `${TARGET_URL}/test`,
      retries: randomIntBetween(1, 5),
    },
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'X-Authorization': secret,
      'X-Api-Key': secret,
    },
    tags: { operation: 'proxy_request' },
    timeout: '10s',
  };

  const res = http.post(`${BASE_URL}/proxy`, payload, params);

  check(res, {
    'status is 200 or 201': (r) => [200, 201].includes(r.status),
    'response time < 200ms': (r) => r.timings.duration < 200,
    'response time < 500ms (p99 threshold)': (r) => r.timings.duration < 500,
    'has response body': (r) => r.body && r.body.length > 0,
    'no secret leakage in response': (r) => {
      if (!r.body) return true;
      return !DUMMY_SECRETS.some(s => r.body.includes(s));
    },
  });

  sleep(Math.random() * 0.5);
}

export function handleSummary(data) {
  const metrics = data.metrics;
  
  const summary = {
    timestamp: new Date().toISOString(),
    test_type: 'proxy_sanitization',
    configuration: {
      target_vus: 200,
      duration: '8m',
      thresholds: {
        p95_latency_ms: 200,
        p99_latency_ms: 500,
        error_rate: 0.001,
      },
    },
    results: {
      total_requests: metrics.iterations.values.count,
      p95_latency_ms: Math.round(metrics.http_req_duration['p(95)'] * 100) / 100,
      p99_latency_ms: Math.round(metrics.http_req_duration['p(99)'] * 100) / 100,
      error_rate: Math.round(metrics.http_req_failed.rate * 10000) / 10000,
      avg_latency_ms: Math.round(metrics.http_req_duration.avg * 100) / 100,
      requests_per_second: Math.round(metrics.iterations.values.rate * 100) / 100,
    },
    passed: 
      metrics.http_req_duration['p(95)'] < 200 &&
      metrics.http_req_duration['p(99)'] < 500 &&
      metrics.http_req_failed.rate < 0.001,
  };

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'proxy-sanitization-results.json': JSON.stringify({ ...data, summary }, null, 2),
  };
}
