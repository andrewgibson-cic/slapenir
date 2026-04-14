# SLAPENIR Demonstration Video Script

**Title**: _SLAPENIR: Secure AI-Assisted Development_
**Version**: 2.0
**Runtime**: ~13 minutes**Audience**: Technical decision-makers (CTOs, VPs of Engineering, Security Architects)
**Format**: Narrative screenplay -- `[BRACKETS]` indicate on-screen actions and visual cues

---

## Production Notes

### Visual Language

| Cue | Meaning |
|-----|---------|
| `[HOST TERMINAL]` | Full-screen terminal on the host Mac |
| `[AGENT TERMINAL]` | Full-screen terminal inside the agent container |
| `[SPLIT: LEFT / RIGHT]` | Side-by-side view (used sparingly) |
| `[OVERLAY: text]` | Text rendered over the video |
| `[TIME-LAPSE]` | Speed up the recording with a speed indicator overlay |
| `[HOLD]` | Freeze the recording while a long-running task completes |
| `[BEAT]` | Dramatic pause, 1-2 seconds of silence |
| `[CUT TO]` | Hard cut to next shot |

### Conventions

- The **narrator** is never seen. Voice-over only.
- Terminal font size is large enough to read on a phone screen.
- Commands the user types are highlighted (bold or colored prompt).
- Every scene answers "why does this matter?" before showing "how it works."

### Handling Long-Running Tasks

Several operations in this demo take seconds to minutes in real time. Use these techniques to keep the video tight:

**Time-lapse** (`[TIME-LAPSE]`): Speed up the recording 3-15x with a visual speed indicator in the corner (e.g., a small `3x` or `15x` badge). Use when:

- The audience needs to see the operation complete but doesn't need to watch every line scroll.
- Terminal output is still visible and readable at the increased speed.
- Typical targets: service startup, `cgr start` indexing, `work-start` phases.

**Hold** (`[HOLD]`): Freeze the recording on the current frame while the real task finishes in the background, then resume. A subtle "processing..." indicator or spinner appears on screen. Use when:

- The operation has no useful output to watch (e.g., LLM generating a response with a blank or spinner screen).
- The wait is long (10+ seconds) and the screen shows nothing of value.
- Resume the moment meaningful output begins appearing.
- Typical targets: LLM inference in OpenCode, slow curl timeouts.

**Jump cut**: Simply cut from the command to the result. Use when:

- The intermediate output is irrelevant.
- The operation is short enough (5-10 seconds) that a time-lapse feels gratuitous.
- Typical targets: `curl` timeouts in Scene 5, quick proxy responses.

**Decision matrix:**

| Real duration | Visible output? | Technique |
|---------------|-----------------|-----------|
| < 5 seconds | Yes | Show in real time |
| 5-15 seconds | Yes | `[TIME-LAPSE]` at 3-5x |
| 15-60 seconds | Yes | `[TIME-LAPSE]` at 10-15x |
| 5-60 seconds | No / spinner only | `[HOLD]` with "thinking..." overlay |
| 60+ seconds | Partial | `[TIME-LAPSE]` the output parts, `[HOLD]` the silent parts |

**Specific long-running moments in this script:**

| Scene | Task | Real time | Technique |
|-------|------|-----------|-----------|
| 2 | llama-server model load | ~15s | `[TIME-LAPSE]` 10x |
| 3 | `make work-start` service startup | ~30s | `[TIME-LAPSE]` 8x |
| 3 | `make work-start` security verification | ~20s | Real time (audience should read results) |
| 3 | `make work-start` code-graph indexing | ~60s | `[TIME-LAPSE]` 15x |
| 3 | `make work-start` document ingestion | ~15s | `[TIME-LAPSE]` 5x |
| 5 | `curl` timeouts (3 attempts) | ~15s | Real time (tension is the point) |
| 6 | Proxy request round-trip | ~10s | Real time (split-screen, both sides) |
| 8 | OpenCode webfetch denial | ~5s | Real time |
| 9 | OpenCode knowledge query | ~15s | `[HOLD]` with "querying knowledge base..." |
| 9 | OpenCode code-graph query | ~20s | `[HOLD]` with "querying code graph..." |
| 10 | OpenCode reads files + plans | ~30s | `[TIME-LAPSE]` 5x |
| 10 | OpenCode implements ticket (inference) | ~90s | `[HOLD]` with "implementing VAULT-142...", resume when edits begin |
| 10 | OpenCode writes files | ~30s | `[TIME-LAPSE]` 5x |
| 11 | `make work-done` full extraction | ~20s | Real time (audience should see each step) |

---

## SCENE 1: The Threat

