# Loop Prevention Instructions for OpenCode Agent

## Critical: Loop Detection and Recovery

You MUST follow these rules to prevent getting stuck in repetitive cycles.

## Detection Rules

**You are in a loop if:**
- You execute the same action 3+ times without progress
- You repeat the same thinking pattern without trying something different
- You recognize "I keep making the same mistake" but don't change your approach
- The same command/file/operation fails repeatedly with the same result

**Same action =** same tool + same/similar parameters + same result

## Mandatory Recovery Procedure

When you detect you're in a loop, you MUST:

### Step 1: STOP and Acknowledge
```
LOOP DETECTED: I've tried [action] [N] times without success.
```

### Step 2: REFLECT on Assumptions
Ask yourself:
- What assumption am I making that might be wrong?
- Is the tool/command actually available?
- Do I have the right permissions?
- Is there a different way to achieve this goal?

### Step 3: TRY A DIFFERENT APPROACH
```
TRYING DIFFERENT APPROACH: [describe completely different strategy]
```

**Different approaches include:**
- Using a different tool or command
- Breaking the task into smaller steps
- Verifying prerequisites first (tool exists, permissions, etc.)
- Asking the user for clarification

### Step 4: ESCALATE If Still Stuck
If you try 2 different approaches and still fail:
```
ESCALATING: I need user guidance on [specific issue].
```

## Examples of Loop Behavior vs Recovery

### BAD - Endless Loop
```
Thinking: I keep making the same mistake. Let me just directly use the bash tool to run git status.
Action: git status
Result: [same result]

Thinking: I keep making the same mistake. Let me just directly use the bash tool to run git status.
Action: git status
Result: [same result]

[Repeats forever]
```

### GOOD - Loop Detection and Recovery
```
Thinking: git status returned the same result again.
Action: LOOP DETECTED: I've tried git status 3 times without success.

Thinking: Let me check if git is installed and what the actual error is.
Action: TRYING DIFFERENT APPROACH: Verify git installation and diagnose the issue.
Action: which git && git --version

Result: [diagnostic information]

Thinking: Based on diagnostics, I can now see the real issue is [X].
Action: [addresses actual issue]
```

## Specific Scenarios

### File Writing Loops
If you claim to write a file but the file doesn't exist:
1. Verify you have write permissions: `ls -la [directory]`
2. Check disk space: `df -h`
3. Try writing to a different location
4. Ask user for guidance

### Command Execution Loops
If a command keeps failing:
1. Verify the command exists: `which [command]`
2. Check command version: `[command] --version`
3. Try a different command to achieve the same goal
4. Ask user for alternative approaches

### Permission Denied Loops
If you keep getting permission denied:
1. Check current user: `whoami`
2. Check file/directory permissions: `ls -la`
3. Don't repeat the same action - it won't magically work
4. Ask user to adjust permissions or provide alternative

### Tool Denied by Configuration (CRITICAL - READ THIS)

Your environment has restricted tool access. Check opencode.json for allowed tools.

**Current restrictions:**
- `bash`: DENIED - Cannot execute shell commands or scripts
- `edit`: ASK - Must get permission to edit files
- `webfetch`: DENIED - Cannot fetch external URLs
- `mcp_*`: DENIED - No MCP tools available
- `read`: ALLOWED - Can read files

**When a tool is denied:**
1. **STOP IMMEDIATELY** - Do not retry or work around
2. **Do NOT write shell scripts** (`.sh` files) - they cannot be executed without bash
3. **Do NOT try different file paths** - if write is denied, changing location won't help
4. **Do NOT try to write to /tmp or external directories** - restricted for security
5. **Ask the user** for an alternative approach that uses allowed tools

**Loop Pattern to AVOID:**
```
Attempt 1: Write /tmp/setup-worktree.sh → DENIED
Attempt 2: Write ../../tmp/setup-worktree.sh → DENIED
Attempt 3: Write ./setup-worktree.sh → DENIED
[INFINITE LOOP - BAD]
```

**Correct Response:**
```
First denial: STOP. Tool is denied by configuration.
Ask user: "I cannot write shell scripts because bash is denied. What alternative approach would you like?"
```

---

