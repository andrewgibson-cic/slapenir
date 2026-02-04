# GitHub Actions Workflows

This directory contains automated CI/CD workflows for the SLAPENIR project.

## 📋 Available Workflows

### 1. **test.yml** - Continuous Integration Tests
**Triggers:** Push to `main`/`develop`, Pull Requests

**Purpose:** Run comprehensive test suite on every code change

**Jobs:**
- **proxy-tests**: Rust tests, linting, formatting, type checking
  - `cargo test` - Unit, integration, and property-based tests
  - `cargo clippy` - Linting with strict warnings
  - `cargo fmt` - Code formatting verification
  - Coverage reporting with tarpaulin
- **python-lint**: Python code quality checks
  - `ruff` - Fast Python linter
  - `black` - Code formatting verification
- **agent-tests**: Python tests
  - Unit tests (test_agent.py)
  - Advanced tests (test_agent_advanced.py)
  - Coverage reporting with pytest-cov
- **integration-tests**: Docker-based end-to-end tests
  - Build all services
  - Verify health endpoints
  - Test service interactions
- **security-audit**: Quick security checks
  - `cargo audit` - Rust dependency vulnerabilities
  - `cargo deny` - Security policy enforcement

**Status Badge:**
```markdown
![Tests](https://github.com/YOUR_ORG/slapenir/actions/workflows/test.yml/badge.svg)
```

---

### 2. **release.yml** - Semantic Releases
**Triggers:** Push to `main`, Manual workflow_dispatch

**Purpose:** Automated semantic versioning and release creation

**Release Process:**
1. **Test Phase**: Run full test suite
2. **Security Phase**: CVE scanning before release
3. **Release Phase**: Semantic version analysis
   - Analyzes conventional commits
   - Generates version number (semver)
   - Creates CHANGELOG.md
   - Creates GitHub release with notes
   - Tags repository (v1.2.3)
4. **Docker Phase**: Build and tag images with version

**Conventional Commit Format:**
```bash
# Minor version bump (v1.1.0)
feat: add new feature
feat(proxy): add AWS SigV4 support

# Patch version bump (v1.0.1)
fix: resolve bug
fix(agent): correct heartbeat timing

# Major version bump (v2.0.0)
feat!: breaking change
feat(api)!: redesign configuration API

# No release
docs: update documentation
test: add test coverage
chore: update dependencies
```

**Release Types:**
| Commit Type | Release | Example |
|-------------|---------|---------|
| `feat:` | Minor (1.x.0) | New feature |
| `fix:` | Patch (1.0.x) | Bug fix |
| `feat!:` | Major (x.0.0) | Breaking change |
| `perf:` | Patch | Performance improvement |
| `refactor:` | Patch | Code refactoring |
| `docs:` | None | Documentation only |
| `test:` | None | Test updates |
| `chore:` | None | Maintenance |

**Status Badge:**
```markdown
![Release](https://github.com/YOUR_ORG/slapenir/actions/workflows/release.yml/badge.svg)
```

---

### 3. **security.yml** - Security & CVE Scanning
**Triggers:** Push, Pull Requests, Weekly schedule (Mondays 9:00 UTC), Manual

**Purpose:** Comprehensive security vulnerability scanning

**Scans:**
- **Rust Security**:
  - `cargo-audit` - RustSec advisory database
  - `cargo-deny` - Security policy enforcement
  - Dependency vulnerability checking
- **Python Security**:
  - `pip-audit` - PyPI vulnerability scanner
  - `safety` - Known security vulnerabilities
  - `bandit` - Python code security analysis
- **Docker Security**:
  - `trivy` - Container image scanning
  - Scans for HIGH/CRITICAL vulnerabilities
  - OS packages and application dependencies
- **Dependency Review** (PRs only):
  - GitHub native dependency analysis
  - License compliance checking

**Automated Issue Creation:**
- Creates GitHub issue if vulnerabilities found (scheduled runs only)
- Labels: `security`, `vulnerability`, `automated`
- Includes links to detailed reports

**Artifacts:**
- Bandit report (JSON)
- Trivy scan results (JSON)

**Status Badge:**
```markdown
![Security](https://github.com/YOUR_ORG/slapenir/actions/workflows/security.yml/badge.svg)
```

---

## 🚀 Usage Guide

### Running Tests Locally

**Rust (Proxy):**
```bash
cd proxy
cargo fmt --check
cargo clippy -- -D warnings
cargo test
```

**Python (Agent):**
```bash
# Install tools
pip install ruff black pytest pytest-cov

# Run linting
ruff check agent/scripts/
black --check agent/scripts/

# Run tests
python3 agent/tests/test_agent.py
python3 agent/tests/test_agent_advanced.py
```

### Manual Workflow Triggers