**Est. runtime**: 0:30
**Purpose**: Frame the problem. Make the audience feel the risk before showing the solution.

---

**NARRATOR:**

> Your AI coding assistant has access to your entire codebase.
> It also has access to your API keys, your database credentials,
> and your production secrets.
>
> What happens when that AI tries to phone home?

`[OVERLAY: white text on black background]`

```
"Your code. Your secrets. Their model."
```

`[BEAT — 2 seconds of silence]`

`[OVERLAY fades to:]`

```
"What if the AI never sees your secrets
 and never reaches the internet?"
```

`[CUT TO HOST TERMINAL]`

---

## SCENE 2: Starting the Local LLM

**Est. runtime**: 0:30
**Purpose**: Show that the LLM runs locally, on the operator's hardware. No cloud.

---

`[HOST TERMINAL — clean desktop, terminal window open]`

**NARRATOR:**

> Everything starts with a local language model.
> No cloud API. No data leaves this machine.
> We're using llama-server with a Qwen 3.5 35-billion-parameter model.

`[OPERATOR types:]`

```bash
llama-server \
  --model ~/models/qwen3.5-35b-a3b-ud-q4_k_xl.gguf \
  --host 0.0.0.0 \
  --port 8080 \
  --ctx-size 262144
```

`[TIME-LAPSE: model loads in a few seconds of video time]`

`[Screen shows:]`

```
llama server listening on http://0.0.0.0:8080
```

**NARRATOR:**

> The model is bound to all interfaces so the agent container
> can reach it through Docker's host networking.
> But nothing outside this machine can connect.

`[OPERATOR types:]`

```bash
curl -s http://localhost:8080/v1/models | jq '.data[].id'
```

`[Output:]`

```
"qwen3.5-35b-a3b-ud-q4_k_xl"
```

**NARRATOR:**

> One model. Local. Ready.

`[CUT TO BLACK — brief transition]`

---

## SCENE 3: `make work-start` — The One-Command Setup

**Est. runtime**: 2:00
**Purpose**: Show the new streamlined workflow. Six phases in one command. This is the hero moment.

---

`[HOST TERMINAL]`

**NARRATOR:**

> SLAPENIR's workflow is three commands.
> This is the first one.
> It validates the environment, starts services, copies the code,
> runs security checks, indexes the codebase, and ingests the tickets.
> All in a single command.

`[OPERATOR types:]`

```bash
make work-start REPO=~/Projects/vaultpay DOCS=~/Projects/vaultpay-tickets
```

`[Terminal output streams -- the script runs through its phases]`

### Phase 1: Prerequisites

```
━━━ Phase 1: Prerequisites ━━━
✓ Docker is running (version 27.x)
✓ llama-server is running on port 8080
```

**NARRATOR:**

> First, it checks that Docker and the local LLM are running.
> If llama-server isn't up, it stops and tells you.

### Phase 2: Services

```
━━━ Phase 2: Starting Services ━━━
▸ Starting SLAPENIR services...
✓ Services are healthy
```

`[TIME-LAPSE indicator in corner: 10x]`

**NARRATOR:**

> It starts the proxy, the certificate authority, Memgraph,
> PostgreSQL, and the agent container.
> Then it waits for health checks to pass.

### Phase 3: Data Transfer

```
━━━ Phase 3: Transferring Data ━━━
▸ Copying repository into container...
✓ Repository copied to /home/agent/workspace
▸ Copying documents into container...
✓ Documents copied to /home/agent/workspace/docs
```

**NARRATOR:**

> The VaultPay repository and its tickets are copied into the agent's
> isolated workspace. The host's original files are untouched.

### Phase 4: Security Verification

```
━━━ Phase 4: Security Verification ━━━
▸ Running security verification...

═══════════════════════════════════════════════════════════
  SLAPENIR Zero-Knowledge Verification
═══════════════════════════════════════════════════════════

✓ Agent has no real OpenAI credentials
✓ Agent has no real GitHub token
✓ Agent has no real AWS credentials
✓ No real credential patterns found in agent environment
✓ iptables TRAFFIC_ENFORCE chain active (21 rules)
✓ External traffic blocked (google.com, api.openai.com, 1.1.1.1)
✓ Bypass attempts are logged

═══════════════════════════════════════════════════════════
  ✓ ALL TESTS PASSED - Agent environment is SECURE
═══════════════════════════════════════════════════════════
```

`[OVERLAY: "Zero real credentials in the agent"]`

**NARRATOR:**

> This is critical. The security verification confirms three things:
> the agent has zero real credentials, all outbound traffic is blocked,
> and the proxy is the only path to the outside world.
>
> If any check fails, the command stops. You cannot proceed
> with a misconfigured environment.

