# Security Incident Report: Exposed CA Keys

## Incident Summary
**Date:** 2026-02-02  
**Severity:** CRITICAL  
**Status:** RESOLVED  
**Discovered By:** Security review  

## What Happened

Three sensitive cryptographic files were accidentally committed and pushed to the public GitHub repository in commit `75afad77bdbbef7cbb8387a3cd482898cd4349ed`:

1. `ca-data/secrets/intermediate_ca_key` - Encrypted EC private key
2. `ca-data/secrets/root_ca_key` - Encrypted EC private key  
3. `ca-data/secrets/password` - Password file

These files were committed on 2026-01-31 at 15:11:55 UTC despite having a `.gitignore` rule for `*.key` files.

## Impact Assessment

**Exposure Level:** Medium
- Keys were **encrypted** with AES-256-CBC
- Files were exposed publicly on GitHub for approximately 2 days
- Keys are used for internal CA operations in the slapenir development proxy
- No production systems affected
- No user data compromised

**Attack Vector:** An attacker would need both the encrypted key files AND the encryption password to use these keys.

## Remediation Actions Taken

### Immediate Actions (Completed 2026-02-02 09:16 UTC)

1. ✅ **Deleted exposed files from working directory**
   ```bash
   rm -f ca-data/secrets/intermediate_ca_key 
   rm -f ca-data/secrets/root_ca_key 
   rm -f ca-data/secrets/password
   ```

2. ✅ **Removed files from entire git history**
   ```bash
   git filter-repo --path ca-data/secrets/intermediate_ca_key \
                   --path ca-data/secrets/root_ca_key \
                   --path ca-data/secrets/password \
                   --invert-paths --force
   ```

3. ✅ **Force pushed cleaned history to remote**
   ```bash
   git push origin --force --all
   ```
   - Commit `75afad77` was rewritten to `7b929c5`
   - All references to secret files removed from history

4. ✅ **Updated .gitignore** 
   - Added explicit directory exclusions:
     ```
     ca-data/secrets/
     ca-data/db/
     ```

5. ✅ **Verified removal**
   ```bash
   git log --all --full-history --oneline -- ca-data/secrets/
   ```
   - Returned no results (confirmed clean)

### Required Follow-up Actions

- [ ] **Regenerate ALL CA keys** - The exposed keys must be considered compromised
  ```bash
  scripts/init-step-ca.sh
  ```

- [ ] **Rotate any certificates** signed by the exposed CAs

- [ ] **Review commit access** - Investigate how files were committed despite .gitignore

- [ ] **Add pre-commit hooks** - Prevent future secret commits
  ```bash
  # Install git-secrets or similar tool
  brew install git-secrets
  git secrets --install
  git secrets --register-aws
  ```

## Root Cause Analysis

**Why did this happen?**

1. The files may have been explicitly force-added using `git add -f`
2. The `.gitignore` pattern `*.key` should have prevented this, suggesting a forced add
3. No pre-commit scanning for secrets was in place
4. Manual oversight during commit process

**Why wasn't it caught sooner?**

- No automated secret scanning in CI/CD
- No pre-commit hooks to detect secrets
- Developer committed during active development phase

## Prevention Measures

### Implemented
1. ✅ Enhanced `.gitignore` with explicit directory exclusions
2. ✅ Documented incident for team awareness

### Recommended
1. ⚠️ Install git-secrets or similar pre-commit secret detection
2. ⚠️ Enable GitHub secret scanning (if not already enabled)
3. ⚠️ Add CI/CD pipeline check for secrets using tools like:
   - TruffleHog
   - gitleaks
   - detect-secrets
4. ⚠️ Implement mandatory code review for all commits
5. ⚠️ Create `.gitattributes` to mark sensitive directories
6. ⚠️ Regular security audits of repository

## Timeline

- **2026-01-31 15:11:55 UTC** - Files committed in `75afad77`
- **2026-01-31 15:11:55 UTC** - Files pushed to GitHub
- **2026-02-02 09:11:14 UTC** - Issue discovered during security review
- **2026-02-02 09:13:00 UTC** - Files deleted from working directory
- **2026-02-02 09:14:23 UTC** - git-filter-repo installed and executed
- **2026-02-02 09:14:55 UTC** - Cleaned history force-pushed to remote
- **2026-02-02 09:16:14 UTC** - .gitignore updated, incident documented

**Total exposure time:** ~2 days  
**Remediation time:** ~5 minutes

## Lessons Learned

1. **Encrypted keys are still secrets** - Even encrypted keys should never be in version control
2. **Defense in depth** - Multiple layers needed: .gitignore, pre-commit hooks, secret scanning
3. **Quick response matters** - Rapid remediation limited exposure window
4. **git-filter-repo is essential** - Standard tool for removing secrets from history

## References

- Original commit: https://github.com/andrewgibson-cic/slapenir/commit/75afad77bdbbef7cbb8387a3cd482898cd4349ed
- git-filter-repo: https://github.com/newren/git-filter-repo
- GitHub secret scanning: https://docs.github.com/en/code-security/secret-scanning

---

**Incident Status:** RESOLVED - History cleaned, secrets removed, .gitignore updated  
**Next Action Required:** Regenerate all CA keys and certificates