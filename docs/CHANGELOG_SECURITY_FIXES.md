# Security Fixes Changelog

## 2026-01-02 - Dependency Security Updates

### Critical Vulnerability Fixed
- **RUSTSEC-2024-0437**: Fixed protobuf crash vulnerability
  - Upgraded `prometheus` from 0.13.4 → 0.14.0
  - This upgrade transitively updated `protobuf` from 2.28.0 → 3.7.2
  - **Impact**: Eliminated crash risk due to uncontrolled recursion in protobuf parsing
  - **Severity**: Critical

### Dependency Updates
- **prometheus**: 0.13.4 → 0.14.0
  - Metrics library for Prometheus instrumentation
  - API-compatible upgrade with no code changes required
  - All tests pass with new version

- **rustls-pemfile**: 2.0 → 2.2
  - Updated to latest available version
  - Note: RUSTSEC-2025-0134 warning remains (crate is unmaintained)
  - This is an acceptable warning as 2.2.0 is the latest version
  - Functionality remains secure and stable

### Verification
- ✅ All 43 unit tests pass
- ✅ Code compiles without errors
- ✅ cargo audit shows only 1 allowed warning (rustls-pemfile unmaintained)
- ✅ No breaking API changes
- ✅ Formatting applied via rustfmt

### Testing Performed
```bash
# Update dependencies
cargo update

# Security audit
cargo audit
# Result: 0 vulnerabilities, 1 allowed warning

# Build verification
cargo build
# Result: Success

# Test suite
cargo test
# Result: 43 passed; 0 failed

# Format check
cargo fmt -- --check
# Result: All files formatted correctly
```

### Commits
1. `style(proxy): apply rustfmt to fix code formatting` (bca108f)
2. `security(proxy): patch RUSTSEC-2024-0437 protobuf vulnerability` (pending)

### References
- [RUSTSEC-2024-0437](https://rustsec.org/advisories/RUSTSEC-2024-0437) - protobuf uncontrolled recursion
- [RUSTSEC-2025-0134](https://rustsec.org/advisories/RUSTSEC-2025-0134) - rustls-pemfile unmaintained (warning only)