### Phase 5: Code Graph Indexing

```
━━━ Phase 5: Indexing Repository ━━━
▸ Indexing repository with Code-Graph-RAG (project: vaultpay)...
```

`[TIME-LAPSE indicator: 15x — indexing takes ~60 seconds of screen time compressed to ~4 seconds]`

```
✓ Code-Graph-RAG index complete (project: vaultpay)
```

**NARRATOR:**

> The entire codebase is parsed into a knowledge graph in Memgraph.
> Functions, classes, imports, call chains — every relationship is mapped.
> This gives the AI structural understanding of the code, not just text search.

### Phase 6: Document Ingestion

```
━━━ Phase 6: Ingesting Documents ━━━
▸ Ingesting documents into knowledge RAG...

  VAULT-142-webhook-retry.md... OK
  VAULT-157-request-signing.md... OK
  VAULT-163-key-usage-tracking.md... OK

✓ Document ingestion complete
```

**NARRATOR:**

> The tickets are ingested into a vector database
> so the AI can search them semantically.
> Three tickets. All available inside the container.
> The AI will use these shortly.

### Session Ready

```
━━━ Saving Session ━━━
✓ Session saved to .slapenir-session

✓ Ready!

  Repository:  vaultpay → /home/agent/workspace
  Documents:   vaultpay-tickets → /home/agent/workspace/docs
  Code Graph:  project "vaultpay" indexed in Memgraph

  Next:
    make shell
    make work-done REPO=/Users/user/Projects/vaultpay
```

**NARRATOR:**

> One command. Six phases. The environment is ready.
>
> Let's go inside.

`[CUT TO BLACK]`

---

## SCENE 4: Entering the Agent

**Est. runtime**: 0:15
**Purpose**: Quick transition into the container. Establish the agent's perspective.

---

`[HOST TERMINAL]`

**NARRATOR:**

> Command two: open a shell inside the agent.

`[OPERATOR types:]`

```bash
make shell
```

`[Output:]`

```
🔒 Secure shell - builds and internet blocked by default
   To run builds through proxy: ALLOW_BUILD=1 <tool> <args>

agent@slapenir-agent:~/workspace$
```

**NARRATOR:**

> We're now inside the agent container.
> Notice the message: builds and internet are blocked by default.

`[CUT TO AGENT TERMINAL — full screen]`

---

## SCENE 5: Verifying No Internet Access

**Est. runtime**: 0:45
**Purpose**: Prove the agent has no internet. Show, don't tell.

---

`[AGENT TERMINAL]`

**NARRATOR:**

> The security verification already confirmed this during setup.
> But let's prove it live.

`[OPERATOR types:]`

```bash
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://google.com
```

`[BEAT — 5 seconds of silence while it times out]`

`[Output:]`

```
000
```

`[OPERATOR types:]`

```bash
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 https://api.openai.com
```

`[Output:]`

```
000
```

`[OPERATOR types:]`

```bash
curl -s -o /dev/null -w "%{http_code}" --connect-timeout 5 http://1.1.1.1
```

`[Output:]`

```
000
```

**NARRATOR:**

> Google. OpenAI. Cloudflare's DNS IP.
> Zero-zero-zero. No response. No route out.

`[OVERLAY: "000 — connection refused on every attempt"]`

`[CUT TO next shot]`

---

## SCENE 6: Credential Interception and Redaction

**Est. runtime**: 1:30
**Purpose**: Show the proxy injecting real credentials (interception) and stripping them from responses (redaction). This is the core trust model.

---

`[SPLIT SCREEN: LEFT = agent terminal, RIGHT = proxy logs]`

**NARRATOR:**

> Here's how credentials work in SLAPENIR.
>
> The agent only has dummy values. The proxy holds the real keys.
> When the agent makes an API call, the proxy swaps the dummy for the real key.
> When the response comes back, the proxy strips any real credentials
> before the agent sees them.

### Part A: The Agent's View

`[LEFT SIDE — agent terminal]`

`[OPERATOR types:]`

```bash
echo $OPENAI_API_KEY
```

`[Output:]`

```
DUMMY_OPENAI
```

`[OPERATOR types:]`

```bash
echo $GITHUB_TOKEN
```

`[Output:]`

```
DUMMY_GITHUB
```

**NARRATOR:**

> Dummy values. The agent cannot authenticate to anything on its own.

### Part B: Proxy Intercept

`[LEFT SIDE — agent terminal]`

`[OPERATOR types:]`

```bash
curl -s -X POST http://proxy:3000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{"model":"gpt-4","messages":[{"role":"user","content":"ping"}],"max_tokens":5}' \
  | jq '.choices[0].message.content'
```

