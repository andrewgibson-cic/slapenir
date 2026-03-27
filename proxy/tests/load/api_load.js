import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend, Counter } from 'k6/metrics';

const errorRate = new Rate('errors');
const requestDuration = new Trend('request_duration');
const requestsPerSecond = new Counter('requests_per_second');

export const options = {
  scenarios: {
    constant_load: {
      executor: 'constant-arrival-rate',
      rate: 100,
      timeUnit: '1s',
      duration: '2m',
      preAllocatedVUs: 50,
      maxVUs: 200,
      gracefulStop: '30s',
    },
    ramping_load: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 500,
      stages: [
        { target: 50, duration: '1m' },
        { target: 100, duration: '2m' },
        { target: 200, duration: '3m' },
        { target: 100, duration: '2m' },
        { target: 10, duration: '1m' },
      ],
      gracefulStop: '30s',
    },
    spike_test: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 100,
      maxVUs: 1000,
      stages: [
        { target: 10, duration: '1m' },
        { target: 500, duration: '30s' },
        { target: 10, duration: '1m' },
      ],
      gracefulStop: '30s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<500', 'p(99)<1000'],
    http_req_failed: ['rate<0.01'],
    errors: ['rate<0.05'],
    request_duration: ['p(95)<500'],
  },
};

const BASE_URL = __ENV.PROXY_URL || 'http://localhost:3000';

export default function () {
  const responses = http.batch([
    ['GET', `${BASE_URL}/health`, null, { tags: { endpoint: 'health' } }],
    ['GET', `${BASE_URL}/metrics`, null, { tags: { endpoint: 'metrics' } }],
  ]);

  responses.forEach((res, index) => {
    const endpoint = index === 0 ? 'health' : 'metrics';
    
    const success = check(res, {
      [`${endpoint} status is 200`]: (r) => r.status === 200,
      [`${endpoint} response time < 500ms`]: (r) => r.timings.duration < 500,
      [`${endpoint} has body`]: (r) => r.body && r.body.length > 0,
    });

    errorRate.add(!success);
    requestDuration.add(res.timings.duration);
    requestsPerSecond.add(1);

    if (!success) {
      console.error(`${endpoint} check failed: ${res.status} ${res.timings.duration}ms`);
    }
  });

  sleep(1);
}

export function handleSummary(data) {
  const metrics = {
    http_req_duration: data.metrics.http_req_duration.values,
    http_req_failed: data.metrics.http_req_failed.values,
    iterations: data.metrics.iterations.values,
    vus: data.metrics.vus.values,
  };

  const summary = {
    timestamp: new Date().toISOString(),
    test_type: 'api_load',
    thresholds: {
      p95_latency: { threshold: 500, actual: metrics.http_req_duration['p(95)'] },
      p99_latency: { threshold: 1000, actual: metrics.http_req_duration['p(99)'] },
      error_rate: { threshold: 0.01, actual: metrics.http_req_failed.rate },
    },
    passed: 
      metrics.http_req_duration['p(95)'] < 500 &&
      metrics.http_req_duration['p(99)'] < 1000 &&
      metrics.http_req_failed.rate < 0.01,
  };

  return {
    'stdout': JSON.stringify(summary, null, 2),
    'load-test-results.json': JSON.stringify({ ...data, summary }, null, 2),
  };
}
