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