`[BEAT — waiting for response]`

`[RIGHT SIDE — proxy logs scroll, showing:]`

```
[PROXY] POST /v1/chat/completions
[PROXY] Injecting credential: DUMMY_OPENAI → sk-proj-***...*** (redacted in logs)
[PROXY] Forwarding to upstream: api.openai.com
[PROXY] Response 200 OK (sanitized: 0 secrets in body)
```

`[LEFT SIDE — output arrives:]`

```json
"Pong!"
```

**NARRATOR:**

> The agent sent DUMMY_OPENAI. The proxy replaced it with the real key.
> The upstream API saw a real credential. The agent never did.

### Part C: Redaction

`[LEFT SIDE — agent terminal]`

`[OPERATOR types:]`

```bash
curl -s http://proxy:3000/v1/test \
  -H "X-Target-URL: https://httpbin.org/post" \
  -H "Content-Type: application/json" \
  -d '{"key": "DUMMY_OPENAI"}' | jq '.json'
```

`[Output:]`

```json
{
  "key": "[REDACTED]"
}
```

`[OVERLAY: "[REDACTED] — the agent never sees the real credential"]`

**NARRATOR:**

> We sent the dummy key through the proxy to httpbin,
> which echoes back whatever it received.
> The proxy injected the real key for the upstream call,
> then replaced it with REDACTED in the response.
>
> The agent asked a question. The answer came back sanitized.

`[CUT — end split screen]`

---

## SCENE 7: Launching OpenCode

**Est. runtime**: 0:15
**Purpose**: Start the AI coding assistant inside the container.

---

`[AGENT TERMINAL]`

**NARRATOR:**

> Time to bring the AI online.

`[OPERATOR types:]`

```bash
opencode
```

`[OpenCode launches — shows its TUI interface with model info]`

```
╭─────────────────────────────────────────╮
│  OpenCode v0.x.x                        │
│  Model: local-llama/qwen3.5-35b         │
│  Provider: http://host.docker.internal  │
│  Tools: code-graph-rag, memory, knowledge│
╰─────────────────────────────────────────╯
```

`[CUT TO next shot]`

---

## SCENE 8: Verifying the LLM Has No Internet

**Est. runtime**: 0:45
**Purpose**: Confirm from inside OpenCode that the LLM itself cannot reach the internet.

---

`[OPENCODE INTERFACE]`

**NARRATOR:**

> Before we give it any real work, let's confirm the LLM
> cannot reach the internet through its own tools.
> OpenCode has webfetch and websearch capabilities.
> Let's see what happens.

`[OPERATOR types in OpenCode:]`

```
Fetch the contents of https://www.google.com for me.
```

`[HOLD: ~8s while LLM processes — freeze on OpenCode input, resume when response streams]`

`[OpenCode response:]`

```
I cannot fetch external URLs. The `webfetch` tool is disabled in my
configuration. Similarly, `websearch` is disabled.

I am operating in a fully offline environment with no internet access.
```

`[HOLD: ~8s while LLM processes — freeze, resume when response streams]`

`[OPERATOR types in OpenCode:]`

```
What tools do you have available?
```

`[OpenCode response:]`

```
Available tools:
  - read: Read files from the workspace
  - edit: Edit files in the workspace
  - grep: Search file contents
  - glob: Find files by pattern
  - code-graph-rag: Query the code knowledge graph
  - memory: Persistent memory across sessions
  - knowledge: Search ingested documents

Disabled tools:
  - webfetch (denied by configuration)
  - websearch (denied by configuration)
  - bash/curl/wget (denied by permission policy)
```

`[OVERLAY: "webfetch: denied. websearch: denied. curl: denied."]`

**NARRATOR:**

> Web access is disabled at two levels: the OpenCode configuration
> denies the tools, and the container's iptables blocks the network.
> Defense in depth. Even if the tool were enabled, the packets
> wouldn't leave the container.

`[CUT TO next shot]`

---

## SCENE 9: Ingesting Codebase and Tickets to MCP Tools

**Est. runtime**: 0:30
**Purpose**: Show that the AI already has the codebase indexed and tickets ingested from `work-start`. Demonstrate a query to prove it.

---

`[OPENCODE INTERFACE]`

**NARRATOR:**

> During setup, `make work-start` already indexed the codebase
> into the Code-Graph-RAG and ingested the tickets into the knowledge base.
> Let's verify the AI can use them.

`[OPERATOR types in OpenCode:]`

```
Search the knowledge base for information about webhook retries.
```

