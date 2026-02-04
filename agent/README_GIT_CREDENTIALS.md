# Git Credentials in SLAPENIR Agent

This document explains how Git authentication is configured in the SLAPENIR agent container using **Personal Access Tokens (PATs)** for secure, production-ready Git operations.

## Overview

The SLAPENIR agent uses **GitHub Personal Access Tokens (PATs) via proxy injection** for secure, zero-trust Git operations. This approach provides:

- ✅ **Zero-trust architecture** (agent never sees real credentials)
- ✅ **Fine-grained permissions** (scoped to specific repositories and operations)
- ✅ **Easy revocation** (instant token invalidation)
- ✅ **Simple rotation** (update environment variable in proxy only)
- ✅ **Audit trail** (GitHub tracks all token usage, proxy logs all requests)
- ✅ **Container-friendly** (dummy credentials in agent, real ones in proxy)

## Architecture: Proxy-Based Credential Injection

### How It Works

1. **Agent** uses dummy token (`DUMMY_GITHUB_TOKEN`)
2. **Proxy** intercepts the request
3. **Proxy** replaces dummy token with real `GITHUB_TOKEN`
4. **GitHub** receives authenticated request with real token
5. **Proxy** forwards response back to agent

This ensures the agent **never has access to real credentials**.

### Why Proxy Injection vs Direct Authentication?

| Aspect | Direct PAT (Old) | Proxy Injection (Current) |
|--------|------------------|---------------------------|
| Credential exposure | Agent has real token | Agent only has dummy |
| Security model | Single point of failure | Zero-trust architecture |
| Token rotation | Update agent env | Update proxy only |
| Audit trail | Git logs only | Proxy + Git logs |
| Breach impact | Full token exposure | Dummy token only |
| Compliance | Single-tier | Defense-in-depth |

## Architecture

### Components

1. **`git-credential-helper.sh`** - Provides credentials to Git from environment variables
2. **`setup-git-credentials.sh`** - Configures Git at container startup
3. **S6 oneshot service (`git-init`)** - Runs setup script before agent starts
4. **Environment variables** - Injects PAT securely at runtime

### Flow

```
Container Start
    ↓
S6-Overlay Init
    ↓
git-init service runs
    ↓
setup-git-credentials.sh executes
    ↓
- Validates GITHUB_TOKEN
- Configures Git credential helper
- Sets user identity
- Validates token with GitHub API
    ↓
Agent service starts
    ↓
Git operations use PAT transparently
```

## Setup Instructions

### 1. Generate GitHub Personal Access Token

