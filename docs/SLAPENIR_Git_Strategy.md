# **SLAPENIR: Git Strategy & Version Control Workflow**

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

**Version:** 1.0  
**Author:** andrewgibson-cic <andrew.gibson-cic@ibm.com>  
**Last Updated:** January 28, 2026  
**Repository:** git@github.com:andrewgibson-cic/slapenir.git

---

## **Table of Contents**

1. [Executive Summary](#1-executive-summary)
2. [Repository Configuration](#2-repository-configuration)
3. [Branching Strategy](#3-branching-strategy)
4. [Commit Standards](#4-commit-standards)
5. [Code Review Process](#5-code-review-process)
6. [Release Management](#6-release-management)
7. [Security Measures](#7-security-measures)
8. [Workflow Automation](#8-workflow-automation)
9. [Development Workflow](#9-development-workflow)
10. [Tooling Setup](#10-tooling-setup)
11. [Best Practices](#11-best-practices)
12. [Appendices](#12-appendices)

---

## **1. Executive Summary**

This document defines the Git strategy for SLAPENIR, a security-critical solo project. The strategy emphasizes:

1. **Security-First:** Prevent secret leakage through automated scanning and pre-commit hooks
2. **Automation:** Use GitHub Actions to enforce quality gates without manual review overhead
3. **Traceability:** Maintain clear audit trail through conventional commits and signed commits
4. **Simplicity:** Streamlined workflow suitable for solo development without team coordination overhead

### **1.1 Core Principles**

- **Trunk-Based Development:** Short-lived feature branches merge directly to `main`
- **Continuous Testing:** All commits trigger automated test suites
- **Security Scanning:** Pre-commit and server-side secret detection
- **Semantic Versioning:** Clear version numbering with automated changelog generation
- **Audit Trail:** GPG-signed commits for authenticity verification

### **1.2 Repository Structure**

```
slapenir/
├── .github/
│   ├── workflows/          # GitHub Actions CI/CD
│   ├── CODEOWNERS          # Automated review assignments
│   └── PULL_REQUEST_TEMPLATE.md
├── docs/                   # Architecture & strategy docs
├── proxy/                  # Rust proxy service
│   ├── src/
│   ├── tests/
│   └── Cargo.toml
├── agent/                  # Agent environment
│   ├── Dockerfile
│   ├── tests/
│   └── requirements.txt
├── tests/                  # Integration & E2E tests
│   ├── fixtures/
│   ├── integration/
│   └── e2e/
├── docker-compose.yml
├── .gitignore
├── .pre-commit-config.yaml
└── README.md
```

---

## **2. Repository Configuration**

### **2.1 Initial Setup**

```bash
# Clone repository
git clone git@github.com:andrewgibson-cic/slapenir.git
cd slapenir

# Configure user identity
git config user.name "andrewgibson-cic"
git config user.email "andrew.gibson-cic@ibm.com"

# Enable GPG signing (recommended)
git config commit.gpgsign true
git config user.signingkey YOUR_GPG_KEY_ID

# Set default branch
git config init.defaultBranch main

# Configure line endings
git config core.autocrlf input  # Unix-style LF

# Set pull strategy
git config pull.rebase true
```

### **2.2 .gitignore Configuration**

**File:** `.gitignore`

```gitignore
# === Secrets & Credentials ===
*.pem
*.key
*.crt
!tests/fixtures/certs/*.crt  # Test certs are OK
*.env
.env.local
secrets.json
!tests/fixtures/tokens.json  # Dummy tokens only

# === Rust ===
target/
Cargo.lock  # Include for binary projects
**/*.rs.bk
*.pdb

# === Python ===
__pycache__/
*.py[cod]
*$py.class
.pytest_cache/
.coverage
htmlcov/
*.egg-info/
dist/
build/

# === Docker ===
.docker/volumes/
*.log

# === IDE ===
.vscode/settings.json  # Local settings
.idea/
*.swp
*.swo
*~

# === OS ===
.DS_Store
Thumbs.db

# === Coverage & Reports ===
target/coverage/
coverage/
*.profraw

# === Temporary ===
*.tmp
*.bak
temp/
```

### **2.3 Git Attributes**

**File:** `.gitattributes`

```gitattributes
# Auto-detect text files
* text=auto

# Enforce LF for source code
*.rs text eol=lf
*.py text eol=lf
*.sh text eol=lf
*.yml text eol=lf
*.toml text eol=lf
*.md text eol=lf

# Binary files
*.png binary
*.jpg binary
*.pdf binary
```

---

## **3. Branching Strategy**

### **3.1 Branch Types**

SLAPENIR uses a simplified trunk-based development model suitable for solo development:

```
main (protected)
  ↑
  ├── feature/proxy-sanitization
  ├── feature/agent-bootstrap
  ├── fix/memory-leak-proxy
  └── hotfix/critical-cve-2024-001
```

#### **3.1.1 Main Branch**

- **Purpose:** Production-ready code
- **Protection:** Cannot push directly; PRs only
- **Deployment:** Automatically tagged for releases
- **Quality:** All CI checks must pass

#### **3.1.2 Feature Branches**

- **Naming:** `feature/<short-description>`
- **Lifespan:** 1-3 days maximum
- **Examples:**
  - `feature/aho-corasick-streaming`
  - `feature/mtls-validation`
  - `feature/rate-limiter`

#### **3.1.3 Fix Branches**

- **Naming:** `fix/<issue-description>`
- **Lifespan:** < 1 day
- **Examples:**
  - `fix/split-secret-detection`
  - `fix/cert-renewal-logic`

#### **3.1.4 Hotfix Branches**

- **Naming:** `hotfix/<critical-issue>`
- **Purpose:** Emergency security patches
- **Lifespan:** Hours
- **Process:** Can bypass some CI checks for speed

### **3.2 Branch Naming Conventions**

```bash
# Format: <type>/<description-in-kebab-case>

# Feature branches
feature/proxy-request-sanitization
feature/agent-wolfi-base-image
feature/chaos-test-network-partition

# Fix branches
fix/memory-leak-stream-replacer
fix/rate-limit-token-bucket
fix/cert-validation-edge-case

# Hotfix branches (critical security)
hotfix/cve-2024-12345-rustls
hotfix/secret-leak-response-header

# Documentation branches
docs/update-architecture-diagram
docs/add-deployment-guide

# Chore branches (non-functional)
chore/update-dependencies
chore/refactor-test-structure
```

### **3.3 Branch Protection Rules**

**GitHub Settings for `main` branch:**

```yaml
# .github/branch-protection.yml (conceptual - set via GitHub UI)
main:
  required_status_checks:
    strict: true
    contexts:
      - "Unit Tests (Rust + Python)"
      - "Property-Based Tests"
      - "Integration Tests"
      - "Security Audit"
      - "Code Coverage (90%+)"
  
  required_pull_request_reviews:
    required_approving_review_count: 0  # Solo project
    dismiss_stale_reviews: true
    require_code_owner_reviews: false
  
  restrictions: null  # No push restrictions for owner
  
  enforce_admins: false  # Allow admin override for hotfixes
  
  required_linear_history: true  # No merge commits
  
  allow_force_pushes: false
  
  allow_deletions: false
```

---

## **4. Commit Standards**

### **4.1 Conventional Commits**

SLAPENIR uses [Conventional Commits](https://www.conventionalcommits.org/) for automated changelog generation.

#### **4.1.1 Commit Message Format**

```
<type>(<scope>): <subject>

[optional body]

[optional footer]
```

**Examples:**

```bash
feat(proxy): implement Aho-Corasick stream replacement

- Add StreamReplacer struct with buffer overlap handling
- Implement zeroize trait for SecretBuffer
- Add property tests for split-secret detection

Closes #23

---

fix(agent): correct certificate renewal timing

The renewal was triggering at 50% lifespan instead of 66%.
Updated the calculation in bootstrap.sh.

Fixes #45

---

security(proxy): patch CVE-2024-12345 in rustls dependency

Upgraded rustls from 0.21.0 to 0.21.10 to address TLS
handshake vulnerability.

BREAKING CHANGE: Minimum TLS version now 1.3

---

test(chaos): add network partition recovery test

Validates agent can recover from 30s network outage without
data loss or credential leakage.

---

docs(architecture): update mTLS sequence diagram

Clarified certificate bootstrap flow with Step-CA.

---

chore(deps): update all Rust dependencies

Ran cargo update and verified all tests pass.
```

#### **4.1.2 Commit Types**

| Type | Description | Changelog Section | Examples |
|------|-------------|-------------------|----------|
| **feat** | New feature | Features | Add rate limiting, implement sanitization |
| **fix** | Bug fix | Bug Fixes | Fix memory leak, correct validation logic |
| **security** | Security patch | Security | Patch CVE, update dependencies |
| **perf** | Performance improvement | Performance | Optimize stream processing |
| **refactor** | Code refactoring | (Internal) | Restructure module, extract function |
| **test** | Add/update tests | (Internal) | Add property tests, chaos scenarios |
| **docs** | Documentation | Documentation | Update README, add architecture doc |
| **chore** | Maintenance | (Internal) | Update deps, configure CI |
| **ci** | CI/CD changes | (Internal) | Update GitHub Actions workflow |

#### **4.1.3 Scope Guidelines**

| Scope | Component |
|-------|-----------|
| **proxy** | Rust proxy service |
| **agent** | Agent environment/Docker |
| **mtls** | mTLS/certificate logic |
| **sanitizer** | Token replacement engine |
| **tests** | Test infrastructure |
| **ci** | CI/CD pipelines |
| **docs** | Documentation |

### **4.2 Commit Message Templates**

**File:** `.gitmessage`

```
# <type>(<scope>): <subject>
# |<----  Using a Maximum Of 50 Characters  ---->|

# Explain why this change is being made
# |<----   Try To Limit Each Line to a Maximum Of 72 Characters   ---->|

# Provide links or keys to any relevant tickets, articles or other resources
# Example: Closes #23

# --- COMMIT END ---
# Type can be:
#   feat     (new feature)
#   fix      (bug fix)
#   security (security patch)
#   refactor (refactoring code)
#   test     (adding tests)
#   docs     (changes to documentation)
#   chore    (updating dependencies, etc)
# --------------------
# Remember to:
#   - Use the imperative mood in the subject line
#   - Do not end the subject line with a period
#   - Separate subject from body with a blank line
#   - Use the body to explain what and why vs. how
#   - Reference issues and pull requests
# --------------------
```

**Configure:**

```bash
git config commit.template .gitmessage
```

### **4.3 Atomic Commits**

**Principle:** Each commit should represent a single logical change.

**Good Examples:**

```bash
# ✅ Single responsibility
feat(proxy): add rate limiting middleware

# ✅ Complete feature
feat(agent): implement certificate bootstrap with Step-CA

# ✅ Focused fix
fix(sanitizer): handle UTF-8 split across chunk boundaries
```

**Bad Examples:**

```bash
# ❌ Multiple unrelated changes
feat: add rate limiting and fix memory leak and update docs

# ❌ Incomplete change
feat(proxy): partial implementation of sanitization (WIP)

# ❌ Vague description
fix: various bug fixes
```

### **4.4 GPG Commit Signing**

**Why:** Provides cryptographic proof of commit authorship.

**Setup:**

```bash
# Generate GPG key
gpg --full-generate-key
# Select: RSA and RSA, 4096 bits, no expiration
# Name: andrewgibson-cic
# Email: andrew.gibson-cic@ibm.com

# List keys
gpg --list-secret-keys --keyid-format=long

# Output example:
# sec   rsa4096/ABC123DEF456 2024-01-28 [SC]
#       1234567890ABCDEF1234567890ABCDEF12345678
# uid   andrewgibson-cic <andrew.gibson-cic@ibm.com>

# Export public key for GitHub
gpg --armor --export ABC123DEF456

# Add to GitHub: Settings → SSH and GPG keys → New GPG key

# Configure Git
git config --global user.signingkey ABC123DEF456
git config --global commit.gpgsign true
git config --global tag.gpgsign true
```

**Verify:**

```bash
git log --show-signature

# Output shows:
# commit abc123def456
# gpg: Signature made Mon 28 Jan 2024
# gpg: Good signature from "andrewgibson-cic <andrew.gibson-cic@ibm.com>"
```

---

## **5. Code Review Process**

### **5.1 Self-Review Checklist**

Since SLAPENIR is a solo project, use this checklist before merging:

#### **5.1.1 Functionality**

- [ ] Code implements the intended feature/fix completely
- [ ] All acceptance criteria met
- [ ] Edge cases handled
- [ ] Error handling implemented
- [ ] No hardcoded values (use environment variables)

#### **5.1.2 Testing**

- [ ] Unit tests added for new code
- [ ] Integration tests added if applicable
- [ ] Property tests added for security-critical paths
- [ ] All tests pass locally
- [ ] Coverage thresholds met (90%+)
- [ ] Manual testing performed

#### **5.1.3 Security**

- [ ] No secrets committed (checked by gitleaks)
- [ ] No SQL injection vulnerabilities
- [ ] Input validation implemented
- [ ] Authentication/authorization correct
- [ ] Dependencies scanned (cargo audit clean)
- [ ] Memory safety verified (zeroize applied)

#### **5.1.4 Code Quality**

- [ ] Follows Rust/Python style guides
- [ ] No compiler warnings
- [ ] Clippy lints pass
- [ ] Code is self-documenting or has comments
- [ ] No commented-out code
- [ ] No console.log/println! debugging statements

#### **5.1.5 Documentation**

- [ ] README updated if needed
- [ ] API documentation added
- [ ] Architecture docs updated
- [ ] Changelog entry will be auto-generated

### **5.2 Pull Request Template**

**File:** `.github/PULL_REQUEST_TEMPLATE.md`

```markdown
## Description

<!-- Brief description of what this PR does -->

## Type of Change

- [ ] feat: New feature
- [ ] fix: Bug fix
- [ ] security: Security patch
- [ ] refactor: Code refactoring
- [ ] test: Adding/updating tests
- [ ] docs: Documentation update
- [ ] chore: Maintenance

## Related Issues

<!-- Link to related issues: Closes #123, Fixes #456 -->

## Self-Review Checklist

### Functionality
- [ ] Code implements intended feature/fix completely
- [ ] Edge cases handled
- [ ] Error handling implemented

### Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added if needed
- [ ] All tests pass locally (`cargo test --workspace`)
- [ ] Coverage ≥ 90% (`cargo tarpaulin`)

### Security
- [ ] No secrets committed (verified with `gitleaks`)
- [ ] Cargo audit clean (`cargo audit`)
- [ ] Input validation implemented
- [ ] Memory safety verified (zeroize applied where needed)

### Code Quality
- [ ] No compiler warnings
- [ ] Clippy clean (`cargo clippy -- -D warnings`)
- [ ] Code formatted (`cargo fmt`)
- [ ] Python formatted (`black agent/`)

### Documentation
- [ ] README updated if needed
- [ ] Code comments added for complex logic
- [ ] Architecture docs updated if needed

## Testing Performed

<!-- Describe manual testing you performed -->

```bash
# Example:
cargo test --workspace
cargo tarpaulin --out Html
docker-compose up -d
# Tested full flow with mock API
```

## Screenshots (if applicable)

<!-- Add screenshots for UI changes -->

## Additional Notes

<!-- Any additional context or information -->
```

### **5.3 Automated Code Review Tools**

#### **5.3.1 Rust: Clippy**

```bash
# Run locally
cargo clippy --all-targets --all-features -- -D warnings

# Common issues caught:
# - Unused variables
# - Unnecessary clones
# - Inefficient string operations
# - Potential panic points
```

#### **5.3.2 Rust: Rustfmt**

```bash
# Check formatting
cargo fmt -- --check

# Auto-format
cargo fmt
```

**Configuration:** `rustfmt.toml`

```toml
edition = "2021"
max_width = 100
hard_tabs = false
tab_spaces = 4
newline_style = "Unix"
use_small_heuristics = "Default"
reorder_imports = true
reorder_modules = true
remove_nested_parens = true
```

#### **5.3.3 Python: Black & isort**

```bash
# Format Python code
black agent/
isort agent/

# Check only
black --check agent/
```

---

## **6. Release Management**

### **6.1 Semantic Versioning**

SLAPENIR follows [Semantic Versioning 2.0.0](https://semver.org/):

```
MAJOR.MINOR.PATCH

1.0.0 → Initial release
1.1.0 → New feature (backward compatible)
1.1.1 → Bug fix
2.0.0 → Breaking change
```

**Version Increment Rules:**

- **MAJOR:** Breaking changes (API changes, removed features)
- **MINOR:** New features (backward compatible)
- **PATCH:** Bug fixes, security patches

### **6.2 Release Process**

#### **Step 1: Prepare Release Branch**

```bash
# Create release branch
git checkout main
git pull origin main
git checkout -b release/v1.2.0

# Update version numbers
# proxy/Cargo.toml: version = "1.2.0"
# agent/setup.py: version="1.2.0"

git commit -m "chore(release): bump version to 1.2.0"
```

#### **Step 2: Generate Changelog**

```bash
# Install git-cliff
cargo install git-cliff

# Generate changelog
git-cliff --tag v1.2.0 --output CHANGELOG.md

# Review and edit if needed
git add CHANGELOG.md
git commit -m "docs(release): update changelog for v1.2.0"
```

#### **Step 3: Create Release PR**

```bash
git push origin release/v1.2.0

# Create PR via GitHub CLI
gh pr create \
  --title "Release v1.2.0" \
  --body "Release preparation for version 1.2.0" \
  --base main
```

#### **Step 4: Tag and Release**

```bash
# After PR is merged
git checkout main
git pull origin main

# Create signed tag
git tag -s v1.2.0 -m "Release version 1.2.0"

# Push tag
git push origin v1.2.0

# Create GitHub release
gh release create v1.2.0 \
  --title "SLAPENIR v1.2.0" \
  --notes-file CHANGELOG.md \
  --latest
```

### **6.3 Release Naming Convention**

```bash
# Format: v<MAJOR>.<MINOR>.<PATCH>

v1.0.0  # Initial release
v1.1.0  # Feature release
v1.1.1  # Patch release
v2.0.0  # Breaking change release

# Pre-releases (optional)
v1.2.0-alpha.1
v1.2.0-beta.1
v1.2.0-rc.1
```

### **6.4 Changelog Configuration**

**File:** `cliff.toml`

```toml
[changelog]
header = """
# Changelog\n
All notable changes to SLAPENIR will be documented in this file.\n
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).\n
"""

body = """
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {% if commit.breaking %}[**BREAKING**] {% endif %}{{ commit.message | upper_first }}\
    {% endfor %}
{% endfor %}\n
"""

[git]
conventional_commits = true
filter_unconventional = true
commit_parsers = [
  { message = "^feat", group = "Features"},
  { message = "^fix", group = "Bug Fixes"},
  { message = "^security", group = "Security"},
  { message = "^perf", group = "Performance"},
  { message = "^docs", group = "Documentation"},
  { message = "^test", skip = true},
  { message = "^chore", skip = true},
  { message = "^ci", skip = true},
]
```

### **6.5 Rollback Procedure**

If a release introduces critical issues:

```bash
# Revert to previous version
git checkout v1.1.0

# Create hotfix branch
git checkout -b hotfix/revert-v1.2.0

# Revert problematic commits
git revert <commit-hash>

# Create new patch release
git tag -s v1.2.1 -m "Hotfix: Revert problematic changes"
git push origin v1.2.1

# Update deployment
docker pull ghcr.io/andrewgibson-cic/slapenir:v1.2.1
docker-compose up -d
```

---

## **7. Security Measures**

### **7.1 Pre-Commit Secret Scanning**

**Tool:** Gitleaks

**Installation:**

```bash
# macOS
brew install gitleaks

# Linux
wget https://github.com/gitleaks/gitleaks/releases/download/v8.18.0/gitleaks_8.18.0_linux_x64.tar.gz
tar -xzf gitleaks_8.18.0_linux_x64.tar.gz
sudo mv gitleaks /usr/local/bin/
```

**Configuration:** `.gitleaks.toml`

```toml
title = "SLAPENIR Gitleaks Configuration"

[extend]
useDefault = true

[[rules]]
id = "github-token"
description = "GitHub Personal Access Token"
regex = '''ghp_[0-9a-zA-Z]{36}'''
tags = ["key", "github"]

[[rules]]
id = "aws-access-key"
description = "AWS Access Key ID"
regex = '''AKIA[0-9A-Z]{16}'''
tags = ["key", "aws"]

[[rules]]
id = "openai-api-key"
description = "OpenAI API Key"
regex = '''sk-[a-zA-Z0-9]{48}'''
tags = ["key", "openai"]

[[rules]]
id = "private-key"
description = "Private Key"
regex = '''-----BEGIN (RSA|EC|OPENSSH) PRIVATE KEY-----'''
tags = ["key", "private"]

[allowlist]
description = "Allowlist test fixtures"
paths = [
  '''tests/fixtures/tokens\.json''',
  '''tests/fixtures/certs/.*\.key''',
]
```

**Usage:**

```bash
# Scan staged files
gitleaks protect --staged

# Scan entire repo
gitleaks detect --source . --verbose

# Scan specific commit
gitleaks detect --log-opts="--since=2024-01-01"
```

### **7.2 Server-Side Scanning (GitHub)**

**Enable GitHub Secret Scanning:**

1. Go to repository Settings → Code security and analysis
2. Enable "Secret scanning"
3. Enable "Push protection"

**Result:** GitHub will:
- Scan all commits for secrets
- Block pushes containing secrets
- Alert you of historical secrets

### **7.3 Dependency Security**

#### **7.3.1 Rust: Cargo Audit**

```bash
# Install
cargo install cargo-audit

# Scan dependencies
cargo audit

# Fix vulnerabilities
cargo audit fix

# CI integration (fail on vulnerabilities)
cargo audit --deny warnings
```

#### **7.3.2 Dependabot Configuration**

**File:** `.github/dependabot.yml`

```yaml
version: 2
updates:
  # Rust dependencies
  - package-ecosystem: "cargo"
    directory: "/proxy"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "rust"
    commit-message:
      prefix: "chore(deps)"
    reviewers:
      - "andrewgibson-cic"
  
  # Python dependencies
  - package-ecosystem: "pip"
    directory: "/agent"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "python"
    commit-message:
      prefix: "chore(deps)"
  
  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "monthly"
    labels:
      - "dependencies"
      - "ci"
    commit-message:
      prefix: "ci(deps)"
```

### **7.4 Security Patch Workflow**

When a security vulnerability is discovered:

```bash
# 1. Create hotfix branch
git checkout main
git checkout -b hotfix/cve-2024-12345-rustls

# 2. Update vulnerable dependency
cargo update rustls

# 3. Run security audit
cargo audit

# 4. Run tests
cargo test --workspace

# 5. Commit with security type
git commit -m "security(proxy): patch CVE-2024-12345 in rustls

Upgraded rustls from 0.21.0 to 0.21.10 to address TLS
handshake vulnerability that could lead to denial of service.

CVE-2024-12345: https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2024-12345"

# 6. Fast-track merge (can bypass some CI for critical patches)
git push origin hotfix/cve-2024-12345-rustls

# 7. Create immediate patch release
git tag -s v1.2.1 -m "Security patch for CVE-2024-12345"
git push origin v1.2.1
```

### **7.5 Secrets Management**

**Never commit:**
- API keys
- Passwords
- Private keys
- Certificates (except test fixtures)
- .env files

**Use instead:**
- Environment variables
- GitHub Secrets (for CI/CD)
- Docker Secrets (for production)
- Dummy values in code/tests

**If secret is committed:**

```bash
# Use BFG Repo Cleaner
bfg --delete-files secrets.json

# Or git-filter-repo
git filter-repo --invert-paths --path secrets.json

# Force push (DANGEROUS - coordinate with team)
git push origin --force --all

# Rotate the compromised secret immediately!
```

---

## **8. Workflow Automation**

### **8.1 GitHub Actions Workflows**

#### **8.1.1 Main CI/CD Pipeline**

**File:** `.github/workflows/ci.yml`

```yaml
name: CI/CD Pipeline

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  lint-and-format:
    name: Lint & Format Check
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
          components: rustfmt, clippy
      
      - name: Check Rust formatting
        run: cargo fmt -- --check
      
      - name: Run Clippy
        run: cargo clippy --all-targets --all-features -- -D warnings
      
      - name: Check Python formatting
        run: |
          pip install black isort
          black --check agent/
          isort --check-only agent/

  test:
    name: Test Suite
    runs-on: ubuntu-latest
    needs: lint-and-format
    steps:
      - uses: actions/checkout@v4
      
      - name: Run tests
        run: cargo test --workspace --verbose
      
      - name: Run property tests
        run: cargo test --release proptest
        env:
          PROPTEST_CASES: 1000

  security:
    name: Security Audit
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
      
      - name: Run Cargo Audit
        uses: actions-rs/cargo@v1
        with:
          command: audit
          args: --deny warnings

  coverage:
    name: Code Coverage
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4
      
      - name: Generate coverage
        run: |
          cargo install cargo-tarpaulin
          cargo tarpaulin --out Xml --workspace
      
      - name: Upload to Codecov
        uses: codecov/codecov-action@v3
        with:
          token: ${{ secrets.CODECOV_TOKEN }}
          fail_ci_if_error: true
```

#### **8.1.2 Release Automation**

**File:** `.github/workflows/release.yml`

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build-and-release:
    name: Build and Release
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      
      - name: Install Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: stable
      
      - name: Build proxy
        run: cargo build --release --manifest-path proxy/Cargo.toml
      
      - name: Generate changelog
        run: |
          cargo install git-cliff
          git-cliff --latest --output RELEASE_NOTES.md
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          body_path: RELEASE_NOTES.md
          files: |
            target/release/proxy
          draft: false
          prerelease: false
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### **8.2 Pre-commit Hooks Configuration**

**File:** `.pre-commit-config.yaml`

```yaml
repos:
  - repo: local
    hooks:
      # Gitleaks secret scanning
      - id: gitleaks
        name: Gitleaks (secret scanning)
        entry: gitleaks protect --staged --redact --verbose
        language: system
        pass_filenames: false
      
      # Rust formatting
      - id: cargo-fmt
        name: cargo fmt
        entry: cargo fmt --manifest-path proxy/Cargo.toml --
        language: system
        types: [rust]
        pass_filenames: false
      
      # Rust linting
      - id: cargo-clippy
        name: cargo clippy
        entry: cargo clippy --manifest-path proxy/Cargo.toml -- -D warnings
        language: system
        types: [rust]
        pass_filenames: false
      
      # Rust tests (fast unit tests only)
      - id: cargo-test
        name: cargo test (unit)
        entry: cargo test --manifest-path proxy/Cargo.toml --lib
        language: system
        types: [rust]
        pass_filenames: false
      
      # Python formatting
      - id: black
        name: black
        entry: black
        language: system
        types: [python]
        args: [--check]
      
      - id: isort
        name: isort
        entry: isort
        language: system
        types: [python]
        args: [--check-only]
      
      # Trailing whitespace
      - id: trailing-whitespace
        name: Trim trailing whitespace
        entry: trailing-whitespace-fixer
        language: system
        types: [text]
      
      # Mixed line endings
      - id: mixed-line-ending
        name: Check mixed line endings
        entry: mixed-line-ending
        language: system
        types: [text]
        args: [--fix=lf]
```

**Installation:**

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install

# Run manually on all files
pre-commit run --all-files

# Skip hooks (emergency only)
git commit --no-verify -m "hotfix: critical security patch"
```

---

## **9. Development Workflow**

### **9.1 Daily Development Flow**

```bash
# === Morning: Start New Feature ===

# 1. Update main branch
git checkout main
git pull origin main

# 2. Create feature branch
git checkout -b feature/proxy-rate-limiting

# 3. Make changes
# ... code, code, code ...

# 4. Test locally
cargo test --workspace
cargo tarpaulin --out Html

# 5. Commit (triggers pre-commit hooks)
git add src/rate_limiter.rs tests/test_rate_limiter.rs
git commit -m "feat(proxy): implement token bucket rate limiter

- Add TokenBucket struct with configurable capacity
- Implement middleware integration with tower
- Add unit tests with edge cases
- Add property tests for fairness

Closes #42"

# 6. Push to remote
git push origin feature/proxy-rate-limiting

# === Afternoon: Continue Work ===

# 7. Make more changes
# ... more code ...

# 8. Commit again (atomic commits)
git commit -m "test(proxy): add integration test for rate limiting"

# 9. Push updates
git push origin feature/proxy-rate-limiting

# === Evening: Ready to Merge ===

# 10. Rebase on main (if main has changed)
git checkout main
git pull origin main
git checkout feature/proxy-rate-limiting
git rebase main

# 11. Force push after rebase
git push origin feature/proxy-rate-limiting --force-with-lease

# 12. Create PR
gh pr create \
  --title "feat(proxy): implement rate limiting" \
  --body "Implements token bucket rate limiter as specified in #42" \
  --base main

# 13. Wait for CI to pass, then merge via GitHub UI

# 14. Clean up
git checkout main
git pull origin main
git branch -d feature/proxy-rate-limiting
```

### **9.2 Bug Fix Flow**

```bash
# 1. Create fix branch from main
git checkout main
git pull origin main
git checkout -b fix/split-secret-detection

# 2. Write failing test first (TDD)
# tests/test_sanitizer.rs
git add tests/test_sanitizer.rs
git commit -m "test(sanitizer): add failing test for split secret bug"

# 3. Implement fix
# src/sanitizer.rs
git add src/sanitizer.rs
git commit -m "fix(sanitizer): handle secrets split across 4KB boundaries

The Aho-Corasick buffer was not maintaining sufficient overlap
between chunks. Increased overlap buffer to max(secret_length).

Fixes #78"

# 4. Push and create PR
git push origin fix/split-secret-detection
gh pr create --fill

# 5. Merge and clean up
# (after CI passes)
git checkout main
git pull origin main
git branch -d fix/split-secret-detection
```

### **9.3 Hotfix Flow (Critical Security)**

```bash
# 1. Create hotfix branch immediately
git checkout main
git checkout -b hotfix/cve-2024-12345

# 2. Apply emergency patch
cargo update rustls
cargo audit  # Verify fix

# 3. Fast commit
git commit -am "security(proxy): patch CVE-2024-12345 in rustls

CRITICAL: Upgraded rustls to address remote code execution
vulnerability. All deployments must update immediately.

CVE-2024-12345"

# 4. Push and merge (can skip some CI checks)
git push origin hotfix/cve-2024-12345

# 5. Tag immediately
git tag -s v1.2.1 -m "Security hotfix for CVE-2024-12345"
git push origin v1.2.1

# 6. Deploy immediately
docker pull ghcr.io/andrewgibson-cic/slapenir:v1.2.1
docker-compose up -d
```

### **9.4 Interactive Rebase (Cleaning History)**

```bash
# Before pushing, clean up messy commits
git rebase -i HEAD~3

# Interactive editor shows:
# pick abc123 feat(proxy): add rate limiter
# pick def456 fix typo
# pick ghi789 test(proxy): add tests

# Change to:
# pick abc123 feat(proxy): add rate limiter
# fixup def456 fix typo  # Merges into previous
# pick ghi789 test(proxy): add tests

# Save and exit - history is now clean
```

### **9.5 Cherry-Picking Commits**

```bash
# Apply specific commit from another branch
git checkout main
git cherry-pick abc123def456

# Apply multiple commits
git cherry-pick abc123..def456

# Cherry-pick without committing (to modify)
git cherry-pick -n abc123
```

---

## **10. Tooling Setup**

### **10.1 Required Tools**

```bash
# === Git Tools ===
git --version                    # Git 2.40+
gh --version                     # GitHub CLI

# === Rust Tools ===
cargo --version                  # Rust 1.75+
cargo install cargo-audit        # Security scanning
cargo install cargo-tarpaulin    # Coverage
cargo install git-cliff          # Changelog generation

# === Python Tools ===
pip install pre-commit black isort pytest

# === Security Tools ===
brew install gitleaks            # Secret scanning

# === Optional ===
brew install lazygit             # TUI for git
```

### **10.2 Git Aliases**

Add to `~/.gitconfig`:

```gitconfig
[alias]
    # Short status
    st = status -sb
    
    # Pretty log
    lg = log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
    
    # Last commit
    last = log -1 HEAD --stat
    
    # Amend without editing message
    amend = commit --amend --no-edit
    
    # Undo last commit (keeps changes)
    undo = reset HEAD~1 --soft
    
    # Discard all local changes
    nuke = reset --hard HEAD
    
    # List branches by date
    branches = branch --sort=-committerdate
    
    # Delete merged branches
    cleanup = "!git branch --merged | grep -v '\\*\\|main\\|develop' | xargs -n 1 git branch -d"
    
    # Show files changed in last commit
    changed = diff-tree --no-commit-id --name-only -r HEAD
```

### **10.3 Editor Configuration**

**VS Code:** `.vscode/settings.json`

```json
{
  "git.enableCommitSigning": true,
  "git.alwaysSignOff": true,
  "git.confirmSync": false,
  "git.autofetch": true,
  "git.pruneOnFetch": true,
  "editor.rulers": [50, 72, 100],
  "git.inputValidation": "always",
  "git.inputValidationLength": 50,
  "git.inputValidationSubjectLength": 50
}
```

---

## **11. Best Practices**

### **11.1 Commit Hygiene**

✅ **DO:**
- Write clear, descriptive commit messages
- Make atomic commits (one logical change)
- Test before committing
- Sign commits with GPG
- Reference issues in commit messages
- Use conventional commit format

❌ **DON'T:**
- Commit broken code
- Mix refactoring with features
- Commit commented-out code
- Use generic messages ("fix stuff", "WIP")
- Commit secrets or credentials
- Skip pre-commit hooks without good reason

### **11.2 Branch Management**

✅ **DO:**
- Keep branches short-lived (< 3 days)
- Delete merged branches
- Rebase on main before merging
- Use descriptive branch names
- Keep main branch always deployable

❌ **DON'T:**
- Let branches go stale
- Accumulate many long-lived branches
- Force push to main
- Merge broken code
- Leave WIP branches unfinished

### **11.3 Code Review**

✅ **DO:**
- Review your own code before pushing
- Run full test suite locally
- Check for security issues
- Update documentation
- Verify CI passes before merging

❌ **DON'T:**
- Merge failing CI
- Skip testing
- Ignore security warnings
- Leave TODOs in production code
- Rush hotfixes without testing

---

## **12. Appendices**

### **Appendix A: Git Command Cheatsheet**

```bash
# === Basic Operations ===
git status                       # Check status
git add <file>                   # Stage file
git commit -m "message"          # Commit
git push origin <branch>         # Push
git pull origin <branch>         # Pull

# === Branching ===
git branch                       # List branches
git branch <name>                # Create branch
git checkout <branch>            # Switch branch
git checkout -b <branch>         # Create and switch
git branch -d <branch>           # Delete branch

# === Undoing Changes ===
git reset HEAD <file>            # Unstage file
git checkout -- <file>           # Discard changes
git revert <commit>              # Revert commit
git reset --hard HEAD~1          # Delete last commit

# === History ===
git log                          # View history
git log --oneline                # Compact history
git show <commit>                # Show commit
git diff                         # Show changes

# === Stashing ===
git stash                        # Stash changes
git stash pop                    # Apply stash
git stash list                   # List stashes
git stash drop                   # Delete stash

# === Remotes ===
git remote -v                    # List remotes
git fetch origin                 # Fetch changes
git push -u origin <branch>      # Set upstream

# === Rebasing ===
git rebase main                  # Rebase on main
git rebase -i HEAD~3             # Interactive rebase
git rebase --continue            # Continue after conflict
git rebase --abort               # Abort rebase
```

### **Appendix B: Troubleshooting Common Issues**

**Problem: Accidentally committed to main**

```bash
# Move commits to new branch
git branch feature/my-work
git reset --hard origin/main
git checkout feature/my-work
```

**Problem: Need to fix last commit message**

```bash
git commit --amend -m "New message"
git push --force-with-lease
```

**Problem: Committed secret accidentally**

```bash
# Remove from history
git filter-repo --invert-paths --path secrets.json
git push origin --force --all

# THEN: Rotate the secret immediately!
```

**Problem: Merge conflict**

```bash
# 1. See conflicting files
git status

# 2. Edit files, remove conflict markers
# <<<<<<< HEAD
# =======
# >>>>>>> branch

# 3. Stage resolved files
git add <file>

# 4. Complete merge
git commit
```

**Problem: Want to undo git push**

```bash
# If no one else has pulled
git reset --hard HEAD~1
git push --force-with-lease

# If others have pulled - revert instead
git revert HEAD
git push
```

### **Appendix C: Conventional Commit Quick Reference**

| Prefix | Use Case | Example |
|--------|----------|---------|
| `feat:` | New feature | `feat(proxy): add rate limiting` |
| `fix:` | Bug fix | `fix(agent): correct cert renewal` |
| `security:` | Security patch | `security(proxy): patch CVE-2024-001` |
| `perf:` | Performance | `perf(sanitizer): optimize regex` |
| `refactor:` | Refactoring | `refactor(proxy): extract middleware` |
| `test:` | Tests | `test(proxy): add property tests` |
| `docs:` | Documentation | `docs(readme): update installation` |
| `chore:` | Maintenance | `chore(deps): update dependencies` |
| `ci:` | CI/CD | `ci(actions): add coverage workflow` |

### **Appendix D: Summary**

This Git strategy provides a comprehensive framework for maintaining SLAPENIR's codebase with:

1. **Security-first approach** with automated secret scanning
2. **Automated quality gates** via GitHub Actions
3. **Clear audit trail** through signed commits and conventional format
4. **Streamlined workflow** optimized for solo development
5. **Semantic versioning** with automated changelog generation

**Key Principle:** Every commit to `main` should be production-ready and fully tested.

**Next Steps:**
1. Configure local environment (Section 2 & 10)
2. Set up pre-commit hooks (Section 8.2)
3. Create first feature branch following workflow (Section 9.1)
4. Review self-review checklist before each merge (Section 5.1)

---

**Document Maintenance:**
- Review quarterly for workflow improvements
- Update after implementing new tooling
- Revise based on lessons learned from incidents
- Keep synchronized with TDD Strategy document

**References:**
- [SLAPENIR TDD Strategy](./SLAPENIR_TDD_Strategy.md)
- [SLAPENIR Architecture](./SLAPENIR_Architecture.md)
- [SLAPENIR Specifications](./SLAPENIR_Specifications.md)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Semantic Versioning](https://semver.org/)
- [GitHub Flow](https://guides.github.com/introduction/flow/)