**Security Scan:**
```bash
# Via GitHub UI: Actions → Security Scan → Run workflow
# Or via GitHub CLI:
gh workflow run security.yml
```

**Release:**
```bash
# Via GitHub UI: Actions → Release → Run workflow
# Or via GitHub CLI:
gh workflow run release.yml
```

### Creating a Release

1. **Make commits using conventional format:**
   ```bash
   git commit -m "feat: add new strategy support"
   git commit -m "fix: resolve memory leak in sanitizer"
   ```

2. **Push to main:**
   ```bash
   git push origin main
   ```

3. **Release workflow automatically:**
   - Runs tests and security scans
   - Analyzes commits since last release
   - Generates new version number
   - Creates GitHub release
   - Tags repository
   - Builds Docker images

### Viewing Security Reports

**In GitHub UI:**
1. Go to Actions tab
2. Select "Security Scan" workflow
3. Click on latest run
4. Download artifacts (bandit-report, trivy-reports)

**Viewing Summary:**
- Each workflow run generates a summary in the Actions UI
- Look for the "Summary" section in completed workflow runs

---

## 📊 Workflow Dependencies

```
test.yml:
  ├── proxy-tests
  ├── python-lint
  ├── agent-tests (depends on: python-lint)
  ├── integration-tests (depends on: proxy-tests, agent-tests)
  ├── security-audit
  └── test-summary (depends on: all)

release.yml:
  ├── test (runs full test suite)
  ├── security (runs security scans)
  ├── release (depends on: test, security)
  ├── docker (depends on: release)
  └── release-summary (depends on: all)

security.yml:
  ├── rust-security
  ├── python-security
  ├── docker-security
  ├── dependency-review (PRs only)
  ├── cve-summary (depends on: all security jobs)
  └── create-issue (depends on: all security jobs, scheduled only)
```

---

## 🔧 Configuration

### Required Secrets

None required for basic functionality. The workflows use `GITHUB_TOKEN` which is automatically provided.

**Optional secrets for future enhancements:**
- `DOCKER_USERNAME` - For Docker Hub publishing
- `DOCKER_PASSWORD` - For Docker Hub authentication
- `CODECOV_TOKEN` - For Codecov.io integration (currently using anonymous uploads)

### Environment Variables

All workflows use:
```yaml
env:
  RUST_VERSION: 1.93.0
  PYTHON_VERSION: 3.11
```

### Permissions

**release.yml:**
```yaml
permissions:
  contents: write      # Create releases and tags
  issues: write        # (Reserved for future use)
  pull-requests: write # (Reserved for future use)
  packages: write      # (Reserved for Docker publishing)
```

**security.yml:**
```yaml
permissions:
  issues: write  # Create security issues
```

---

## 📈 Metrics & Monitoring

### Test Coverage
- Rust: ~82% (target: >80%)
- Python: ~85% (target: >80%)
- Reports uploaded to Codecov (optional)

### Workflow Performance
- **test.yml**: ~5-8 minutes
- **release.yml**: ~10-15 minutes
- **security.yml**: ~8-12 minutes

---

## 🐛 Troubleshooting

### Tests Failing

**Rust clippy warnings:**
```bash
# Fix locally first
cd proxy
cargo clippy --fix
cargo fmt
```

**Python formatting issues:**
```bash
# Auto-format code
black agent/scripts/
ruff check agent/scripts/ --fix
```

### Release Not Created

**Check commit messages:**
- Must use conventional commit format
- Must include `feat:`, `fix:`, or breaking change
- `docs:`, `chore:`, `test:` commits don't trigger releases

**View semantic-release logs:**
1. Go to Actions → Release workflow
2. Check "Run semantic-release" step
3. Look for commit analysis output

### Security Scan False Positives

**Rust:**
```bash
# Add to proxy/.cargo/deny.toml
[advisories]
ignore = ["RUSTSEC-2021-0139"]  # Add specific advisory IDs
```

**Python:**
```bash
# Add to pyproject.toml or suppress in workflow
pip-audit --ignore-vuln PYSEC-2021-123
```

---

## 🔄 Workflow Updates

When modifying workflows:

1. **Test locally first** (where possible)
2. **Use feature branches** for workflow changes
3. **Test on PRs** before merging to main
4. **Document changes** in this README
5. **Update version numbers** if dependencies change

---

## 📚 Additional Resources

- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Semantic Release](https://github.com/semantic-release/semantic-release)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [Cargo Audit](https://github.com/rustsec/rustsec/tree/main/cargo-audit)
- [Trivy](https://github.com/aquasecurity/trivy)
- [Ruff](https://github.com/astral-sh/ruff)

---

**Last Updated:** 2026-01-31  
**Maintainer:** Andrew Gibson (andrew.gibson-cic@ibm.com)