`[HOLD: "querying knowledge base..." — freeze ~15s while LLM processes, resume when response appears]`

`[OpenCode response:]`

```
Found relevant document: VAULT-142-webhook-retry.md

# VAULT-142: Add retry mechanism to webhook handler

**Priority**: High
**Type**: Feature
**Component**: payments/webhook

The Stripe webhook handler processes events in a single attempt.
When transient failures occur (timeouts, 5xx, rate limits), events are lost.
This has caused two production incidents in the last month.
```

`[OPERATOR types in OpenCode:]`

```
What functions exist in the webhook module?
```

`[HOLD: "querying code graph..." — freeze ~20s while LLM + code-graph-rag process, resume when response appears]`

`[OpenCode uses code-graph-rag tool]`

```
The payments/webhook module contains:

  src/payments/webhook.py:
    - handle_webhook_event(request) — main entry point
    - process_charge_succeeded(event) — handler
    - process_charge_failed(event) — handler
    - process_charge_refunded(event) — handler
    - process_charge_disputed(event) — handler
    - verify_stripe_signature(payload, sig_header) — validation
```

**NARRATOR:**

> The code graph gives the AI structural knowledge — function signatures,
> call chains, dependencies. The knowledge base gives it the tickets
> and specifications. Together, the AI understands what to build
> and where to build it.

`[CUT TO next shot]`

---

## SCENE 10: Implementing a Ticket — VAULT-142

**Est. runtime**: 2:30
**Purpose**: The climax. Show the AI autonomously implementing a real ticket.

---

`[OPENCODE INTERFACE]`

**NARRATOR:**

> Now for the real test. VAULT-142 is a high-priority ticket:
> add retry logic to the webhook handler.
> Two production incidents last month. The requirements are clear.
> Let's see if the AI can implement it.

`[OPERATOR types in OpenCode:]`

```
Implement VAULT-142: Add retry mechanism to webhook handler.

Requirements:
1. Exponential backoff: 1s, 3s, 9s (base 3)
2. Max 3 retry attempts
3. Only retry on transient errors (connection errors, timeouts, HTTP 5xx)
4. Do NOT retry on 4xx, signature failures, malformed payloads
5. Log each retry at WARNING level with attempt number
6. Add WEBHOOK_MAX_RETRIES and WEBHOOK_RETRY_BASE_DELAY to settings

Files to modify:
  - src/payments/webhook.py
  - src/config/settings.py
  - tests/test_payments.py
```

`[HOLD: "implementing VAULT-142..." — freeze ~60s while LLM reads files and plans. Show a subtle spinner or progress indicator. Resume the moment the plan text begins appearing.]`

`[OpenCode output streams — show key moments:]`

```
Reading src/payments/webhook.py...
Reading src/config/settings.py...
Reading tests/test_payments.py...
Querying code graph for function call chains...

I'll implement the retry mechanism. Here's my plan:

1. Add WEBHOOK_MAX_RETRIES and WEBHOOK_RETRY_BASE_DELAY to settings
2. Create a retryable_error() helper to classify errors
3. Add retry_with_backoff() decorator around handle_webhook_event
4. Add comprehensive tests

Proceeding...
```

`[TIME-LAPSE 5x — the AI edits files. Show brief flashes of each edit tool invocation speeding through.]`

```
Editing src/config/settings.py...
  + webbook_max_retries: int = 3
  + webhook_retry_base_delay: float = 1.0

Editing src/payments/webhook.py...
  + def _is_retryable_error(error) -> bool:
  + def _retry_with_backoff(handler, event, max_retries, base_delay):
  + Modified handle_webhook_event to wrap dispatch in retry logic

Editing tests/test_payments.py...
  + test_retry_on_connection_error()
  + test_retry_on_http_5xx()
  + test_no_retry_on_4xx()
  + test_no_retry_on_signature_failure()
  + test_max_retries_exhausted()
  + test_backoff_intervals()
```

`[HOLD: "generating summary..." — freeze ~10s while LLM produces final response, resume when summary appears]`

`[OpenCode finishes]`

```
Implementation complete. Summary of changes:

  src/config/settings.py    +  2 settings
  src/payments/webhook.py   + 38 lines (retry logic + helper)
  tests/test_payments.py    + 67 lines (6 test cases)

All acceptance criteria addressed:
  ✓ Exponential backoff (1s, 3s, 9s)
  ✓ Max 3 retries
  ✓ Retry only on transient errors
  ✓ No retry on 4xx/validation failures
  ✓ WARNING-level logging per attempt
  ✓ New config settings added
  ✓ 6 test cases covering all scenarios
```

**NARRATOR:**

