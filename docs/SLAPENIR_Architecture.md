# **SLAPENIR: Architecture Specification**

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

## **1\. System Overview**

**SLAPENIR** is a "Zero-Knowledge" execution sandbox designed to host high-privilege Autonomous Agents. The architecture enforces a strict separation of **Capability** (the Agent's ability to execute logic) and **Authority** (the credentials required to interact with external systems).

The system relies on a Polyglot Architecture:

* **Security Gateway (Proxy):** Written in **Rust** for deterministic memory management and high-throughput stream processing.  
* **Execution Environment (Agent):** Built on **Wolfi OS** for minimal attack surface with full glibc compatibility.  
* **Identity Plane:** Managed by **Step-CA** for automated, short-lived mutual TLS (mTLS) certificates.

## **2\. Component Architecture**

### **2.1 The Proxy Gateway (Rust)**

The Proxy is the central security enforcement point. It functions as a transparent Man-in-the-Middle (MitM) service that injects credentials into outbound requests and sanitizes inbound responses.

#### **2.1.1 Core Technology Stack**

* **Language:** Rust (Edition 2021+)  
* **Runtime:** tokio (Asynchronous Runtime)  
* **HTTP Framework:** axum (Ergonomic, modular web framework)  
* **Middleware Abstraction:** tower (Service composition)  
* **Search Algorithm:** aho-corasick (Streaming multi-pattern search)  
* **Memory Hygiene:** zeroize (Secure memory wiping)

#### **2.1.2 Request/Response Pipeline (Middleware Stack)**

The Proxy is structured as a series of tower layers. Data flows through this pipeline for every network interaction initiated by the Agent.

1. **Layer 1: mTLS Termination (Identity)**
   * **Function:** Terminates TLS connections from the Agent.
   * **Logic:** Extracts the Client Certificate. Validates the Common Name (CN) against the allowlist of active agents. Rejects any connection without a valid Step-CA signed certificate.
   * **Technology:** rustls, axum-server.
2. **Layer 2: Rate Limiting (Traffic Control)**
   * **Function:** Prevents Denial of Service (DoS) from malfunctioning agents.
   * **Algorithm:** Token Bucket.
   * **Logic:** Limits requests per IP/Agent ID. Allows for "bursts" (e.g., git operations) but enforces a sustained average.
   * **Crate:** governor or leaky-bucket.
3. **Layer 3: Request Injection (The "Upstream" Path)**
   * **Function:** Replaces DUMMY\_TOKEN with REAL\_TOKEN.
   * **Logic:**
     * Reads HTTP Request Body with configurable size limits (default: 10MB).
     * Uses Aho-Corasick algorithm for O(N) multi-pattern matching.
     * On match, injects the real secret from the secure vault (memory).
     * **Critical Security:** The mapping of DUMMY:REAL is held in memory protected by zeroize.
4. **Layer 4: Response Sanitization (The "Downstream" Path)**
   * **Function:** Replaces REAL\_TOKEN with [REDACTED] to prevent leakage.
   * **Logic:**
     * Reads HTTP Response Body with configurable size limits (default: 100MB).
     * Uses cached Aho-Corasick automaton for O(N) pattern matching (built once, reused).
     * **Binary-Safe Sanitization:** Processes raw bytes, handling non-UTF-8 payloads correctly.
     * **Header Sanitization:** Also sanitizes secrets in response headers (Set-Cookie, Location, etc.).
     * **Content-Length Correction:** Recalculates Content-Length after body modification.
     * **Blocked Headers:** Removes dangerous headers (x-debug-token, server-timing, etc.).

#### **2.1.3 Security Features (2026-02-22 Update)**

The following security enhancements have been implemented:

| Feature | Description | CVE Mitigation |
|---------|-------------|----------------|
| **Binary-Safe Sanitization** | Uses byte-based pattern matching for non-UTF-8 payloads | Prevents bypass via binary responses |
| **Header Sanitization** | Sanitizes all HTTP response headers | Prevents secret leakage via headers |
| **Size Limits** | Configurable request/response size limits | Prevents OOM attacks |
| **Content-Length Fix** | Recalculates Content-Length after sanitization | Prevents protocol desync |
| **Cached Automaton** | Sanitization automaton built once at startup | Prevents performance degradation |
| **Blocked Headers** | Removes debug/info headers from responses | Reduces information leakage |

### **2.2 The Agent Environment (Wolfi OS)**

The Agent is the untrusted execution environment. It must support complex AI workloads (Python, PyTorch, Compilation) while maintaining a minimal security footprint.

#### **2.2.1 Operating System: Wolfi**

* **Base Image:** cgr.dev/chainguard/wolfi-base  
* **Rationale:**  
  * **glibc Compatibility:** Unlike Alpine (musl), Wolfi supports standard Python wheels (PyTorch, NumPy, TensorFlow) without requiring local compilation.  
  * **Supply Chain Security:** All packages are signed and have SBOMs.  
  * **Minimalism:** Contains no kernel, systemd, or unnecessary binaries.

#### **2.2.2 Process Supervision: s6-overlay**

To satisfy the "Dual-Layer Disaster Recovery" requirement, the Agent container uses s6-overlay as PID 1\.

* **PID 1 (s6-svscan):** The rigorous init process. Handles signal propagation and zombie reaping.  
* **Service A (Agent Logic):** The Python script or shell running the LLM agent.  
* **Failure Modes:**  
  * **Mode A (Process Crash/Suicide):** If the Agent executes kill \-9 $$ or the Python script crashes, s6 restarts the *service* immediately. The Container remains running; filesystem state (/workspace) is preserved.  
  * **Mode B (System Failure):** If s6 itself crashes or OOM occurs, the Docker restart\_policy: on-failure handles the Container restart.

### **2.3 Network & Identity Architecture**

#### **2.3.1 Network Topology**

The architecture uses a strict "Bridge Isolation" model.

* **slape-net (Internal Docker Network):**  
  * **Members:** Agent, Proxy, Step-CA.  
  * **Constraint:** internal: true. No direct internet access.  
* **Ingress (Admin Access):**  
  * **Cloudflare Tunnel:** Exposes the Dashboard/Logs to administrators.  
  * **Security:** Outbound-only connection. No open firewall ports. Authenticated via Cloudflare Access (Zero Trust).

#### **2.3.2 Certificate Bootstrapping**

1. **Startup:** Agent container boots. s6 executes /etc/s6-overlay/s6-rc.d/init-certs.  
2. **Request:** Agent runs step ca bootstrap using a one-time enrollment token injected via environment variable.  
3. **Issuance:** Step-CA issues a short-lived (e.g., 24h) Certificate and Private Key to the Agent volume.  
4. **Connection:** Agent uses these certs to establish mTLS with the Proxy.

## **3\. Data Flow Diagram (Conceptual)**

sequenceDiagram  
    participant LLM as Agent (Wolfi)  
    participant MTLS as mTLS Layer  
    participant PROXY as Rust Proxy  
    participant WORLD as Internet

    Note over LLM: Wants to clone Private Repo  
    LLM-\>\>MTLS: HTTPS Request (Token: DUMMY\_GITHUB)  
    MTLS-\>\>MTLS: Verify Client Cert (Step-CA)  
    MTLS-\>\>PROXY: Forward Authenticated Stream

    Note over PROXY: Streaming Scan (Aho-Corasick)  
    PROXY-\>\>PROXY: Detect "DUMMY\_GITHUB"  
    PROXY-\>\>PROXY: Swap with "ghp\_RealToken..."  
    PROXY-\>\>PROXY: Zeroize Secret from Buffer

    PROXY-\>\>WORLD: Send Request (Real Token)  
    WORLD-\>\>PROXY: Response (Data \+ Potential Secrets)

    Note over PROXY: Reverse Scan  
    PROXY-\>\>PROXY: Detect "ghp\_RealToken..."  
    PROXY-\>\>PROXY: Swap with "REDACTED"

    PROXY-\>\>LLM: Safe Response Stream

## **4\. Key Architectural Decisions Matrix**

| Decision | Choice | Alternative | Rationale |
| :---- | :---- | :---- | :---- |
| **Language** | **Rust** | Go (Golang) | Go's Garbage Collector cannot guarantee immediate memory wiping (Security Risk). Rust Drop \+ zeroize guarantees it. |
| **OS** | **Wolfi** | Alpine | Alpine (musl) breaks Python AI wheels. Wolfi offers glibc support with Alpine's size. |
| **Supervision** | **s6-overlay** | Supervisord / Bash | Bash handles signals poorly (zombies). s6 is lightweight and handles process restarts correctly inside Docker. |
| **Regex** | **Aho-Corasick** | Standard Regex | Standard regex is O(N\*M). Aho-Corasick is O(N) and supports stream buffering for split-secret detection. |
| **Ingress** | **Cloudflare** | Nginx / Port Fwd | Eliminates open port risks. Shifts AuthN to the Edge (Cloudflare Access). |

