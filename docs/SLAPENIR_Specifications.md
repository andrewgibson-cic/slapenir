# **SLAPENIR: System Specifications**

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

This document outlines the granular requirements and specifications for the SLAPENIR project.

## **1\. Functional Requirements**

### **R1: Isolation & Network Policy**

* **REQ-1.1:** The Agent Environment **MUST NOT** have a default route to the public internet.  
* **REQ-1.2:** All outbound TCP/UDP traffic from the Agent **MUST** be routed explicitly through the Proxy Gateway.  
* **REQ-1.3:** The Network **MUST** use a Docker Bridge with internal: true to prevent accidental exposure.

### **R2: Zero-Knowledge Sanitization**

* **REQ-2.1:** The Proxy **MUST** intercept all HTTP/S request and response bodies.  
* **REQ-2.2:** The Proxy **MUST** maintain a secure, in-memory map of Dummy Token \-\> Real Token.  
* **REQ-2.3:** The Proxy **MUST** replace Dummy Token with Real Token in the Upstream Request (Agent \-\> Internet).  
* **REQ-2.4:** The Proxy **MUST** replace Real Token with \[REDACTED\] in the Downstream Response (Internet \-\> Agent).  
* **REQ-2.5:** The Agent **MUST NEVER** receive a Real Token in plain text, even if the external API echoes it back in a response.

### **R3: Identity & Authentication**

* **REQ-3.1:** The connection between Agent and Proxy **MUST** be secured via Mutual TLS (mTLS) version 1.2 or 1.3.  
* **REQ-3.2:** The Proxy **MUST** validate the Agent's Client Certificate against a local Root CA. Connections without valid client certificates must be dropped immediately.  
* **REQ-3.3:** The Agent **MUST** automatically bootstrap its identity on first boot using a one-time enrollment token from Step-CA.

### **R4: Resilience & Recovery**

* **REQ-4.1:** The Agent Container **MUST** utilize a process supervisor (s6-overlay) as PID 1\.  
* **REQ-4.2:** In the event of an Agent application crash (exit code \!= 0), the supervisor **MUST** restart the process within \< 1 second without restarting the entire container.  
* **REQ-4.3:** In the event of a system failure (e.g., Out of Memory), the Docker Daemon **MUST** restart the container automatically (restart: on-failure).

### **R5: "Dangerous Mode" Support**

* **REQ-5.1:** The Agent OS **MUST** provide glibc compatibility (via Wolfi OS) to support standard Python AI ecosystem wheels.  
* **REQ-5.2:** The Agent **MUST** be capable of dynamically installing build tools (gcc, make, cmake) via package manager (apk) during runtime if requested by the LLM.  
* **REQ-5.3:** The Agent **MUST** support the installation of Python binary wheels (specifically manylinux standards) without requiring local source compilation.

## **2\. Non-Functional Requirements**

### **R6: Performance & Latency**

* **REQ-6.1:** Proxy processing overhead (latency penalty) **MUST** be \< 50ms for payloads under 100KB.  
* **REQ-6.2:** The Proxy **MUST** support streaming. It **MUST NOT** buffer the entire file into memory before forwarding. This is critical to support operations like multi-GB git clone or large model downloads.

### **R7: Memory Safety**

* **REQ-7.1:** The Proxy **MUST** be written in a memory-safe language that does not use a Garbage Collector (Rust) to ensure deterministic memory management.  
* **REQ-7.2:** All buffers containing secrets **MUST** be zeroed out (overwritten with 0x00) immediately upon drop/release using volatile writes (e.g., the zeroize crate).

## **3\. Environment & Hardware Specifications**

### **3.1 Proxy Container Specs**

* **Base Image:** rust:1.75-slim (Build Stage), debian:bookworm-slim (Runtime Stage).  
* **CPU:** 0.5 vCPU reserved.  
* **Memory:** 256MB Limit (Optimized for Rust's low footprint).  
* **Environment Variables:**  
  * RUST\_LOG=info  
  * CERT\_PATH=/etc/proxy/certs  
  * TOKENS\_JSON=/etc/proxy/secrets.json (or Docker Secret path)

### **3.2 Agent Container Specs**

* **Base Image:** cgr.dev/chainguard/wolfi-base  
* **CPU:** 2 vCPU (Minimum requirement for efficient LLM tool use).  
* **Memory:** 4GB Limit (Soft), with 8GB Swap allowed to handle compilation spikes.  
* **Volumes:**  
  * /workspace: Persists code execution state.  
  * /home/agent/certs: Persists mTLS identity keys.

### **3.3 CA Container Specs**

* **Image:** smallstep/step-ca:latest  
* **Storage:** Persistent volume for the BoltDB database (db).

## **4\. Software Bill of Materials (SBOM)**

### **4.1 Proxy Dependencies (Rust)**

* **tokio**: Asynchronous Runtime.  
* **axum**: HTTP Server Framework.  
* **tower**: Middleware Service abstraction.  
* **aho-corasick**: High-performance string search algorithm.  
* **zeroize**: Secure memory clearing traits.  
* **rustls**: Modern TLS implementation (replacing OpenSSL).

### **4.2 Agent Dependencies (Wolfi APK)**

* **python-3.11**: Core runtime.  
* **py3-pip**: Package manager.  
* **build-base**: Standard build chain (gcc, make, etc.).  
* **git**: Version control.  
* **openssh**: SSH client.  
* **s6-overlay**: Process supervisor.