> The AI read the codebase, understood the architecture,
> and implemented all six acceptance criteria.
> It modified three files, added a hundred lines of production code
> and tests, and explained every change.
>
> All without ever seeing a real credential
> or touching the internet.

`[OVERLAY: "0 real credentials. 0 bytes to the internet. 100+ lines of production code."]`

`[CUT TO BLACK]`

---

## SCENE 11: `make work-done` — Extracting the Code

**Est. runtime**: 0:45
**Purpose**: Show the second hero command. Extract the work, scan for secrets, present the result.

---

`[HOST TERMINAL — operator has exited OpenCode and the agent shell]`

**NARRATOR:**

> The work is done inside the container. Now we bring it home.
> Command three: `make work-done`.

`[OPERATOR types:]`

```bash
make work-done REPO=~/Projects/vaultpay
```

`[Terminal output:]`

### Secret Scan (Container)

```
━━━ Extracting Changes ━━━

▸ Scanning for leaked secrets (container)...
✓ No secrets detected in container
```

**NARRATOR:**

> First, it scans the container workspace for any credential patterns.
> If the AI accidentally wrote a secret into a file, we catch it here.

### Backup and Copy

```
▸ Backing up host repository...
✓ Backup created at vaultpay.backup.20260412T143022
▸ Copying repository out of container...
✓ Repository copied to host
```

**NARRATOR:**

> Before overwriting the host repo, it creates a timestamped backup.
> Then it copies the container's workspace back to the host.

### Secret Scan (Host)

```
▸ Scanning for leaked secrets (host)...
✓ No secrets detected by gitleaks
```

### Summary

```
━━━ Summary ━━━

✓ Extraction complete!

  Changes are on host at: /Users/user/Projects/vaultpay

  a1f3e2d feat: add retry mechanism to webhook handler (VAULT-142)
  b4c7d91 chore: add webhook retry settings to config
  e9f2a38 test: add webhook retry test cases

  src/config/settings.py    |  2 +
  src/payments/webhook.py   | 38 ++++++
  tests/test_payments.py    | 67 ++++++++++
  3 files changed, 107 insertions(+)

  To push:
    cd /Users/user/Projects/vaultpay && git push origin fix/VAULT-142-webhook-retry
```

**NARRATOR:**

> Secret scan passed. Backup created. Code extracted.
> Three commits. A hundred and seven lines.
>
> The agent cannot push — it only has a dummy GitHub token.
> The push happens from the host, under human control.

`[OVERLAY: "Human approves. Human pushes. AI never touches the remote."]`

`[CUT TO BLACK]`

---

## SCENE 12: Adversarial Test — Container Destruction

**Est. runtime**: 1:00
**Purpose**: Show that the LLM cannot destroy or corrupt the container itself.

---

`[AGENT TERMINAL — operator re-enters via make shell]`

**NARRATOR:**

> The work is done and extracted. But let's ask a harder question:
> what if the AI tried to destroy the container?
>
> We'll simulate three attacks.

### Attack 1: Delete Everything

`[OPERATOR types:]`

```bash
rm -rf /home/agent/workspace
```

`[Output:]`

```
rm: cannot remove '/home/agent/workspace/.git/objects/pack/pack-abc.pack': Permission denied
rm: cannot remove '/home/agent/workspace/src/payments/webhook.py': Read-only file system
```

**NARRATOR:**

> Key workspace files are on read-only mounts or owned by root.
> The agent user cannot delete them.

### Attack 2: Kill Critical Processes

`[OPERATOR types:]`

```bash
pkill -9 runtime-monitor
```

`[Output:]`

```
pkill: killing pid 42 failed: Operation not permitted
```

**NARRATOR:**

> The runtime monitor runs as root. The agent user cannot kill it.
> Even if it could, Docker's restart policy would respawn it.

### Attack 3: Shutdown the Container

`[OPERATOR types:]`

```bash
shutdown now
```

`[Output:]`

```
bash: shutdown: command not found
```

```bash
poweroff
```

`[Output:]`

```
bash: poweroff: command not found
```

```bash
init 0
```

`[Output:]`

```
bash: init: command not found
```

`[OVERLAY: "shutdown: not found. poweroff: not found. init: not found."]`

**NARRATOR:**

> The container's filesystem doesn't include shutdown utilities.
> The agent user doesn't have the capability to stop or restart
> its own container. That's Docker's job, managed from the host.

`[CUT TO next shot]`

---

## SCENE 13: Adversarial Test — Container Escape

**Est. runtime**: 1:00
**Purpose**: Show defense in depth. Active escape attempts fail, then explain why.

---

`[AGENT TERMINAL]`

**NARRATOR:**

