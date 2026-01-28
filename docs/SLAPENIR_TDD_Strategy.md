# **SLAPENIR: Test-Driven Development Strategy**

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

**Version:** 1.0  
**Author:** andrewgibson-cic <andrew.gibson-cic@ibm.com>  
**Last Updated:** January 28, 2026

---

## **Table of Contents**

1. [Executive Summary](#1-executive-summary)
2. [Testing Principles](#2-testing-principles-for-security-critical-systems)
3. [Test Architecture](#3-test-architecture-the-testing-pyramid)
4. [Rust Proxy Tests](#4-rust-proxy-test-specification)
5. [Agent Environment Tests](#5-agent-environment-test-specification)
6. [Integration & E2E Tests](#6-integration-and-end-to-end-tests)
7. [Chaos Engineering](#7-chaos-engineering-tests)
8. [Testing Tools & Setup](#8-testing-tools-and-setup)
9. [CI/CD Integration](#9-cicd-integration)
10. [Test Data Management](#10-test-data-management)
11. [Compliance Testing](#11-compliance-testing-checklist)
12. [Appendices](#12-appendices)

---

## **1. Executive Summary**

This document defines the comprehensive Test-Driven Development (TDD) strategy for SLAPENIR, a security-critical system that proxies high-privilege autonomous agents. Given the zero-knowledge architecture and the potential impact of security failures, this strategy adopts a **conservative, high-coverage approach** that prioritizes correctness over development velocity.

### **1.1 Core Testing Philosophy**

SLAPENIR testing is built on three pillars:

1. **Security-First:** Every test must validate a security property (isolation, sanitization, authentication).
2. **Property-Based:** Use generative testing to explore edge cases humans might miss.
3. **Chaos-Validated:** The system must prove resilience under adversarial conditions.

### **1.2 Coverage Goals**

| Component | Target Coverage | Critical Paths |
|-----------|----------------|----------------|
| **Rust Proxy Core** | 95% line coverage | 100% (sanitization, mTLS) |
| **Stream Replacement** | 100% branch coverage | 100% |
| **Agent Supervisor** | 85% line coverage | 100% (restart logic) |
| **Integration Tests** | N/A | All REQ-* validated |

### **1.3 Quality Gates**

No code may be merged to `main` without:
- ✅ All unit tests passing
- ✅ All integration tests passing
- ✅ Coverage thresholds met
- ✅ Cargo audit clean (no known vulnerabilities)
- ✅ Property tests passing (1000+ iterations)
- ✅ At least one chaos scenario validated

---

## **2. Testing Principles for Security-Critical Systems**

### **2.1 The "Zero Trust" Testing Model**

In SLAPENIR, we assume:
- The Agent code is **malicious by default** (simulate worst-case behavior)
- External APIs are **adversarial** (return payloads designed to leak secrets)
- The network is **unreliable** (simulate partitions, delays, corruption)

### **2.2 The Conservative Coverage Approach**

**Rationale:** A single missed test case in the sanitization engine could leak AWS credentials to an Agent, resulting in complete compromise. The cost of exhaustive testing is negligible compared to the cost of a security incident.

**Implementation:**
- Write tests **before** implementing features (strict TDD)
- Maintain a **regression test suite** for every reported bug
- Use **property-based testing** to generate adversarial inputs
- Run **mutation testing** quarterly to validate test effectiveness

### **2.3 Compliance Framework**

While SLAPENIR has no formal compliance requirements, we adopt industry standards as guidance:

- **OWASP ASVS Level 2:** Application Security Verification Standard
- **CIS Docker Benchmarks:** Container security validation
- **NIST CSF:** Risk management approach (Identify → Protect → Detect → Respond → Recover)

---

## **3. Test Architecture: The Testing Pyramid**

```
                    ┌─────────────────┐
                    │  Chaos Tests    │  ← 5% (Long-running, expensive)
                    │  (Pumba/Toxics) │
                    └─────────────────┘
                  ┌───────────────────────┐
                  │  End-to-End Tests     │  ← 15% (Full system)
                  │  (Docker Compose)     │
                  └───────────────────────┘
              ┌─────────────────────────────┐
              │  Integration Tests          │  ← 30% (Component pairs)
              │  (Testcontainers)           │
              └─────────────────────────────┘
          ┌─────────────────────────────────────┐
          │  Unit Tests                         │  ← 50% (Fast, isolated)
          │  (cargo test, pytest)               │
          └─────────────────────────────────────┘
```

### **3.1 Unit Tests (50% of test suite)**

**Purpose:** Validate individual functions and modules in isolation.

**Characteristics:**
- Fast execution (< 1ms per test)
- No external dependencies (mock network, filesystem)
- Focus on pure functions and business logic

**Example Areas:**
- Token replacement logic (dummy → real)
- Buffer boundary handling
- Certificate validation functions
- Rate limiter algorithms

### **3.2 Integration Tests (30% of test suite)**

**Purpose:** Validate interactions between components.

**Characteristics:**
- Medium execution time (100ms - 2s per test)
- Uses real dependencies (Docker containers)
- Tests component contracts

**Example Areas:**
- Agent → Proxy → Mock API flow
- Step-CA certificate issuance
- s6-overlay restart behavior

### **3.3 End-to-End Tests (15% of test suite)**

**Purpose:** Validate complete user workflows.

**Characteristics:**
- Slow execution (5s - 30s per test)
- Full Docker Compose stack
- Validates all REQ-* specifications

**Example Areas:**
- Complete secret injection/sanitization flow
- Network isolation enforcement
- Disaster recovery scenarios

### **3.4 Chaos Tests (5% of test suite)**

**Purpose:** Prove resilience under adversarial conditions.

**Characteristics:**
- Very slow execution (1min+)
- Uses Pumba or Toxiproxy
- Non-deterministic (run multiple times)

**Example Areas:**
- Network partition during git clone
- Random process kills
- Disk exhaustion

---

## **4. Rust Proxy Test Specification**

The Proxy is the security enforcement point. Its tests must be exhaustive.

### **4.1 Critical Test Scenarios for Stream Replacement**

#### **Scenario 1: Simple Single-Token Replacement**
```rust
#[tokio::test]
async fn test_simple_replacement() {
    let input = b"Authorization: Bearer DUMMY_GITHUB_TOKEN";
    let patterns = vec![("DUMMY_GITHUB_TOKEN", "ghp_real_secret")];
    
    let result = process_stream(input, patterns).await;
    
    assert_eq!(result, "Authorization: Bearer ghp_real_secret");
}
```

#### **Scenario 2: Split Secret Across Chunk Boundaries (CRITICAL)**
```rust
#[tokio::test]
async fn test_split_secret_detection() {
    // Secret "DUMMY_GITHUB_TOKEN" split between chunks
    let chunk1 = b"Authorization: Bearer DUMMY_GIT";
    let chunk2 = b"HUB_TOKEN\nContent-Type: json";
    
    let patterns = vec![("DUMMY_GITHUB_TOKEN", "ghp_real")];
    let result = process_chunks(vec![chunk1, chunk2], patterns).await;
    
    assert!(result.contains("ghp_real"));
    assert!(!result.contains("DUMMY_GITHUB_TOKEN"));
}
```

#### **Scenario 3: Multiple Tokens in Same Payload**
Tests that all tokens are replaced correctly when multiple appear together.

#### **Scenario 4: Overlapping Pattern Handling**
Tests longest-match behavior when one pattern is substring of another.

#### **Scenario 5: No False Positives**
Ensures partial matches don't trigger replacement.

#### **Scenario 6: Response Sanitization**
Validates that real tokens in API responses are replaced with `[REDACTED]`.

#### **Scenario 7: Large Payload Streaming**
Tests multi-GB file handling without memory exhaustion.

#### **Scenario 8: Binary Data Handling**
Ensures binary protocols don't cause crashes or false matches.

#### **Scenario 9: Unicode and UTF-8 Edge Cases**
Tests multi-byte character handling at chunk boundaries.

#### **Scenario 10: Concurrent Request Handling**
Validates thread safety and no secret leakage between requests.

### **4.2 Property-Based Tests**

**File:** `proxy/tests/property_tests.rs`

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_never_leaks_real_secrets(
        secret in "[a-zA-Z0-9]{32,64}",
        prefix in ".*",
        suffix in ".*"
    ) {
        let input = format!("{}DUMMY_TOKEN{}", prefix, suffix);
        let patterns = vec![("DUMMY_TOKEN", &secret)];
        let sanitized = sanitize_response(input.as_bytes(), patterns);
        
        prop_assert!(!sanitized.contains(&secret));
        prop_assert!(sanitized.contains("[REDACTED]"));
    }

    #[test]
    fn prop_split_secrets_always_detected(
        secret in "[A-Z_]{10,20}",
        split_point in 1usize..19
    ) {
        let part1 = &secret[..split_point];
        let part2 = &secret[split_point..];
        let patterns = vec![(&secret, "REAL_SECRET")];
        
        let chunk1 = format!("prefix {}", part1);
        let chunk2 = format!("{} suffix", part2);
        let result = process_chunks(vec![&chunk1, &chunk2], patterns);
        
        prop_assert!(result.contains("REAL_SECRET"));
        prop_assert!(!result.contains(&secret));
    }

    #[test]
    fn prop_idempotent_sanitization(input in ".*") {
        let patterns = vec![("DUMMY", "REAL")];
        let first = sanitize_response(input.as_bytes(), patterns.clone());
        let second = sanitize_response(&first, patterns);
        prop_assert_eq!(first, second);
    }
}
```

### **4.3 Memory Safety Tests**

**File:** `proxy/tests/memory_safety.rs`

```rust
#[test]
fn test_zeroize_on_drop() {
    let mut buffer = SecretBuffer::new(b"SENSITIVE".to_vec());
    let ptr = buffer.as_ptr();
    
    assert_eq!(buffer.as_slice(), b"SENSITIVE");
    drop(buffer);
    
    // Verify zeroed
    unsafe {
        let slice = std::slice::from_raw_parts(ptr, 9);
        assert_eq!(slice, &[0u8; 9]);
    }
}
```

### **4.4 mTLS Certificate Validation Tests**

```rust
#[tokio::test]
async fn test_reject_invalid_certificate() {
    let proxy = start_test_proxy().await;
    let self_signed_client = create_self_signed_client();
    
    let result = self_signed_client
        .get(&format!("https://localhost:{}/health", proxy.port()))
        .send()
        .await;
    
    assert!(result.is_err());
}

#[tokio::test]
async fn test_accept_step_ca_certificate() {
    let (ca, proxy) = start_with_step_ca().await;
    let valid_client = create_valid_client(&ca).await;
    
    let result = valid_client
        .get(&format!("https://localhost:{}/health", proxy.port()))
        .send()
        .await;
    
    assert!(result.is_ok());
    assert_eq!(result.unwrap().status(), 200);
}
```

### **4.5 Rate Limiting Tests**

```rust
#[tokio::test]
async fn test_rate_limit_enforcement() {
    let proxy = start_test_proxy().await;
    
    let mut ok_count = 0;
    let mut limited_count = 0;
    
    for _ in 0..20 {
        match proxy.get("/test").await.status() {
            StatusCode::OK => ok_count += 1,
            StatusCode::TOO_MANY_REQUESTS => limited_count += 1,
            _ => panic!("Unexpected status"),
        }
    }
    
    assert_eq!(ok_count, 10);
    assert_eq!(limited_count, 10);
}
```

---

## **5. Agent Environment Test Specification**

### **5.1 Wolfi OS Compatibility Tests**

**File:** `agent/tests/test_wolfi_compat.py`

```python
def test_glibc_python_wheels():
    """Verify PyTorch installs without compilation"""
    result = subprocess.run(
        ["pip", "install", "torch==2.0.0", "--dry-run"],
        capture_output=True
    )
    assert "manylinux" in result.stdout.decode()
    assert "Building wheel" not in result.stdout.decode()

def test_gcc_available():
    """Verify build tools work"""
    result = subprocess.run(["gcc", "--version"], capture_output=True)
    assert result.returncode == 0
```

### **5.2 s6-overlay Supervision Tests**

**File:** `agent/tests/test_s6_supervision.sh`

```bash
#!/bin/bash

test_process_restart() {
    # Start agent
    docker-compose up -d agent
    
    # Get Python PID
    PID=$(docker exec agent pgrep -f "python.*agent.py")
    
    # Kill process
    docker exec agent kill -9 $PID
    
    # Wait 2 seconds
    sleep 2
    
    # Verify new process exists
    NEW_PID=$(docker exec agent pgrep -f "python.*agent.py")
    
    [ "$PID" != "$NEW_PID" ] && echo "PASS: Process restarted"
    
    # Verify container still running
    STATUS=$(docker inspect -f '{{.State.Running}}' agent)
    [ "$STATUS" = "true" ] && echo "PASS: Container still running"
}
```

### **5.3 Certificate Bootstrap Tests**

```python
def test_certificate_bootstrap():
    """Verify agent can obtain cert from Step-CA"""
    agent = start_agent_container()
    
    # Wait for bootstrap
    time.sleep(5)
    
    # Check cert exists
    result = agent.exec_run("ls /home/agent/certs/cert.pem")
    assert result.exit_code == 0
    
    # Verify cert is valid
    result = agent.exec_run("step certificate verify /home/agent/certs/cert.pem")
    assert "certificate is valid" in result.output.decode()
```

---

## **6. Integration and End-to-End Tests**

### **6.1 Full Secret Injection Flow**

**File:** `tests/e2e/test_secret_injection.rs`

```rust
#[tokio::test]
async fn test_end_to_end_secret_injection() {
    // Start full stack
    let stack = docker_compose_up("tests/docker-compose.test.yml").await;
    
    // Agent makes request with DUMMY token
    let agent = stack.get_container("agent");
    agent.exec("curl -H 'Authorization: Bearer DUMMY_GITHUB_TOKEN' https://api.github.com/user");
    
    // Verify Proxy logs show replacement
    let proxy_logs = stack.get_logs("proxy");
    assert!(proxy_logs.contains("Replaced DUMMY_GITHUB_TOKEN"));
    
    // Verify API received REAL token (mock server)
    let mock_api_logs = stack.get_logs("mock-api");
    assert!(mock_api_logs.contains("ghp_real_secret"));
    
    // Verify Agent never sees REAL token
    let agent_logs = stack.get_logs("agent");
    assert!(!agent_logs.contains("ghp_real_secret"));
}
```

### **6.2 Network Isolation Validation**

```rust
#[tokio::test]
async fn test_network_isolation() {
    let stack = docker_compose_up("tests/docker-compose.test.yml").await;
    let agent = stack.get_container("agent");
    
    // Direct internet access should fail
    let result = agent.exec("curl https://google.com");
    assert!(result.is_err() || result.unwrap().contains("Could not resolve host"));
    
    // Access through proxy should work
    let result = agent.exec("curl -x https://proxy:443 https://google.com");
    assert!(result.is_ok());
}
```

### **6.3 Requirement Validation Matrix**

Test each REQ-* from SLAPENIR_Specifications.md:

| Requirement | Test File | Status |
|-------------|-----------|--------|
| REQ-1.1 No Default Route | `test_network_isolation.rs` | ✅ |
| REQ-2.1 Intercept All Traffic | `test_proxy_interception.rs` | ✅ |
| REQ-2.3 Upstream Replacement | `test_secret_injection.rs` | ✅ |
| REQ-2.4 Downstream Sanitization | `test_response_sanitization.rs` | ✅ |
| REQ-3.1 mTLS Required | `test_mtls_validation.rs` | ✅ |
| REQ-4.2 Process Restart < 1s | `test_s6_supervision.sh` | ✅ |

---

## **7. Chaos Engineering Tests**

### **7.1 Test Infrastructure Setup**

**File:** `tests/chaos/docker-compose.chaos.yml`

```yaml
version: '3.8'
services:
  pumba:
    image: gaiaadm/pumba:latest
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --random --interval 30s kill --signal SIGKILL re2:agent
```

### **7.2 Network Partition Test**

**File:** `tests/chaos/test_network_partition.sh`

```bash
#!/bin/bash

test_network_partition_recovery() {
    echo "Starting stack..."
    docker-compose up -d
    
    echo "Inducing network partition (100% packet loss for 30s)..."
    pumba netem --duration 30s loss --percent 100 proxy
    
    # During partition, agent should queue requests
    sleep 15
    
    # After partition heals, requests should succeed
    sleep 20
    
    AGENT_LOGS=$(docker logs agent 2>&1)
    echo "$AGENT_LOGS" | grep -q "Request succeeded after retry"
    
    if [ $? -eq 0 ]; then
        echo "PASS: Agent recovered from network partition"
        return 0
    else
        echo "FAIL: Agent did not recover"
        return 1
    fi
}
```

### **7.3 Process Suicide Test**

```bash
test_agent_process_suicide() {
    docker-compose up -d
    
    # Get initial PID
    INITIAL_PID=$(docker exec agent pgrep -f "python.*agent.py")
    echo "Initial PID: $INITIAL_PID"
    
    # Agent kills itself
    docker exec agent kill -9 $INITIAL_PID
    
    # Wait for s6 to restart
    sleep 2
    
    # Verify new process
    NEW_PID=$(docker exec agent pgrep -f "python.*agent.py")
    
    if [ "$INITIAL_PID" != "$NEW_PID" ] && [ ! -z "$NEW_PID" ]; then
        echo "PASS: Process restarted (Old: $INITIAL_PID, New: $NEW_PID)"
        return 0
    else
        echo "FAIL: Process did not restart"
        return 1
    fi
}
```

### **7.4 OOM Simulation Test**

```python
def test_oom_handling():
    """Simulate memory exhaustion during compilation"""
    agent = start_agent_with_limits(memory="512m", memory_swap="1g")
    
    # Trigger memory-intensive compilation
    result = agent.exec_run("gcc -o /tmp/test large_file.c")
    
    # Should succeed using swap, not crash
    assert result.exit_code == 0
    
    # Container should still be running
    agent.reload()
    assert agent.status == "running"
```

### **7.5 Certificate Expiry Test**

```python
def test_certificate_expiry_renewal():
    """Verify cert renewal before expiry"""
    ca, agent = start_with_step_ca()
    
    # Issue short-lived cert (10 minutes)
    issue_short_lived_cert(agent, validity="10m")
    
    # Wait for 7 minutes (70% of lifespan)
    time.sleep(420)
    
    # Verify renewal occurred
    cert_info = get_cert_info(agent)
    assert cert_info['not_after'] > datetime.now() + timedelta(minutes=8)
```

---

## **8. Testing Tools and Setup**

### **8.1 Required Tools**

#### **8.1.1 Rust Testing Stack**

```toml
# Cargo.toml [dev-dependencies]
[dev-dependencies]
tokio-test = "0.4"
proptest = "1.4"
testcontainers = "0.15"
criterion = "0.5"           # Benchmarking
cargo-tarpaulin = "0.27"     # Coverage
mockall = "0.12"             # Mocking
```

**Installation:**
```bash
cargo install cargo-audit    # Security scanning
cargo install cargo-tarpaulin # Coverage
cargo install cargo-mutants   # Mutation testing
```

#### **8.1.2 Python Testing Stack**

```bash
pip install pytest pytest-cov hypothesis docker
```

#### **8.1.3 Infrastructure Tools**

```bash
# Chaos engineering
docker pull gaiaadm/pumba:latest

# Testcontainers
cargo add testcontainers --dev
```

### **8.2 Local Development Setup**

**File:** `.vscode/settings.json`

```json
{
  "rust-analyzer.checkOnSave.command": "clippy",
  "rust-analyzer.checkOnSave.extraArgs": ["--all-targets"],
  "editor.formatOnSave": true,
  "[rust]": {
    "editor.defaultFormatter": "rust-lang.rust-analyzer"
  },
  "coverage-gutters.coverageFileNames": [
    "cobertura.xml",
    "target/coverage/cobertura.xml"
  ]
}
```

### **8.3 Running Tests Locally**

```bash
# Run all Rust unit tests
cargo test --workspace

# Run with coverage
cargo tarpaulin --out Html --output-dir target/coverage

# Run property tests (extended)
cargo test --release -- --ignored

# Run integration tests
cargo test --test '*' --features integration-tests

# Run chaos tests (requires Docker)
./tests/chaos/run_all_chaos_tests.sh

# Generate coverage report
open target/coverage/index.html
```

---

## **9. CI/CD Integration**

### **9.1 GitHub Actions Workflow**

**File:** `.github/workflows/test.yml`

```yaml
name: SLAPENIR Test Suite

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

env:
  CARGO_TERM_COLOR: always

jobs:
  unit-tests:
    name: Unit Tests (Rust + Python)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust toolchain
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          components: clippy, rustfmt
      
      - name: Cache cargo registry
        uses: actions/cache@v3
        with:
          path: ~/.cargo/registry
          key: ${{ runner.os }}-cargo-registry-${{ hashFiles('**/Cargo.lock') }}
      
      - name: Run Rust unit tests
        run: cargo test --workspace --lib
      
      - name: Run Python unit tests
        run: |
          cd agent
          pip install -r requirements-dev.txt
          pytest tests/unit/
  
  property-tests:
    name: Property-Based Tests
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Run property tests
        run: cargo test --release --test property_tests -- --test-threads=1
        env:
          PROPTEST_CASES: 10000
  
  integration-tests:
    name: Integration Tests
    runs-on: ubuntu-latest
    services:
      docker:
        image: docker:dind
        options: --privileged
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rs/toolchain@v1
      
      - name: Start test infrastructure
        run: docker-compose -f tests/docker-compose.test.yml up -d
      
      - name: Run integration tests
        run: cargo test --test '*' --features integration-tests
      
      - name: Collect logs on failure
        if: failure()
        run: docker-compose -f tests/docker-compose.test.yml logs > test-logs.txt
      
      - name: Upload logs
        if: failure()
        uses: actions/upload-artifact@v3
        with:
          name: test-logs
          path: test-logs.txt
  
  coverage:
    name: Code Coverage
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Install tarpaulin
        run: cargo install cargo-tarpaulin
      
      - name: Generate coverage
        run: cargo tarpaulin --out Xml --workspace
      
      - name: Upload to codecov
        uses: codecov/codecov-action@v3
        with:
          files: cobertura.xml
          fail_ci_if_error: true
      
      - name: Check coverage thresholds
        run: |
          COVERAGE=$(grep -oP 'line-rate="\K[^"]+' cobertura.xml | head -1)
          COVERAGE_PCT=$(echo "$COVERAGE * 100" | bc)
          if (( $(echo "$COVERAGE_PCT < 90" | bc -l) )); then
            echo "Coverage $COVERAGE_PCT% below 90% threshold"
            exit 1
          fi
  
  security-audit:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions-rs/toolchain@v1
      
      - name: Run cargo audit
        uses: actions-rs/cargo@v1
        with:
          command: audit
          args: --deny warnings
      
      - name: Run cargo deny
        run: |
          cargo install cargo-deny
          cargo deny check licenses
  
  chaos-tests:
    name: Chaos Engineering (Nightly)
    runs-on: ubuntu-latest
    if: github.event_name == 'schedule'
    steps:
      - uses: actions/checkout@v4
      
      - name: Run chaos tests
        run: ./tests/chaos/run_all_chaos_tests.sh
        timeout-minutes: 30
```

### **9.2 Pre-commit Hooks**

**File:** `.pre-commit-config.yaml`

```yaml
repos:
  - repo: local
    hooks:
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --
        language: system
        types: [rust]
        pass_filenames: false
      
      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
      
      - id: cargo-test
        name: cargo test
        entry: cargo test --workspace --lib
        language: system
        types: [rust]
        pass_filenames: false
      
      - id: gitleaks
        name: gitleaks (secret scanning)
        entry: gitleaks protect --staged
        language: system
        pass_filenames: false
```

**Installation:**
```bash
pip install pre-commit
pre-commit install
```

---

## **10. Test Data Management**

### **10.1 Mock Certificate Generation**

**File:** `tests/fixtures/generate_test_certs.sh`

```bash
#!/bin/bash
# Generate test certificates for local development

step certificate create root.test \
  root_ca.crt root_ca.key \
  --profile root-ca \
  --no-password --insecure

step certificate create agent.test \
  agent.crt agent.key \
  --ca root_ca.crt --ca-key root_ca.key \
  --no-password --insecure
```

### **10.2 Dummy Token Strategies**

**File:** `tests/fixtures/tokens.json`

```json
{
  "github": {
    "dummy": "DUMMY_GITHUB_TOKEN_ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "real": "ghp_REAL_SECRET_DO_NOT_COMMIT"
  },
  "aws": {
    "dummy": "AKIADUMMY

AWS_ACCESS_KEY_ID",
    "real": "AKIAIOSFODNN7EXAMPLE"
  },
  "openai": {
    "dummy": "sk-dummy-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
    "real": "sk-REAL_OPENAI_KEY"
  }
}
```

### **10.3 Test Fixture Organization**

```
tests/
├── fixtures/
│   ├── certs/
│   │   ├── generate_test_certs.sh
│   │   ├── root_ca.crt
│   │   └── agent.crt
│   ├── tokens/
│   │   ├── tokens.json
│   │   └── generate_dummy_tokens.py
│   ├── payloads/
│   │   ├── malicious_api_responses.json
│   │   └── split_secret_cases.txt
│   └── docker/
│       ├── docker-compose.test.yml
│       └── docker-compose.chaos.yml
├── unit/
│   ├── proxy/
│   │   ├── test_stream_replacer.rs
│   │   ├── test_mtls.rs
│   │   └── test_rate_limiter.rs
│   └── agent/
│       ├── test_wolfi_compat.py
│       └── test_bootstrap.py
├── integration/
│   ├── test_proxy_agent_flow.rs
│   └── test_step_ca_integration.rs
├── e2e/
│   ├── test_full_stack.rs
│   └── test_network_isolation.rs
└── chaos/
    ├── test_network_partition.sh
    ├── test_process_suicide.sh
    └── run_all_chaos_tests.sh
```

### **10.4 Mock API Server**

**File:** `tests/fixtures/mock_api/server.py`

```python
from flask import Flask, request, jsonify

app = Flask(__name__)

@app.route('/user', methods=['GET'])
def get_user():
    """Mock GitHub API - echoes auth header"""
    auth = request.headers.get('Authorization', '')
    
    # Log what we received (for test verification)
    app.logger.info(f"Received auth: {auth}")
    
    # Echo back in response (tests sanitization)
    return jsonify({
        "login": "testuser",
        "auth_received": auth  # This should be sanitized by proxy
    })

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)
```

---

## **11. Compliance Testing Checklist**

### **11.1 OWASP ASVS Level 2 Requirements**

| ID | Requirement | Test Coverage | Status |
|----|-------------|---------------|--------|
| **V2.1.1** | Verify passwords 12+ chars | N/A (certificate-based) | ✅ |
| **V3.4.1** | JWT signature validation | N/A (mTLS) | ✅ |
| **V6.2.1** | Cryptography uses approved modes | Uses rustls (TLS 1.3) | ✅ |
| **V8.1.1** | Sensitive data not logged | `test_no_secrets_in_logs.rs` | ✅ |
| **V8.3.4** | Sensitive memory is cleared | `test_zeroize_on_drop.rs` | ✅ |
| **V9.2.1** | TLS for all connections | `test_mtls_required.rs` | ✅ |
| **V14.1.3** | Dependencies checked for vulns | GitHub Actions `cargo-audit` | ✅ |

### **11.2 CIS Docker Benchmarks**

| Benchmark | Requirement | Implementation | Test |
|-----------|-------------|----------------|------|
| **5.1** | Verify AppArmor Profile | Default Docker profile | `test_apparmor.sh` |
| **5.3** | Verify SELinux security options | N/A (macOS dev) | - |
| **5.7** | Do not map privileged ports | Proxy on 8443, not 443 | Config check |
| **5.10** | Memory limit set | `mem_limit: 4g` | `docker inspect` |
| **5.12** | Root filesystem read-only | Agent `/workspace` only RW | `test_readonly_fs.sh` |
| **5.25** | Container restart policy | `restart: on-failure` | Config check |

### **11.3 NIST Cybersecurity Framework Mapping**

**Identify:**
- Asset inventory (Docker images, secrets)
- Risk assessment (SLAPENIR_Risks.md)

**Protect:**
- Access control (mTLS)
- Data security (sanitization)
- Protective technology (rate limiting)

**Detect:**
- Anomaly detection (rate limit violations)
- Security monitoring (proxy logs)

**Respond:**
- Response planning (chaos tests)
- Mitigation (automatic restarts)

**Recover:**
- Recovery planning (s6-overlay restarts)
- Improvements (regression tests)

---

## **12. Appendices**

### **Appendix A: Test Command Reference**

```bash
# === Unit Tests ===
cargo test --lib                    # Rust unit tests only
pytest agent/tests/unit/            # Python unit tests

# === Integration Tests ===
cargo test --test '*'               # All Rust integration tests
pytest agent/tests/integration/     # Python integration tests

# === Property Tests ===
PROPTEST_CASES=10000 cargo test --release proptest

# === Coverage ===
cargo tarpaulin --out Html --output-dir target/coverage
pytest --cov=agent --cov-report=html

# === Security ===
cargo audit                         # Check for vulnerable dependencies
cargo clippy -- -D warnings         # Lint with warnings as errors

# === Chaos ===
./tests/chaos/test_network_partition.sh
./tests/chaos/test_process_suicide.sh

# === Performance ===
cargo bench                         # Run criterion benchmarks
```

### **Appendix B: Coverage Report Interpretation**

**Reading Tarpaulin Output:**

```
|| Tested/Total Lines:
|| proxy/src/sanitizer/stream_replacer.rs: 245/250 (98.00%)
|| proxy/src/mtls/validator.rs: 89/90 (98.89%)
|| 
|| Total Coverage: 95.23%
```

**What to investigate if coverage drops:**
1. Check for unreachable error handling code
2. Review if new features have tests
3. Verify property tests cover edge cases
4. Check if integration tests exercise all paths

### **Appendix C: Troubleshooting Test Failures**

**Problem: Integration tests fail with "connection refused"**
```bash
# Solution: Ensure Docker daemon is running
docker ps

# Check if test containers are up
docker-compose -f tests/docker-compose.test.yml ps
```

**Problem: Property tests timeout**
```bash
# Solution: Reduce PROPTEST_CASES for local dev
PROPTEST_CASES=100 cargo test proptest
```

**Problem: "Memory not zeroed" assertion failure**
```bash
# This is a critical security failure
# Solution: Verify zeroize is applied to all SecretBuffer types
# Check Drop implementation is correct
```

### **Appendix D: Test Template**

**Unit Test Template:**

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_descriptive_name() {
        // Arrange: Set up test data
        let input = create_test_input();
        
        // Act: Execute the function under test
        let result = function_under_test(input);
        
        // Assert: Verify expected behavior
        assert_eq!(result, expected_value);
    }
}
```

**Property Test Template:**

```rust
use proptest::prelude::*;

proptest! {
    #[test]
    fn prop_descriptive_invariant(
        input in strategy_for_input()
    ) {
        let result = function_under_test(input);
        prop_assert!(invariant_holds(result));
    }
}
```

### **Appendix E: Security Test Checklist**

Before merging any PR, verify:

- [ ] No secrets in code or tests
- [ ] All new endpoints have rate limiting tests
- [ ] Split-secret scenarios tested for new patterns
- [ ] Memory zeroization tested for new secret types
- [ ] mTLS validation tested for new routes
- [ ] Property tests cover new sanitization logic
- [ ] Integration test validates end-to-end flow
- [ ] Cargo audit passes with no warnings
- [ ] No new dependencies without security review

### **Appendix F: Mutation Testing Guide**

**Running Mutation Tests:**

```bash
# Install cargo-mutants
cargo install cargo-mutants

# Run mutation testing (slow!)
cargo mutants --timeout 60

# Review results
cat mutants.out/caught.txt    # Mutations caught by tests
cat mutants.out/missed.txt    # Mutations missed (need more tests!)
```

**Interpreting Results:**

- **Caught:** Tests successfully detected the mutation → Good coverage
- **Missed:** Mutation not detected → Add tests for this code
- **Timeout:** Mutation caused infinite loop → May indicate real bug

**Target:** 95%+ mutations caught for critical paths (sanitization, mTLS)

---

## **Summary**

This TDD strategy provides a comprehensive framework for ensuring SLAPENIR's security and reliability through:

1. **Conservative coverage targets** (90-100% for critical paths)
2. **Property-based testing** to explore adversarial inputs
3. **Chaos engineering** to prove resilience
4. **Automated CI/CD gates** to prevent regressions
5. **Compliance mapping** to industry standards

**Key Principle:** In security-critical systems, the cost of comprehensive testing is always less than the cost of a security incident.

**Next Steps:**
1. Set up local testing environment (Section 8)
2. Configure GitHub Actions (Section 9)
3. Write first test following TDD (Section 4-6)
4. Run chaos tests before any production deployment (Section 7)

---

**Document Maintenance:**
- Review quarterly for new attack vectors
- Update after each security incident
- Expand property tests as new edge cases discovered
- Revise coverage targets based on mutation testing results

**References:**
- [SLAPENIR Architecture](./SLAPENIR_Architecture.md)
- [SLAPENIR Risks](./SLAPENIR_Risks.md)
- [SLAPENIR Specifications](./SLAPENIR_Specifications.md)
- [SLAPENIR Roadmap](./SLAPENIR_Roadmap.md)
- [OWASP ASVS](https://owasp.org/www-project-application-security-verification-standard/)
- [CIS Docker Benchmarks](https://www.cisecurity.org/benchmark/docker)
