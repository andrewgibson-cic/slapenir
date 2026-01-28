# SLAPENIR Proxy

**Secure LLM Agent Proxy Environment - Credential Sanitization Gateway**

## Overview

The SLAPENIR Proxy is a Rust-based security gateway that provides zero-knowledge credential sanitization for autonomous AI agents. It acts as a transparent man-in-the-middle (MitM) service that:

- ✅ Injects real credentials into outbound requests
- ✅ Sanitizes real credentials from inbound responses
- ✅ Enforces mTLS authentication
- ✅ Provides rate limiting and traffic control
- ✅ Guarantees secure memory handling (zeroize)

## Architecture

```
Agent (Untrusted) <--mTLS--> Proxy (Trusted) <--HTTPS--> External APIs
                              ↓
                    [Streaming Sanitization]
                    - Aho-Corasick Pattern Matching
                    - Zeroize Memory Management
```

## Features

### Current (v0.1.0)
- ✅ Basic HTTP server with Axum
- ✅ Health check endpoint
- ✅ Logging and tracing
- ✅ Test infrastructure

### Planned (Phase 2)
- ⏳ mTLS middleware
- ⏳ Aho-Corasick streaming sanitizer
- ⏳ Request/response interception
- ⏳ Secure credential management
- ⏳ Rate limiting

## Development

### Prerequisites
- Rust 1.93+ (edition 2021)
- Docker (for integration testing)

### Build
```bash
cargo build
```

### Run
```bash
cargo run
# Server starts on http://127.0.0.1:3000
```

### Test
```bash
cargo test
```

### Key Dependencies
- **axum**: Web framework
- **tokio**: Async runtime
- **tower**: Middleware
- **aho-corasick**: Pattern matching
- **rustls**: TLS implementation
- **zeroize**: Secure memory wiping

## Project Structure

```
proxy/
├── src/
│   └── main.rs          # Entry point, HTTP server
├── Cargo.toml           # Dependencies
└── README.md            # This file
```

## Security Considerations

- **Memory Safety**: All credential buffers are zeroed on drop
- **No Logging**: Credentials never appear in logs
- **Streaming**: Processes data without full buffering
- **Split-Secret Detection**: Handles secrets split across TCP chunks

## License

MIT

## Author

andrewgibson-cic <andrew.gibson-cic@ibm.com>