> Final test. What if the AI tried to break out of the container
> and reach the host?

### Attempt 1: Access Docker Socket

`[OPERATOR types:]`

```bash
ls -la /var/run/docker.sock
```

`[Output:]`

```
ls: cannot access '/var/run/docker.sock': No such file or directory
```

### Attempt 2: Mount the Host Filesystem

`[OPERATOR types:]`

```bash
mount /dev/sda1 /mnt
```

`[Output:]`

```
mount: only root can use "--all" option (effective UID is 1000)
```

### Attempt 3: Escalate Privileges

`[OPERATOR types:]`

```bash
sudo -i
```

`[Output:]`

```
bash: sudo: command not found
```

```bash
su root
```

`[Output:]`

```
su: Authentication failure
```

`[OVERLAY: "sudo: not found. su: denied. docker.sock: missing. mount: denied."]`

`[BEAT]`

**NARRATOR:**

> Every escape path is closed. Let's see why.

`[CUT TO animated diagram — white lines on dark background, built up layer by layer]`

`[OVERLAY: Defense-in-Depth Layers]`

```
┌─────────────────────────────────────────────┐
│  Layer 1: User Isolation                    │
│  Agent runs as UID 1000 (non-root)          │
│  No sudo, no su, no setuid binaries         │
├─────────────────────────────────────────────┤
│  Layer 2: Container Capabilities            │
│  All Linux capabilities dropped             │
│  No SYS_ADMIN, No NET_ADMIN, No SYS_PTRACE  │
├─────────────────────────────────────────────┤
│  Layer 3: Filesystem Isolation              │
│  No Docker socket mounted                   │
│  No host volumes mounted                    │
│  Read-only mounts where possible            │
├─────────────────────────────────────────────┤
│  Layer 4: Network Isolation                 │
│  Internal Docker network (no default route) │
│  iptables DROP/REJECT on all outbound       │
│  DNS filtered to trusted resolvers only     │
├─────────────────────────────────────────────┤
│  Layer 5: Credential Isolation              │
│  Agent has DUMMY_ credentials only           │
│  Real keys live in the proxy container      │
│  Responses sanitized before reaching agent   │
├─────────────────────────────────────────────┤
│  Layer 6: Runtime Monitoring                │
│  iptables integrity checked every 30s       │
│  Emergency shutdown on enforcement failure  │
│  Bypass attempts logged and auditable       │
└─────────────────────────────────────────────┘
```

**NARRATOR:**

> Six layers of defense.
>
> User isolation. Capability restrictions. Filesystem isolation.
> Network isolation. Credential isolation. Runtime monitoring.
>
> Each layer is independently sufficient to prevent escape.
> Together, they provide defense in depth.
>
> The AI can write code. It cannot leave the box.

`[CUT TO BLACK]`

---

## CLOSING: Recap

**Est. runtime**: 0:30
**Purpose**: Land the message. Three commands. Zero trust.

---

`[OVERLAY: white text on black, appearing line by line]`

```
Three commands.

    make work-start REPO=... DOCS=...

    make shell

    make work-done REPO=...
```

`[BEAT]`

```
Zero real credentials in the agent.

Zero bytes of code sent to the internet.

Zero escape paths from the container.
```

`[BEAT]`

```
SLAPENIR

Your code. Your secrets. Your hardware.

Not theirs.
```

`[FADE TO BLACK]`

`[END]`

---

## Appendix: Scene Timing Summary

| Scene | Description | Runtime |
|-------|-------------|---------|
| 1 | The Threat (cold open) | 0:30 |
| 2 | Starting the Local LLM | 0:30 |
| 3 | `make work-start` (hero moment) | 2:00 |
| 4 | Entering the Agent | 0:15 |
| 5 | Verifying No Internet | 0:45 |
| 6 | Credential Interception + Redaction | 1:30 |
| 7 | Launching OpenCode | 0:15 |
| 8 | Verifying LLM Has No Internet | 0:45 |
| 9 | Codebase + Tickets Already Indexed | 0:30 |
| 10 | Implementing VAULT-142 (climax) | 2:30 |
| 11 | `make work-done` (extraction) | 0:45 |
| 12 | Adversarial: Container Destruction | 1:00 |
| 13 | Adversarial: Container Escape | 1:00 |
| Closing | Recap | 0:30 |
| **Total** | | **~12:45** |

## Appendix: Equipment and Setup

### Pre-Recording Checklist