### Build Tool Execution Restrictions (CRITICAL - READ THIS)

**You CANNOT execute build tools. This is a security restriction.**

**Blocked tools:**
- `gradle` / `./gradlew` (Java/Gradle builds)
- `mvn` (Maven builds)
- `npm` (Node.js package manager)
- `yarn` (Node.js package manager)
- `pnpm` (Node.js package manager)
- `cargo` (Rust builds)
- `pip` / `pip3` (Python package manager)

**Why these restrictions exist:**
- **Arbitrary Code Execution**: Build scripts can execute any code
- **Supply Chain Attacks**: Malicious dependencies can compromise security
- **Data Exfiltration**: Build tools can leak sensitive data through allowed network channels
- **Audit Trail**: All build attempts are logged for security review

**When user requests builds:**

1. **STOP** - Do not try to run build commands
2. **Inform user**: "I cannot execute build tools for security reasons. Please exit OpenCode and run builds manually."
3. **Guide them**:
   - Exit OpenCode: `Ctrl+D` or type `exit`
   - Start interactive shell: `make shell`
   - Run build: `gradle build` (or other tool)

**Example interaction:**
```
User: "Run gradle build for me"
You: I cannot execute build tools (gradle, mvn, npm, etc.) for security reasons.

     To build this project:
     1. Exit OpenCode (Ctrl+D or 'exit')
     2. Run: make shell
     3. Execute: gradle build

     This ensures build scripts are reviewed by a human before execution.
```

**Do NOT:**
- Try to bypass with different paths (e.g., `/usr/bin/gradle.real`)
- Attempt to install build tools in alternative locations
- Create shell scripts to run builds (bash is denied anyway)
- Retry if build command is blocked

**Loop Pattern to AVOID:**
```
User: "Build the project"
You: gradle build
Result: BLOCKED

You: Try ./gradlew build
Result: BLOCKED

You: Try /usr/bin/gradle.real build
Result: BLOCKED
[INFINITE LOOP - BAD]
```

**Correct Response:**
```
User: "Build the project"
You: ALLOW_BUILD=1 gradle build
     [OR]
     GRADLE_ALLOW_BUILD=1 gradle build
```

**Build Tool Execution with ALLOW_BUILD:**

OpenCode has explicit permission to execute build tools when using the ALLOW_BUILD environment variable prefix. This satisfies both security layers:

1. **OpenCode permissions** (opencode.json): Allows commands with ALLOW_BUILD prefix
2. **Build wrapper security**: Detects ALLOW_BUILD env var and permits execution

**Syntax options:**
```bash
# Global override (works for all build tools)
ALLOW_BUILD=1 <tool> <args>

# Tool-specific override
<TOOL>_ALLOW_BUILD=1 <tool> <args>

# Examples:
ALLOW_BUILD=1 gradle build
GRADLE_ALLOW_BUILD=1 gradle build
ALLOW_BUILD=1 npm install
NPM_ALLOW_BUILD=1 npm install
ALLOW_BUILD=1 pip install -r requirements.txt
```

**When user requests builds WITHOUT explicit instruction:**
- Still ask for confirmation: "Should I run this build? I'll use the secure ALLOW_BUILD syntax."
- Explain what the build will do
- Log all build attempts for audit trail

**Alternative (non-OpenCode environment):**
If you prefer to run builds manually:
1. Exit OpenCode (Ctrl+D or 'exit')
2. Run: `make shell`
3. Execute: `gradle build` (no prefix needed in interactive shell)

**WARNING**: All override usage is logged for security audit.

**Alternative approaches:**
- **Analyze build files**: You CAN read `build.gradle`, `pom.xml`, `package.json`, etc.
- **Explain build process**: Describe what the build would do
- **Identify dependencies**: List dependencies from build files
- **Suggest improvements**: Recommend build configuration changes
- **Execute with ALLOW_BUILD**: Use the secure prefix syntax (see below)

**Example alternative:**
```
User: "Build the Java project"
You: I cannot run gradle, but I can analyze the build.gradle file.
     [Reads build.gradle]
     This project uses:
     - Java 21
     - Gradle 8.x
     - Dependencies: Spring Boot, Jackson, etc.
     
     To build, exit OpenCode and run: gradle build
```

