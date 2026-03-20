# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.x.x   | ✅ |
| < 1.0   | ❌ |

## Reporting a Vulnerability

**Do NOT open a public issue for security vulnerabilities.**

Instead, please report security issues by:

1. **Email**: Send details to security@slapenir.dev (if available)
2. **GitHub Security Advisory**: Use GitHub's private vulnerability reporting at [github.com/andrewgibson-cic/slapenir/security/advisories](https://github.com/andrewgibson-cic/slapenir/security/advisories)

### What to Include

- Description of the vulnerability
- Steps to reproduce
- Affected versions
- Potential impact
- Suggested fix (if available)

### Response Timeline

| Stage | Target |
|-------|--------|
| Acknowledgment | 48 hours |
| Initial assessment | 7 days |
| Fix development | 14 days (critical), 30 days (moderate) |
| Disclosure | After fix is released |

## Security Features

SLAPENIR implements defense-in-depth security:

### Zero-Knowledge Architecture

- Agents never see real credentials
- DUMMY tokens are replaced at the proxy layer
- Real secrets are memory-protected with zeroize

### Network Isolation

- Internal Docker network with no direct internet access
- iptables-based traffic enforcement
- mTLS between all services

### Memory Safety

- Proxy written in Rust with zeroize trait
- No garbage collection delays
- Deterministic memory wiping

### Certificate Management

- Short-lived mTLS certificates (24h default)
- Automated enrollment via Step-CA
- Certificate rotation support

## Security Best Practices

### For Deployment

1. **Change default passwords** in `.env`
2. **Use strong CA passwords** (32+ characters)
3. **Enable mTLS enforcement** (`MTLS_ENFORCE=true`)
4. **Rotate tokens regularly** (90 days max)
5. **Monitor audit logs** from proxy and GitHub

### For Development

1. **Never commit secrets** to the repository
2. **Use `.env.example`** as template only
3. **Run security scans** before PRs (`cargo audit`)
4. **Review dependencies** for CVEs

## Security Audit

SLAPENIR has undergone security review:

- Credential sanitization bypass testing
- mTLS implementation verification
- Memory safety validation
- Network isolation testing

Run security tests:
```bash
# Dependency vulnerability scan
cd proxy && cargo audit

# Full security test suite
./agent/tests/run_security_tests.sh
```

## Disclosure Policy

We follow responsible disclosure:

1. Report received and acknowledged
2. Vulnerability confirmed and assessed
3. Fix developed and tested
4. Patch released
5. CVE assigned (if applicable)
6. Public disclosure (30 days after patch)

## Contact

- **Security issues**: See reporting instructions above
- **General questions**: Open a GitHub issue
- **Documentation**: See [docs/SLAPENIR_Architecture.md](docs/SLAPENIR_Architecture.md)
