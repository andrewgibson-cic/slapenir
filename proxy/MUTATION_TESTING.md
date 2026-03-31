# Mutation Testing Configuration

This document describes mutation testing setup for SLAPENIR using cargo-mutants.

## What is Mutation Testing?

Mutation testing evaluates test quality by introducing small changes (mutations) to the code and checking if tests catch them. It helps identify:
- Weak test assertions
- Missing edge cases
- Untested code paths

## Installation

```bash
cargo install cargo-mutants
```

## Configuration

### .cargo/mutants.toml

```toml
# Mutation testing configuration

# Exclude test files and generated code
exclude_globs = [
    "*/tests/*",
    "*/benches/*",
    "*/target/*",
]

# Timeout for each mutation (prevents infinite loops)
timeout_secs = 60

# Number of parallel jobs
jobs = 4

# Minimum test coverage required
min_test_coverage = 80

# Mutant operators to use
operators = [
    "arithmetic",
    "boolean",
    "comparison",
    "conditional",
    "function_call",
    "literal",
    "logical",
    "relational",
    "return",
]
```

## Running Mutation Tests

### Quick Check (during development)

```bash
# Run on a specific file
cargo mutants --file src/sanitizer.rs

# Run with limited mutations
cargo mutants --max-mutations 50
```

### Full Suite (CI/CD)

```bash
# Run complete mutation testing
cargo mutants --jobs 4 --timeout 60

# Generate HTML report
cargo mutants --output html
```

### Specific Scenarios

```bash
# Test only sanitizer module
cargo mutants --dir src/sanitizer

# Test with specific mutation operator
cargo mutants --operator arithmetic

# Test excluding certain mutations
cargo mutants --exclude-operator function_call
```

## CI/CD Integration

### GitHub Actions Integration

Mutation testing is integrated into `.github/workflows/test.yml` as the `mutation-tests` job. It runs as part of the standard CI pipeline alongside other test jobs.

## Expected Results

### Mutation Score Targets

| Module | Target Score | Current | Status |
|--------|-------------|---------|--------|
| sanitizer | >85% | TBD | Required |
| proxy | >80% | TBD | Required |
| strategy | >75% | TBD | Required |
| Overall | >80% | TBD | Required |

### Interpreting Results

**High Mutation Score (>80%)**
- ✅ Tests are robust
- ✅ Edge cases covered
- ✅ Good assertions

**Medium Score (60-80%)**
- ⚠️ Some gaps in test coverage
- ⚠️ Consider adding edge case tests

**Low Score (<60%)**
- ❌ Tests are weak
- ❌ Missing critical test cases
- ❌ Needs improvement before production

## Common Mutation Types

### Arithmetic Operator Mutations
```rust
// Original
let sum = a + b;
// Mutated
let sum = a - b;  // Should be caught by tests
```

### Boolean Mutations
```rust
// Original
if is_valid {
// Mutated
if false {  // Should be caught by tests
```

### Comparison Mutations
```rust
// Original
if value > threshold {
// Mutated
if value >= threshold {  // Should be caught by boundary tests
```

### Literal Mutations
```rust
// Original
const MAX_SIZE: usize = 1024;
// Mutated
const MAX_SIZE: usize = 0;  // Should be caught by tests
```

## Improving Mutation Scores

### 1. Add Boundary Tests

```rust
#[test]
fn test_boundary_conditions() {
    // Test exact boundary
    assert_eq!(function(100), expected_at_100);
    
    // Test just below
    assert_eq!(function(99), expected_below);
    
    // Test just above
    assert_eq!(function(101), expected_above);
}
```

### 2. Strengthen Assertions

```rust
// Weak (mutation might survive)
assert!(result.is_ok());

// Strong (catches more mutations)
assert!(result.is_ok());
let value = result.unwrap();
assert_eq!(value.status, "success");
assert!(value.id > 0);
```

### 3. Test Error Paths

```rust
#[test]
fn test_error_handling() {
    let result = function_with_invalid_input();
    assert!(result.is_err());
    let error = result.unwrap_err();
    assert!(error.to_string().contains("expected error message"));
}
```

### 4. Test Side Effects

```rust
#[test]
fn test_side_effects() {
    let before = get_state();
    perform_operation();
    let after = get_state();
    
    assert_ne!(before, after);
    assert_eq!(after.expected_value, "new value");
}
```

## Performance Considerations

### Run Time
- Full suite: ~30-60 minutes
- Per file: ~5-10 minutes
- Quick check: ~1-2 minutes

### Optimization Tips

1. **Run in parallel**: Use `--jobs` flag
2. **Limit mutations**: Use `--max-mutations`
3. **Exclude stable code**: Use `exclude_globs`
4. **Cache results**: Reuse mutation results when possible

## Troubleshooting

### Timeout Errors

If mutations timeout:
```bash
# Increase timeout
cargo mutants --timeout 120

# Or reduce scope
cargo mutants --file src/specific_file.rs
```

### Too Many Surviving Mutants

1. Review surviving mutants in report
2. Identify patterns (e.g., all arithmetic mutations survive)
3. Add targeted tests for those patterns
4. Re-run mutation testing

### Slow Performance

1. Reduce parallel jobs if resource-constrained
2. Focus on recently changed code
3. Run incrementally during development

## Best Practices

1. **Run Weekly**: Schedule full suite weekly in CI
2. **Run on Changes**: Run quick checks on modified files
3. **Review Reports**: Investigate surviving mutants regularly
4. **Set Targets**: Maintain minimum mutation score
5. **Document Exclusions**: Justify any excluded code

## Integration with Code Review

### Pre-merge Checklist

- [ ] Run mutation tests on changed files
- [ ] No new surviving mutants introduced
- [ ] Mutation score maintained or improved
- [ ] Document any intentional exclusions

### PR Comments

Include mutation testing results in PR description:

```markdown
## Mutation Testing Results

**Files Tested**: src/sanitizer.rs, src/proxy.rs
**Mutations Generated**: 45
**Mutations Caught**: 42 (93%)
**Surviving Mutants**: 3

**Surviving Mutant Analysis**:
1. `sanitizer.rs:142` - Boundary edge case (not critical)
2. `proxy.rs:89` - Error message mutation (cosmetic)
3. `proxy.rs:156` - Timeout constant mutation (needs investigation)
```

## Resources

- [cargo-mutants Documentation](https://github.com/sourcefrog/cargo-mutants)
- [Mutation Testing Guide](https://mutationtesting.org/)
- [Effective Mutation Testing](https://www.slideshare.net/CodeShip/effective-mutation-testing)

---

**Last Updated**: 2026-03-27  
**Maintainer**: Andrew Gibson (andrew.gibson-cic@ibm.com)