1. Go to [GitHub Settings → Tokens (Fine-grained)](https://github.com/settings/tokens?type=beta)
2. Click **"Generate new token (fine-grained)"**
3. Configure:
   - **Token name**: `slapenir-agent-token`
   - **Expiration**: 90 days (recommended)
   - **Repository access**: Select specific repositories
   - **Permissions**:
     - ✅ Contents: **Read and Write** (for clone/pull/push)
     - ✅ Meta **Read** (required)
     - ✅ Pull requests: **Read and Write** (optional)
     - ✅ Workflows: **Read and Write** (if managing Actions)
4. Click **"Generate token"** and copy it immediately

### 2. Configure Environment Variables

Add to your `.env` file:

```bash
# GitHub Personal Access Token for Git operations
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx

# Git user identity (for commits)
GIT_USER_NAME=SLAPENIR Agent
GIT_USER_EMAIL=agent@slapenir.local

# Automatically convert SSH URLs to HTTPS
GIT_CONVERT_SSH_TO_HTTPS=true

# Validate token at startup
VALIDATE_GITHUB_TOKEN=true
```

### 3. Build and Start Container

```bash
# Rebuild agent container to include new scripts
docker-compose build agent

# Start services
docker-compose up -d

# Check logs to verify Git configuration
docker-compose logs agent | grep -A 10 "Configuring Git credentials"
```

Expected output:
```
🔧 Configuring Git credentials for SLAPENIR Agent...
📝 Setting up credential helper...
✅ Git identity configured: SLAPENIR Agent <agent@slapenir.local>
✅ SSH to HTTPS conversion enabled
🔍 Validating GitHub token...
✅ GitHub token valid (authenticated as: your-username)
✅ Git credentials configured successfully
🚀 Ready for Git operations (clone, pull, push, etc.)
```

## Usage Examples

Once configured, all Git operations work transparently:

### Clone a Repository

```bash
# SSH URL automatically converts to HTTPS
git clone git@github.com:user/repo.git

# Or use HTTPS directly
git clone https://github.com/user/repo.git
```

### Make Changes and Push

```bash
cd repo
echo "test" > file.txt
git add file.txt
git commit -m "Test commit"
git push origin main  # Uses PAT automatically
```

### Pull Latest Changes

```bash
git pull origin main  # Uses PAT automatically
```

### Multiple Repositories

```bash
# Clone multiple repos - all use the same PAT
git clone https://github.com/user/repo1.git
git clone https://github.com/user/repo2.git
git clone https://github.com/user/repo3.git
```

## Security Best Practices

### Token Management

1. **Use Fine-Grained PATs** - Never use classic tokens
2. **Minimum Permissions** - Only grant required access
3. **Short Expiration** - Set 90-day max expiration
4. **Regular Rotation** - Rotate tokens quarterly
5. **Environment Variables** - Never hardcode in Dockerfile

### Token Storage

```yaml
# ✅ GOOD: Environment variable (runtime injection)
environment:
  - GITHUB_TOKEN=${GITHUB_TOKEN}

# ❌ BAD: Hardcoded in docker-compose.yml
environment:
  - GITHUB_TOKEN=ghp_hardcoded_token_here

# ❌ BAD: Build-time ARG in Dockerfile
ARG GITHUB_TOKEN
RUN git clone https://${GITHUB_TOKEN}@github.com/repo.git
```

### Credential Validation

The setup script validates your token at startup:

```bash
# Successful validation
✅ GitHub token valid (authenticated as: username)

# Failed validation
❌ GitHub token validation failed (HTTP 401)
   Token may be expired or have insufficient permissions
```

### Audit Logging

Monitor token usage via GitHub:
1. Go to [Settings → Personal Access Tokens](https://github.com/settings/tokens)
2. Click on your token
3. View **"Recent Activity"** for audit trail

## Troubleshooting

### Token Not Working

**Symptoms:**
```
remote: Support for password authentication was removed
fatal: Authentication failed
```

**Solution:**
1. Verify `GITHUB_TOKEN` is set: `docker exec slapenir-agent env | grep GITHUB_TOKEN`
2. Check token hasn't expired on GitHub
3. Ensure token has correct permissions (Contents: Read & Write)

### Token Validation Fails

**Symptoms:**
```
❌ GitHub token validation failed (HTTP 401)
```

**Solution:**
1. Verify token format: `ghp_`, `gho_`, `ghu_`, `ghs_`, or `ghr_` prefix
2. Check token isn't expired: [GitHub Tokens](https://github.com/settings/tokens)
3. Regenerate token if necessary

### SSH URLs Not Converting

**Symptoms:**
```
git@github.com: Permission denied (publickey)
```

**Solution:**
1. Ensure `GIT_CONVERT_SSH_TO_HTTPS=true` in `.env`
2. Check Git config: `docker exec slapenir-agent git config --get url.https://github.com/.insteadof`
3. Should return: `git@github.com:`

### Commits Showing Wrong Author

**Symptoms:**
```
Author: root <root@localhost>
```

**Solution:**
1. Set `GIT_USER_NAME` and `GIT_USER_EMAIL` in `.env`
2. Verify: `docker exec slapenir-agent git config --get user.name`

## Token Rotation Procedure

When your token expires or needs rotation:

```bash
# 1. Generate new token on GitHub
# 2. Update .env file with new token
GITHUB_TOKEN=ghp_new_token_here

# 3. Restart agent container (no rebuild needed!)
docker-compose restart agent

# 4. Verify new token works
docker-compose logs agent | grep "GitHub token valid"
```

**No rebuild required!** Tokens are injected at runtime.

## Advanced Configuration

### Disable Token Validation

If GitHub API access is blocked:

```bash
VALIDATE_GITHUB_TOKEN=false
```

### Keep SSH URLs as SSH

If you prefer SSH (not recommended):

```bash
GIT_CONVERT_SSH_TO_HTTPS=false
```

### Custom Git Configuration

Add to `setup-git-credentials.sh`:

```bash
# Example: Enable credential caching
git config --global credential.helper 'cache --timeout=3600'

# Example: Configure diff algorithm
git config --global diff.algorithm histogram
```

## Alternative: Deploy Keys (Not Recommended)

If you **must** use SSH deploy keys:

```yaml
# docker-compose.yml
services:
  agent:
    volumes:
      - ./secrets/deploy_key:/home/agent/.ssh/id_rsa:ro
    environment:
      - GIT_SSH_COMMAND=ssh -i /home/agent/.ssh/id_rsa -o StrictHostKeyChecking=no
```

**Why not recommended:**
- ⚠️ One key per repository
- ⚠️ Complex key management
- ⚠️ Harder to rotate
- ⚠️ Less auditable

## References

- [GitHub PAT Documentation](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens)
- [Git Credential Helpers](https://git-scm.com/docs/gitcredentials)
- [Docker Secrets Best Practices](https://docs.docker.com/engine/swarm/secrets/)

## Support

For issues or questions:
1. Check container logs: `docker-compose logs agent`
2. Verify configuration: `docker exec slapenir-agent git config --list`
3. Test manually: `docker exec -it slapenir-agent bash`