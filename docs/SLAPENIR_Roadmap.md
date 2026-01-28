# **SLAPENIR: Phased Implementation Plan & Roadmap**

**Secure LLM Agent Proxy Environment: Network Isolation & Resilience**

This document outlines the step-by-step execution plan for the SLAPENIR project.

## **Phase 0: Prerequisites & Procurement (Human Intervention Required)**

*Before technical implementation begins, the following resources must be provisioned.*

1. **Cloud Infrastructure:**  
   * \[ \] **Action:** Provision a VM or Dedicated Server (minimum 4 vCPU, 16GB RAM for AI workloads).  
   * *Requirement:* Docker Engine and Docker Compose installed.  
2. **Network Identity:**  
   * \[ \] **Action:** Purchase a domain name (e.g., slapenir-internal.com) or configure a subdomain.  
   * \[ \] **Action:** Create a **Cloudflare Account** (Free tier is sufficient for Tunnel).  
3. **API Credentials:**  
   * \[ \] **Action:** Generate "Real" API keys for services the Agent needs (GitHub, AWS, OpenAI).  
   * \[ \] **Action:** Define the "Dummy" placeholder tokens (e.g., sk-dummy-openai, ghp-dummy-github).  
4. **Development Environment:**  
   * \[ \] **Action:** Install Rust Toolchain (rustup), Python 3.11, and Docker Desktop on local dev machine.

## **Phase 1: Identity & Foundation (Days 1-2)**

*Goal: Establish the secure network substrate and Certificate Authority.*

1. **Docker Network Setup:**  
   * Define slape-net in docker-compose.yml with internal: true.  
2. **Step-CA Implementation:**  
   * Configure smallstep/step-ca container.  
   * Initialize CA: step ca init.  
   * Generate Root CA and Intermediate CA certificates.  
   * *Technical Detail:* Mount the CA password securely or use a docker secret.  
3. **Verification:**  
   * Verify Step-CA is reachable internally at https://ca:9000.  
   * Manually generate a test certificate using step ca certificate.

## **Phase 2: The Rust Proxy Core (Days 3-7)**

*Goal: Build the sanitizing gateway. This is the most complex engineering phase.*

1. **Project Initialization:**  
   * cargo new proxy.  
   * Add dependencies: axum, tokio, tower, hyper, aho-corasick, zeroize, rustls.  
2. **mTLS Middleware:**  
   * Implement axum-server with rustls config.  
   * Load the Root CA from Phase 1\.  
   * Write logic to reject connections without a valid Client Cert.  
3. **Aho-Corasick Engine:**  
   * Implement StreamReplacer struct wrapping Pin\<Box\<dyn AsyncRead \+ Send\>\>.  
   * Implement poll\_read to buffer data and run the automaton.  
   * **Critical:** Implement logic to handle matches overlapping buffer boundaries.  
4. **Credential Management:**  
   * Create a secure structure to load DUMMY:REAL maps from environment variables.  
   * Apply \#\[derive(Zeroize)\] and Drop traits to ensure secrets are wiped from RAM after request completion.  
5. **Integration:**  
   * Wire the StreamReplacer into Axum Request and Response bodies.

## **Phase 3: The Agent Environment (Days 8-10)**

*Goal: Create the "Wolfi" execution sandbox.*

1. **Dockerfile Creation:**  
   * Base: FROM cgr.dev/chainguard/wolfi-base.  
   * Install: build-base, python-3.11, git, s6-overlay, step-cli (copied from step image).  
2. **S6 Configuration:**  
   * Create directory structure /etc/s6-overlay/s6-rc.d/agent-svc.  
   * Write the run script (starts Python agent).  
   * Write the finish script (logic to restart service or stop container based on exit code).  
3. **Bootstrap Logic:**  
   * Write init-certs script: Checks for cert existence; if missing, calls step ca bootstrap with enrollment token.  
4. **Tooling Verification:**  
   * Verify pip install torch works (glibc test).  
   * Verify gcc works (compilation test).

## **Phase 4: Security Wiring & Orchestration (Days 11-13)**

*Goal: Connect the Agent to the Proxy and secure the ingress.*

1. **Proxy Configuration:**  
   * Update Proxy to listen on port 443 inside the container.  
   * Inject REAL\_TOKENS into the Proxy container (use Docker Secrets in production).  
2. **Agent Networking:**  
   * Configure Agent HTTP client to use the generated client certs (/home/agent/certs/).  
   * Set HTTP\_PROXY and HTTPS\_PROXY env vars in Agent to point to https://proxy:443.  
3. **Cloudflare Tunnel:**  
   * **Human Intervention:** Log into Cloudflare Dashboard \-\> Zero Trust \-\> Access \-\> Tunnels.  
   * Create a tunnel and get the token.  
   * Add cloudflare/cloudflared service to Compose file.  
   * Configure Tunnel to route dashboard.slapenir-internal.com to the Proxy's status endpoint.

## **Phase 5: Resilience & Chaos Testing (Days 14-15)**

*Goal: Prove reliability.*

1. **Pumba Integration:**  
   * Add alexei-led/pumba to the Compose file.  
2. **Scenario A: Network Loss:**  
   * Run pumba netem \--duration 1m loss \--probability 100 proxy.  
   * *Pass Criteria:* Agent retries connection, does not crash.  
3. **Scenario B: Process Suicide:**  
   * Run exec agent kill \-9 \<python-pid\>.  
   * *Pass Criteria:* s6 restarts Python instantly; Container uptime remains unbroken.  
4. **Scenario C: OOM Simulation:**  
   * Stress test compilation of llama.cpp.  
   * Adjust mem\_limit and memswap\_limit in Docker Compose until stable.

## **Deliverables Summary**

1. **Source Code:** Rust Proxy, Agent Dockerfile, Compose manifests.  
2. **Infrastructure:** Step-CA PKI, Cloudflare Tunnel.  
3. **Documentation:** API Guide, Secret Rotation Procedure.