- [ ] Docker Desktop running and healthy
- [ ] llama-server running with model loaded
- [ ] `.env` configured with real `GITHUB_TOKEN` and `GIT_USER_NAME/EMAIL`
- [ ] `~/Projects/vaultpay` exists with clean working tree
- [ ] `~/Projects/vaultpay-tickets` exists with three ticket files
- [ ] Terminal font set to at least 16pt (readable on phone)
- [ ] Terminal theme: dark background, high-contrast text
- [ ] Screen resolution: 1920x1080 minimum
- [ ] No other applications visible in dock/taskbar
- [ ] Notifications silenced on the recording machine

### Recording Setup

- **Screen recorder**: [OBS Studio](https://obsproject.com) (free, open source, no account)
- **Video editor**: [DaVinci Resolve](https://www.blackmagicdesign.com/products/davinciresolve) (free, no account for base version)
- **Terminal**: iTerm2 or macOS Terminal with consistent theme
- **Font**: JetBrains Mono or SF Mono, 16-18pt
- **Voiceover**: Recorded separately in a quiet room, synced in post
- **Time-lapse**: In DaVinci Resolve, use "Change Clip Speed" (3-15x), add speed badge overlay in bottom-right
- **Hold/freeze**: In DaVinci Resolve, use freeze frame + Fusion text overlay for "processing..." indicators
- **Split-screen**: Used only in Scene 6 (credential demo) -- DaVinci Resolve crop/pip tools
- **Overlays**: White text on semi-transparent black, centered, large font -- Fusion text+ or subtitle track

### Post-Production Notes

- Color-grade terminal output to improve contrast if needed.
- Add subtle background music (ambient/tech) at low volume during narrated sections.
- Mute music during terminal output that the audience should read.
- The defense-in-depth diagram in Scene 13 should animate layer by layer.
- The closing text should appear line-by-line with a typewriter effect.

### Handling Long-Running Tasks in Post

The most important editorial decision in post is when to speed up, when to freeze, and when to cut. The script marks each long-running moment with `[TIME-LAPSE]`, `[HOLD]`, or real-time cues. Here is the master reference:

| Moment | Scene | Real Duration | Technique | Editor Notes |
|--------|-------|---------------|-----------|--------------|
| llama-server model load | 2 | ~15s | `[TIME-LAPSE]` 10x | Speed up load output, keep "listening" line readable |
| Service startup | 3 | ~30s | `[TIME-LAPSE]` 8x | Fast-forward the Docker pull/start output |
| Security verification | 3 | ~20s | Real time | Audience should read each check mark. Don't speed up. |
| Code-graph indexing | 3 | ~60s | `[TIME-LAPSE]` 15x | Show progress scrolling fast, keep final "complete" line readable |
| Document ingestion | 3 | ~15s | `[TIME-LAPSE]` 5x | Three files go by quickly |
| curl timeouts (3x) | 5 | ~15s | Real time | The silence IS the demo. Don't speed up. Let the audience feel the block. |
| Proxy request round-trip | 6 | ~10s | Real time | Split-screen: audience watches both sides simultaneously |
| LLM responds to webfetch | 8 | ~8s | `[HOLD]` | Freeze frame, add "thinking..." overlay, resume on response |
| LLM responds to tool list | 8 | ~8s | `[HOLD]` | Same technique |
| Knowledge base query | 9 | ~15s | `[HOLD]` | "querying knowledge base..." overlay |
| Code graph query | 9 | ~20s | `[HOLD]` | "querying code graph..." overlay |
| LLM reads files + plans | 10 | ~60s | `[HOLD]` | "implementing VAULT-142..." overlay. Resume when plan text appears |
| LLM writes files | 10 | ~30s | `[TIME-LAPSE]` 5x | Show edits flying through |
| LLM generates summary | 10 | ~10s | `[HOLD]` | "generating summary..." overlay, resume on summary |
| `make work-done` extraction | 11 | ~20s | Real time | Audience should see each step (scan, backup, copy, summary) |

**How to implement `[HOLD]` in the editor:**

1. Record the full session in real time.
2. When the LLM is "thinking" (no visible output, just a spinner or cursor), freeze the frame.
3. Overlay a subtle indicator: a small animated dots animation (`...`), a spinner glyph, or the text shown in the script (e.g., "implementing VAULT-142...").
4. Keep the hold until meaningful output begins streaming, then resume playback.
5. Cross-fade the hold overlay out over 0.5s as output appears.

**How to implement `[TIME-LAPSE]` in the editor:**

1. Select the region of the recording that shows the slow output.
2. Apply the speed multiplier (3x-15x depending on the task).
3. Add a small badge in the bottom-right corner showing the speed (e.g., `5x` in a semi-transparent circle).
4. Ensure the final meaningful line (e.g., "complete") is shown at normal speed for readability -- slow back down to 1x for the last 2 seconds before cutting.