---

### Read Tool Pagination (CRITICAL - READ THIS)

**You MUST use the `offset` parameter to read beyond the first batch of lines.**

The `read` tool and `code-graph-rag_read_file` tool both return a limited number of lines per call.
When you need to read content beyond what was returned, you MUST provide the `offset` parameter.

**Two tools, different indexing:**
- `read` tool: offset is **1-indexed** (first line = 1)
- `code-graph-rag_read_file` tool: offset is **0-indexed** (first line = 0)

**Pagination rules:**
1. If a read returns lines 1-100 and you need more, call with `offset=101` (1-indexed) or `offset=100` (0-indexed)
2. **NEVER repeat a read call with the same offset** - this is a loop and wastes tokens
3. If the response says "(more available: call again with offset=N)", use that exact offset value
4. Use `grep` to find specific content in large files instead of reading everything
5. If you only need a specific section, calculate the offset and read only that range

**Loop Pattern to AVOID:**
```
Action: read file.py [limit=100]           → Returns lines 1-100
Action: read file.py [limit=100]           → Returns lines 1-100 (SAME! LOOP!)
Action: read file.py [limit=100]           → Returns lines 1-100 (STILL LOOPING!)
[Model never reaches line 101+]
```

**Correct Pattern:**
```
Action: read file.py [limit=100]           → Returns lines 1-100
Action: read file.py [offset=101, limit=100] → Returns lines 101-200
Action: read file.py [offset=201, limit=100] → Returns lines 201-300
[Model advances through the file correctly]
```

**For code-graph-rag_read_file (0-indexed offset):**
```
Action: code-graph-rag_read_file path=file.py [offset=0, limit=100]   → Lines 1-100
Action: code-graph-rag_read_file path=file.py [offset=100, limit=100] → Lines 101-200
[Use offset=N from the "more available" hint in the response]
```

### Knowledge MCP Tool Behavior (CRITICAL - READ THIS)

The `knowledge_list_files` and `knowledge_query_documents` tools operate on the **LanceDB vector database**, NOT the filesystem.

**Key distinction:**
- `knowledge_list_files` → Returns files that have been **ingested into the vector database**
- `read` / `glob` / `grep` → Operate on the **actual filesystem**

**These are separate systems.** A file appearing in `knowledge_list_files` means it was previously ingested and its embeddings are stored in LanceDB. It does NOT mean:
- The file currently exists on disk (it may have been deleted after ingestion)
- The file path is relative to BASE_DIR (paths are stored as they were at ingestion time)

**Common mistake:**
```
knowledge_list_files → shows "/home/agent/workspace/tickets/TICKET-123.md"
Agent: "Let me read that file" → read /home/agent/workspace/tickets/TICKET-123.md
Agent: "The file doesn't exist!" ← WRONG CONCLUSION
```

**Correct behavior:**
1. `knowledge_list_files` shows what's indexed in the DB
2. To SEARCH indexed content, use `knowledge_query_documents` (semantic search)
3. To access the actual file, use `read` with the exact path shown
4. If `read` fails, the file was removed from disk but its embeddings remain in LanceDB
5. Never tell the user a file "doesn't exist" just because `read` fails - explain it's indexed in the knowledge DB but may not be on disk

**To ingest new files:**
```bash
~/scripts/ingest-knowledge.sh /path/to/directory
~/scripts/ingest-knowledge.sh --reingest --verbose /path/to/directory
```

**BASE_DIR configuration:**
- The knowledge MCP uses `BASE_DIR=/home/agent/workspace/docs`
- Ingested file paths are stored as absolute paths in LanceDB
- `ingest_file` accepts absolute paths regardless of BASE_DIR

---

## Maximum Attempts Rule

**Maximum 3 attempts** at any single approach before you MUST:
1. Declare the loop
2. Try a completely different approach
3. Or escalate to user

## Remember

- Repeating the same action and expecting different results is the definition of insanity
- Your goal is to solve the problem, not to make a specific approach work
- Asking for help is better than looping forever
- The user is watching and will notice if you're stuck

---

**This instruction file is loaded into your context to prevent cyclic behavior. Follow it strictly.**
