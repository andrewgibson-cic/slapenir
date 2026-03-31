# SLAPENIR Proxy

**Secure LLM Agent Proxy Environment with Network Isolation & Resilience (SLAPENIR) - Credential Sanitization Gateway**

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

### Implemented
- ✅ Basic HTTP server with Axum
- ✅ Health check endpoint
- ✅ Logging and tracing
- ✅ **Aho-Corasick streaming sanitizer**
- ✅ **Request/response interception middleware**
- ✅ **Secure credential management (Zeroize trait)**
- ✅ **mTLS middleware**
- ✅ **Rate limiting**
- ✅ **105+ tests passing (82% coverage)**

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
│   ├── main.rs           # Entry point, HTTP server
│   ├── lib.rs            # Library root
│   ├── proxy.rs          # Proxy handler logic
│   ├── config.rs         # Configuration management
│   ├── builder.rs        # Service builder
│   ├── sanitizer.rs      # Aho-Corasick credential sanitizer
│   ├── middleware.rs      # Request/response middleware
│   ├── metrics.rs        # Prometheus metrics
│   ├── mtls.rs           # mTLS implementation
│   ├── http_parser.rs    # HTTP parsing utilities
│   ├── auto_detect.rs    # Auto credential detection
│   ├── strategy.rs       # Strategy trait definition
│   ├── strategies/       # Authentication strategies (AWS SigV4, etc.)
│   ├── connect*.rs       # Connection handling (full, http, mitm, middleware)
│   └── tls/              # TLS utilities
├── benches/              # Performance benchmarks
├── migrations/           # PostgreSQL migrations
├── tests/                # Integration tests
├── .cargo/               # Cargo configuration (mutants.toml)
├── config.yaml           # Proxy configuration
├── Cargo.toml            # Dependencies
└── README.md             # This file
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