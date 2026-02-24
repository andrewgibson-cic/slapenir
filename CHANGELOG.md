## [1.1.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.0.1...v1.1.0) (2026-02-24)


### Features

* **agent:** add Ollama local LLM support with Aider through proxy ([9496c75](https://github.com/andrewgibson-cic/slapenir/commit/9496c756a49c97677695cd9b9f8f2665b2c87d44))
* **auto-detect:** add PostgreSQL-based automatic secret detection ([32114fb](https://github.com/andrewgibson-cic/slapenir/commit/32114fbf2dc576863b54daf8558809db42fea890))
* **security:** add iptables-based traffic enforcement ([25d6660](https://github.com/andrewgibson-cic/slapenir/commit/25d6660e43cbc0f47ae039757cf02c95158d7147))


### Bug Fixes

* change network subnet from 172.21.0.0/24 to 172.30.0.0/24 to avoid conflict ([a7c8134](https://github.com/andrewgibson-cic/slapenir/commit/a7c8134fe1cc20cab7cacf71a50ca7fd52584e10))
* **ci:** add --force flag to cargo-audit install ([1c2c3f3](https://github.com/andrewgibson-cic/slapenir/commit/1c2c3f3475fdf849092f36667a11d9540ec61ae3))
* **ci:** add --ignore flags to cargo audit in test.yml and release.yml ([f694ce2](https://github.com/andrewgibson-cic/slapenir/commit/f694ce2308fa031df4e03a0b579bbcfede792146))
* **ci:** force cargo audit step to always succeed ([61be61f](https://github.com/andrewgibson-cic/slapenir/commit/61be61f912e382c3f1dc29299342d7e224e81e6a))
* **ci:** improve cargo audit with explicit ignores and debug output ([6ccecb5](https://github.com/andrewgibson-cic/slapenir/commit/6ccecb56529bd03d81b2d4c1df8afbdb0961580e))
* integrate auto-detection database into proxy startup ([3d6d7fd](https://github.com/andrewgibson-cic/slapenir/commit/3d6d7fdcf0008b4314b2989aa7f2c2558e9e269b))
* only collect dummy patterns for strategies with real credentials ([a39c040](https://github.com/andrewgibson-cic/slapenir/commit/a39c0407635642976d032b2d538f71a696e0fb4a))
* **security:** add deny.toml to ignore RSA advisory in cargo-deny ([ff32eb7](https://github.com/andrewgibson-cic/slapenir/commit/ff32eb7a994d2873e8ae96e10ae9846bb06d6a34))
* **security:** resolve cargo audit vulnerabilities ([febe66b](https://github.com/andrewgibson-cic/slapenir/commit/febe66bf4301695d70bb50e516f296e78575f040))
* **security:** resolve critical sanitization bypass vulnerabilities ([9e4a42b](https://github.com/andrewgibson-cic/slapenir/commit/9e4a42b04501eca81f73be7ead65b58085e8d256))
* **security:** resolve critical sanitization bypass vulnerabilities ([747da48](https://github.com/andrewgibson-cic/slapenir/commit/747da481ed337825071b6c7f3f49389e22ed1924))
* use docker-compose (v1) instead of docker compose (v2) ([bf58fd8](https://github.com/andrewgibson-cic/slapenir/commit/bf58fd8a2c4a241002e035b9d87793ea88565c6d))


### Code Refactoring

* simplify Makefile from 177 to 48 lines ([1d456e8](https://github.com/andrewgibson-cic/slapenir/commit/1d456e8521dbe68386408f9e12557912e78bd8f8))

## [1.0.1](https://github.com/andrewgibson-cic/slapenir/compare/v1.0.0...v1.0.1) (2026-02-05)


### Bug Fixes

* add troubleshooting section for semantic-release ([39d2e86](https://github.com/andrewgibson-cic/slapenir/commit/39d2e865a21c26bff8a640854639f6a2b855b8a8))

## 1.0.0 (2026-02-04)


### ⚠ BREAKING CHANGES

* **ops:** Environment variables now loaded from .env file instead of shell export

### Features

* add mTLS module for mutual TLS authentication ([382760e](https://github.com/andrewgibson-cic/slapenir/commit/382760e7129327a97e9f8b5d6cac0258d1e61f05))
* add mTLS support to docker-compose and testing scripts ([b37d852](https://github.com/andrewgibson-cic/slapenir/commit/b37d85233901d7b7b6db18d3c52a46d459a2492b))
* add Python mTLS client for agent ([a27c3a7](https://github.com/andrewgibson-cic/slapenir/commit/a27c3a74a761deefddbbfeefe1c3a729bff449a8))
* **agent:** add secure Git credentials via PATs ([8b4904e](https://github.com/andrewgibson-cic/slapenir/commit/8b4904e9b5b713d5f0437dc56e084b372f71a891))
* Complete Phase 3 TLS MITM implementation + build fixes ([ad96279](https://github.com/andrewgibson-cic/slapenir/commit/ad962795fc367309032e48bb0609806272bf8078))
* integrate mTLS support into proxy main ([82a6533](https://github.com/andrewgibson-cic/slapenir/commit/82a6533372d6c0b19e52bf61465948cf832587bf))
* make dummy environment variables accessible via shell ([83966bd](https://github.com/andrewgibson-cic/slapenir/commit/83966bd8a8846445959ad02510902d70f7f3bab9))
* **metrics:** instrument proxy and sanitizer with Prometheus metrics ([0b2b763](https://github.com/andrewgibson-cic/slapenir/commit/0b2b763c58f7195312c338787eacdb9fa82d9de4))
* **middleware:** implement request/response sanitization middleware ([ba70db3](https://github.com/andrewgibson-cic/slapenir/commit/ba70db39daa0ea08e3bf4d3b99bbf42a3084e4c3))
* **ops:** add environment management and unified control interface ([43f3e55](https://github.com/andrewgibson-cic/slapenir/commit/43f3e55bd312e69513d0563344e59508fa64a29a))
* **orchestration:** complete docker compose integration with all services ([a4f527e](https://github.com/andrewgibson-cic/slapenir/commit/a4f527efcf408304de5041d356dee08835afb364))
* **phase1:** begin Phase 1 - Identity & Foundation ([648a95e](https://github.com/andrewgibson-cic/slapenir/commit/648a95eeb31cde244399621c546663a83febd928))
* **phase2:** initialize Rust proxy with Axum server ([060a6d0](https://github.com/andrewgibson-cic/slapenir/commit/060a6d0ab3fbddeb61aa1f4f71ecca5c3461192c))
* **phase9:** complete strategy pattern integration and update docs ([220a96d](https://github.com/andrewgibson-cic/slapenir/commit/220a96d432d557c9911e1e440837103a41a43e67))
* **proxy,agent:** implement HTTP proxy handler and agent environment ([0d220e9](https://github.com/andrewgibson-cic/slapenir/commit/0d220e91eff5233f156605fd93b3e146bea464d5))
* **release:** automatically update version in Cargo.toml ([7b929c5](https://github.com/andrewgibson-cic/slapenir/commit/7b929c5617ad53061ac676442c5274a00b796364))
* **sanitizer:** implement Aho-Corasick credential sanitization engine ([8ca2cd8](https://github.com/andrewgibson-cic/slapenir/commit/8ca2cd8b03fa662797b0d7af0608c825c499f07f))


### Bug Fixes

* **agent:** install s6-overlay from GitHub releases for Wolfi compatibility ([ea61bcc](https://github.com/andrewgibson-cic/slapenir/commit/ea61bccefd3fae2761b788181b99cbd198350883))
* apply clippy linting fixes ([29e994b](https://github.com/andrewgibson-cic/slapenir/commit/29e994be994e4eafe24c3780a6c01a1a08472bba))
* correct volume mount path in Step-CA init script ([652f752](https://github.com/andrewgibson-cic/slapenir/commit/652f75219d283b4cb0376c28ad169359ba58a010))
* **mtls:** update to rustls 0.22 API and fix compilation errors ([4cdb447](https://github.com/andrewgibson-cic/slapenir/commit/4cdb447ad56c3323ef0ef9d97488fa48ab16e28d))
* **ops:** add execute permissions to all shell scripts ([37e056e](https://github.com/andrewgibson-cic/slapenir/commit/37e056eee3933b928fe96c98f07a1581789e162b))
* **ops:** remove process substitution from init-step-ca script ([59956e1](https://github.com/andrewgibson-cic/slapenir/commit/59956e1f4fdb2e48b25e5e32ed98c0e58d80e07e))
* properly export environment variables to s6 container environment ([694e787](https://github.com/andrewgibson-cic/slapenir/commit/694e7871c6e8c778a59a9940607bff088bec5cc8))
* **proxy:** bind to 0.0.0.0 instead of 127.0.0.1 for container networking ([462f4b9](https://github.com/andrewgibson-cic/slapenir/commit/462f4b9cad1046072760ba3e7cfdfca1bef71c25))
* update actions/upload-artifact from v3 to v4 ([45f43a5](https://github.com/andrewgibson-cic/slapenir/commit/45f43a5403b164491047f89456d2f4e2bd266727))
* update test-system.sh to reference docs/PROGRESS.md ([aecb772](https://github.com/andrewgibson-cic/slapenir/commit/aecb7725b55da15a7b53242d8a4cf87035fdb8c4))


### Code Refactoring

* migrate agent from zsh to bash with auto-loaded environment ([dab0daf](https://github.com/andrewgibson-cic/slapenir/commit/dab0daf1473ff5ff7d296fc12cf7bc77991ba416))


### Documentation

* add CI/CD workflow and update README with test coverage ([86af578](https://github.com/andrewgibson-cic/slapenir/commit/86af578a5ddfec5af9421d2868acd4ad07e05349))
* add comprehensive mTLS setup guide ([fc5bd27](https://github.com/andrewgibson-cic/slapenir/commit/fc5bd27a7fe347b4044cdb6b8c121d7b4691ef70))
* add comprehensive README and system validation script ([53388f8](https://github.com/andrewgibson-cic/slapenir/commit/53388f80f3fca3aaa59a51b70e3d8fc2d4fbbb06))
* add comprehensive security audit report ([1d744e9](https://github.com/andrewgibson-cic/slapenir/commit/1d744e989c6b00acd10e274b9ae2da83e1da3b3f))
* add comprehensive test coverage report and update progress ([a4b2ff5](https://github.com/andrewgibson-cic/slapenir/commit/a4b2ff5df46557b857a1520e9e1af5d01f86ec23))
* add next steps guide and finalize all documentation ([26deec9](https://github.com/andrewgibson-cic/slapenir/commit/26deec95ac217953cc1e42a759385020be4330ca))
* add version history section to README ([ea011c2](https://github.com/andrewgibson-cic/slapenir/commit/ea011c2109b4429d4a6527b128cfcd252fdd086c))
* organize documentation and update gitignore ([fc66aa5](https://github.com/andrewgibson-cic/slapenir/commit/fc66aa529efd5be4b180e26da9778c8417e24e87))
* **readme:** add comprehensive Git credentials and make commands sections ([2fe7956](https://github.com/andrewgibson-cic/slapenir/commit/2fe7956facb588a6b81ff3de11fcb1d639749106))
* **readme:** add comprehensive Make commands and Git credentials sections ([3e12ae5](https://github.com/andrewgibson-cic/slapenir/commit/3e12ae50154cff8b8abe45f40c0ea7df3177ce06))
* **readme:** remove reference to non-existent QUICKSTART.md ([b7a8a7f](https://github.com/andrewgibson-cic/slapenir/commit/b7a8a7f15d3842dedb651757d1f4cb6d0178a6aa))
* update documentation to reflect Phase 2 progress ([6d0e0e7](https://github.com/andrewgibson-cic/slapenir/commit/6d0e0e7d464368c0d21fac6c7c3a9794ac49e93a))
* update PROGRESS.md with complete Phase 4 mTLS implementation ([0fd5225](https://github.com/andrewgibson-cic/slapenir/commit/0fd52252df7649603df0ed54a2a206b06d3be4cd))
* update PROGRESS.md with metrics instrumentation completion ([8684b74](https://github.com/andrewgibson-cic/slapenir/commit/8684b74cb1bb916a991f9019d8ba564c272751d6))
* update README.md to reflect 95% project completion ([70670eb](https://github.com/andrewgibson-cic/slapenir/commit/70670ebac10b9056f375fdfbd46a4d29e48a95f5))

## 1.0.0 (2026-02-04)


### ⚠ BREAKING CHANGES

* **ops:** Environment variables now loaded from .env file instead of shell export

### Features

* add mTLS module for mutual TLS authentication ([382760e](https://github.com/andrewgibson-cic/slapenir/commit/382760e7129327a97e9f8b5d6cac0258d1e61f05))
* add mTLS support to docker-compose and testing scripts ([b37d852](https://github.com/andrewgibson-cic/slapenir/commit/b37d85233901d7b7b6db18d3c52a46d459a2492b))
* add Python mTLS client for agent ([a27c3a7](https://github.com/andrewgibson-cic/slapenir/commit/a27c3a74a761deefddbbfeefe1c3a729bff449a8))
* **agent:** add secure Git credentials via PATs ([8b4904e](https://github.com/andrewgibson-cic/slapenir/commit/8b4904e9b5b713d5f0437dc56e084b372f71a891))
* Complete Phase 3 TLS MITM implementation + build fixes ([ad96279](https://github.com/andrewgibson-cic/slapenir/commit/ad962795fc367309032e48bb0609806272bf8078))
* integrate mTLS support into proxy main ([82a6533](https://github.com/andrewgibson-cic/slapenir/commit/82a6533372d6c0b19e52bf61465948cf832587bf))
* make dummy environment variables accessible via shell ([83966bd](https://github.com/andrewgibson-cic/slapenir/commit/83966bd8a8846445959ad02510902d70f7f3bab9))
* **metrics:** instrument proxy and sanitizer with Prometheus metrics ([0b2b763](https://github.com/andrewgibson-cic/slapenir/commit/0b2b763c58f7195312c338787eacdb9fa82d9de4))
* **middleware:** implement request/response sanitization middleware ([ba70db3](https://github.com/andrewgibson-cic/slapenir/commit/ba70db39daa0ea08e3bf4d3b99bbf42a3084e4c3))
* **ops:** add environment management and unified control interface ([43f3e55](https://github.com/andrewgibson-cic/slapenir/commit/43f3e55bd312e69513d0563344e59508fa64a29a))
* **orchestration:** complete docker compose integration with all services ([a4f527e](https://github.com/andrewgibson-cic/slapenir/commit/a4f527efcf408304de5041d356dee08835afb364))
* **phase1:** begin Phase 1 - Identity & Foundation ([648a95e](https://github.com/andrewgibson-cic/slapenir/commit/648a95eeb31cde244399621c546663a83febd928))
* **phase2:** initialize Rust proxy with Axum server ([060a6d0](https://github.com/andrewgibson-cic/slapenir/commit/060a6d0ab3fbddeb61aa1f4f71ecca5c3461192c))
* **phase9:** complete strategy pattern integration and update docs ([220a96d](https://github.com/andrewgibson-cic/slapenir/commit/220a96d432d557c9911e1e440837103a41a43e67))
* **proxy,agent:** implement HTTP proxy handler and agent environment ([0d220e9](https://github.com/andrewgibson-cic/slapenir/commit/0d220e91eff5233f156605fd93b3e146bea464d5))
* **release:** automatically update version in Cargo.toml ([7b929c5](https://github.com/andrewgibson-cic/slapenir/commit/7b929c5617ad53061ac676442c5274a00b796364))
* **sanitizer:** implement Aho-Corasick credential sanitization engine ([8ca2cd8](https://github.com/andrewgibson-cic/slapenir/commit/8ca2cd8b03fa662797b0d7af0608c825c499f07f))


### Bug Fixes

* **agent:** install s6-overlay from GitHub releases for Wolfi compatibility ([ea61bcc](https://github.com/andrewgibson-cic/slapenir/commit/ea61bccefd3fae2761b788181b99cbd198350883))
* apply clippy linting fixes ([29e994b](https://github.com/andrewgibson-cic/slapenir/commit/29e994be994e4eafe24c3780a6c01a1a08472bba))
* correct volume mount path in Step-CA init script ([652f752](https://github.com/andrewgibson-cic/slapenir/commit/652f75219d283b4cb0376c28ad169359ba58a010))
* **mtls:** update to rustls 0.22 API and fix compilation errors ([4cdb447](https://github.com/andrewgibson-cic/slapenir/commit/4cdb447ad56c3323ef0ef9d97488fa48ab16e28d))
* **ops:** add execute permissions to all shell scripts ([37e056e](https://github.com/andrewgibson-cic/slapenir/commit/37e056eee3933b928fe96c98f07a1581789e162b))
* **ops:** remove process substitution from init-step-ca script ([59956e1](https://github.com/andrewgibson-cic/slapenir/commit/59956e1f4fdb2e48b25e5e32ed98c0e58d80e07e))
* properly export environment variables to s6 container environment ([694e787](https://github.com/andrewgibson-cic/slapenir/commit/694e7871c6e8c778a59a9940607bff088bec5cc8))
* **proxy:** bind to 0.0.0.0 instead of 127.0.0.1 for container networking ([462f4b9](https://github.com/andrewgibson-cic/slapenir/commit/462f4b9cad1046072760ba3e7cfdfca1bef71c25))
* update actions/upload-artifact from v3 to v4 ([45f43a5](https://github.com/andrewgibson-cic/slapenir/commit/45f43a5403b164491047f89456d2f4e2bd266727))
* update test-system.sh to reference docs/PROGRESS.md ([aecb772](https://github.com/andrewgibson-cic/slapenir/commit/aecb7725b55da15a7b53242d8a4cf87035fdb8c4))


### Code Refactoring

* migrate agent from zsh to bash with auto-loaded environment ([dab0daf](https://github.com/andrewgibson-cic/slapenir/commit/dab0daf1473ff5ff7d296fc12cf7bc77991ba416))


### Documentation

* add CI/CD workflow and update README with test coverage ([86af578](https://github.com/andrewgibson-cic/slapenir/commit/86af578a5ddfec5af9421d2868acd4ad07e05349))
* add comprehensive mTLS setup guide ([fc5bd27](https://github.com/andrewgibson-cic/slapenir/commit/fc5bd27a7fe347b4044cdb6b8c121d7b4691ef70))
* add comprehensive README and system validation script ([53388f8](https://github.com/andrewgibson-cic/slapenir/commit/53388f80f3fca3aaa59a51b70e3d8fc2d4fbbb06))
* add comprehensive security audit report ([1d744e9](https://github.com/andrewgibson-cic/slapenir/commit/1d744e989c6b00acd10e274b9ae2da83e1da3b3f))
* add comprehensive test coverage report and update progress ([a4b2ff5](https://github.com/andrewgibson-cic/slapenir/commit/a4b2ff5df46557b857a1520e9e1af5d01f86ec23))
* add next steps guide and finalize all documentation ([26deec9](https://github.com/andrewgibson-cic/slapenir/commit/26deec95ac217953cc1e42a759385020be4330ca))
* organize documentation and update gitignore ([fc66aa5](https://github.com/andrewgibson-cic/slapenir/commit/fc66aa529efd5be4b180e26da9778c8417e24e87))
* **readme:** add comprehensive Git credentials and make commands sections ([2fe7956](https://github.com/andrewgibson-cic/slapenir/commit/2fe7956facb588a6b81ff3de11fcb1d639749106))
* **readme:** add comprehensive Make commands and Git credentials sections ([3e12ae5](https://github.com/andrewgibson-cic/slapenir/commit/3e12ae50154cff8b8abe45f40c0ea7df3177ce06))
* **readme:** remove reference to non-existent QUICKSTART.md ([b7a8a7f](https://github.com/andrewgibson-cic/slapenir/commit/b7a8a7f15d3842dedb651757d1f4cb6d0178a6aa))
* update documentation to reflect Phase 2 progress ([6d0e0e7](https://github.com/andrewgibson-cic/slapenir/commit/6d0e0e7d464368c0d21fac6c7c3a9794ac49e93a))
* update PROGRESS.md with complete Phase 4 mTLS implementation ([0fd5225](https://github.com/andrewgibson-cic/slapenir/commit/0fd52252df7649603df0ed54a2a206b06d3be4cd))
* update PROGRESS.md with metrics instrumentation completion ([8684b74](https://github.com/andrewgibson-cic/slapenir/commit/8684b74cb1bb916a991f9019d8ba564c272751d6))
* update README.md to reflect 95% project completion ([70670eb](https://github.com/andrewgibson-cic/slapenir/commit/70670ebac10b9056f375fdfbd46a4d29e48a95f5))

## 1.0.0 (2026-02-02)


### ⚠ BREAKING CHANGES

* **ops:** Environment variables now loaded from .env file instead of shell export

### Features

* add mTLS module for mutual TLS authentication ([382760e](https://github.com/andrewgibson-cic/slapenir/commit/382760e7129327a97e9f8b5d6cac0258d1e61f05))
* add mTLS support to docker-compose and testing scripts ([b37d852](https://github.com/andrewgibson-cic/slapenir/commit/b37d85233901d7b7b6db18d3c52a46d459a2492b))
* add Python mTLS client for agent ([a27c3a7](https://github.com/andrewgibson-cic/slapenir/commit/a27c3a74a761deefddbbfeefe1c3a729bff449a8))
* **agent:** add secure Git credentials via PATs ([8b4904e](https://github.com/andrewgibson-cic/slapenir/commit/8b4904e9b5b713d5f0437dc56e084b372f71a891))
* integrate mTLS support into proxy main ([82a6533](https://github.com/andrewgibson-cic/slapenir/commit/82a6533372d6c0b19e52bf61465948cf832587bf))
* **metrics:** instrument proxy and sanitizer with Prometheus metrics ([0b2b763](https://github.com/andrewgibson-cic/slapenir/commit/0b2b763c58f7195312c338787eacdb9fa82d9de4))
* **middleware:** implement request/response sanitization middleware ([ba70db3](https://github.com/andrewgibson-cic/slapenir/commit/ba70db39daa0ea08e3bf4d3b99bbf42a3084e4c3))
* **ops:** add environment management and unified control interface ([43f3e55](https://github.com/andrewgibson-cic/slapenir/commit/43f3e55bd312e69513d0563344e59508fa64a29a))
* **orchestration:** complete docker compose integration with all services ([a4f527e](https://github.com/andrewgibson-cic/slapenir/commit/a4f527efcf408304de5041d356dee08835afb364))
* **phase1:** begin Phase 1 - Identity & Foundation ([648a95e](https://github.com/andrewgibson-cic/slapenir/commit/648a95eeb31cde244399621c546663a83febd928))
* **phase2:** initialize Rust proxy with Axum server ([060a6d0](https://github.com/andrewgibson-cic/slapenir/commit/060a6d0ab3fbddeb61aa1f4f71ecca5c3461192c))
* **phase9:** complete strategy pattern integration and update docs ([220a96d](https://github.com/andrewgibson-cic/slapenir/commit/220a96d432d557c9911e1e440837103a41a43e67))
* **proxy,agent:** implement HTTP proxy handler and agent environment ([0d220e9](https://github.com/andrewgibson-cic/slapenir/commit/0d220e91eff5233f156605fd93b3e146bea464d5))
* **release:** automatically update version in Cargo.toml ([7b929c5](https://github.com/andrewgibson-cic/slapenir/commit/7b929c5617ad53061ac676442c5274a00b796364))
* **sanitizer:** implement Aho-Corasick credential sanitization engine ([8ca2cd8](https://github.com/andrewgibson-cic/slapenir/commit/8ca2cd8b03fa662797b0d7af0608c825c499f07f))


### Bug Fixes

* **agent:** install s6-overlay from GitHub releases for Wolfi compatibility ([ea61bcc](https://github.com/andrewgibson-cic/slapenir/commit/ea61bccefd3fae2761b788181b99cbd198350883))
* correct volume mount path in Step-CA init script ([652f752](https://github.com/andrewgibson-cic/slapenir/commit/652f75219d283b4cb0376c28ad169359ba58a010))
* **mtls:** update to rustls 0.22 API and fix compilation errors ([4cdb447](https://github.com/andrewgibson-cic/slapenir/commit/4cdb447ad56c3323ef0ef9d97488fa48ab16e28d))
* **ops:** add execute permissions to all shell scripts ([37e056e](https://github.com/andrewgibson-cic/slapenir/commit/37e056eee3933b928fe96c98f07a1581789e162b))
* **ops:** remove process substitution from init-step-ca script ([59956e1](https://github.com/andrewgibson-cic/slapenir/commit/59956e1f4fdb2e48b25e5e32ed98c0e58d80e07e))
* **proxy:** bind to 0.0.0.0 instead of 127.0.0.1 for container networking ([462f4b9](https://github.com/andrewgibson-cic/slapenir/commit/462f4b9cad1046072760ba3e7cfdfca1bef71c25))
* update actions/upload-artifact from v3 to v4 ([45f43a5](https://github.com/andrewgibson-cic/slapenir/commit/45f43a5403b164491047f89456d2f4e2bd266727))
* update test-system.sh to reference docs/PROGRESS.md ([aecb772](https://github.com/andrewgibson-cic/slapenir/commit/aecb7725b55da15a7b53242d8a4cf87035fdb8c4))


### Code Refactoring

* migrate agent from zsh to bash with auto-loaded environment ([dab0daf](https://github.com/andrewgibson-cic/slapenir/commit/dab0daf1473ff5ff7d296fc12cf7bc77991ba416))


### Documentation

* add CI/CD workflow and update README with test coverage ([86af578](https://github.com/andrewgibson-cic/slapenir/commit/86af578a5ddfec5af9421d2868acd4ad07e05349))
* add comprehensive mTLS setup guide ([fc5bd27](https://github.com/andrewgibson-cic/slapenir/commit/fc5bd27a7fe347b4044cdb6b8c121d7b4691ef70))
* add comprehensive README and system validation script ([53388f8](https://github.com/andrewgibson-cic/slapenir/commit/53388f80f3fca3aaa59a51b70e3d8fc2d4fbbb06))
* add comprehensive test coverage report and update progress ([a4b2ff5](https://github.com/andrewgibson-cic/slapenir/commit/a4b2ff5df46557b857a1520e9e1af5d01f86ec23))
* add next steps guide and finalize all documentation ([26deec9](https://github.com/andrewgibson-cic/slapenir/commit/26deec95ac217953cc1e42a759385020be4330ca))
* organize documentation and update gitignore ([fc66aa5](https://github.com/andrewgibson-cic/slapenir/commit/fc66aa529efd5be4b180e26da9778c8417e24e87))
* **readme:** add comprehensive Git credentials and make commands sections ([2fe7956](https://github.com/andrewgibson-cic/slapenir/commit/2fe7956facb588a6b81ff3de11fcb1d639749106))
* **readme:** add comprehensive Make commands and Git credentials sections ([3e12ae5](https://github.com/andrewgibson-cic/slapenir/commit/3e12ae50154cff8b8abe45f40c0ea7df3177ce06))
* **readme:** remove reference to non-existent QUICKSTART.md ([b7a8a7f](https://github.com/andrewgibson-cic/slapenir/commit/b7a8a7f15d3842dedb651757d1f4cb6d0178a6aa))
* update documentation to reflect Phase 2 progress ([6d0e0e7](https://github.com/andrewgibson-cic/slapenir/commit/6d0e0e7d464368c0d21fac6c7c3a9794ac49e93a))
* update PROGRESS.md with complete Phase 4 mTLS implementation ([0fd5225](https://github.com/andrewgibson-cic/slapenir/commit/0fd52252df7649603df0ed54a2a206b06d3be4cd))
* update PROGRESS.md with metrics instrumentation completion ([8684b74](https://github.com/andrewgibson-cic/slapenir/commit/8684b74cb1bb916a991f9019d8ba564c272751d6))
* update README.md to reflect 95% project completion ([70670eb](https://github.com/andrewgibson-cic/slapenir/commit/70670ebac10b9056f375fdfbd46a4d29e48a95f5))

## 1.0.0 (2026-02-01)


### ⚠ BREAKING CHANGES

* **ops:** Environment variables now loaded from .env file instead of shell export

### Features

* add mTLS module for mutual TLS authentication ([f523de5](https://github.com/andrewgibson-cic/slapenir/commit/f523de5f9f755d9c0d3570c909a93b495903a3b6))
* add mTLS support to docker-compose and testing scripts ([5720c06](https://github.com/andrewgibson-cic/slapenir/commit/5720c069cf1e7c57cd62e35a2723ef59bafa159c))
* add Python mTLS client for agent ([b362ef3](https://github.com/andrewgibson-cic/slapenir/commit/b362ef32a06871d5e569fa49ae07354d62638801))
* **agent:** add secure Git credentials via PATs ([c48d99f](https://github.com/andrewgibson-cic/slapenir/commit/c48d99f743a24cf285f7d65ed36f8423d96b8cd8))
* integrate mTLS support into proxy main ([ba3394f](https://github.com/andrewgibson-cic/slapenir/commit/ba3394fc66a9df44767ce487169bf34e93413ad5))
* **metrics:** instrument proxy and sanitizer with Prometheus metrics ([d6b960b](https://github.com/andrewgibson-cic/slapenir/commit/d6b960b2d07ffc5f9a3a7fa1e8cb03cc0ba1636d))
* **middleware:** implement request/response sanitization middleware ([726b90a](https://github.com/andrewgibson-cic/slapenir/commit/726b90a128a24805bd0db68a28826f45d588796d))
* **ops:** add environment management and unified control interface ([ad663c7](https://github.com/andrewgibson-cic/slapenir/commit/ad663c7d0502b64c3992b20b79b38a18eb81a3b5))
* **orchestration:** complete docker compose integration with all services ([5436b20](https://github.com/andrewgibson-cic/slapenir/commit/5436b200e430ec321188a5027e99f9eaab9ace78))
* **phase1:** begin Phase 1 - Identity & Foundation ([b779d73](https://github.com/andrewgibson-cic/slapenir/commit/b779d7313af0c7385662156b19880281b57fae8a))
* **phase2:** initialize Rust proxy with Axum server ([f3c3021](https://github.com/andrewgibson-cic/slapenir/commit/f3c30212170d2115721eba5873f05411cb468f76))
* **phase9:** complete strategy pattern integration and update docs ([75afad7](https://github.com/andrewgibson-cic/slapenir/commit/75afad77bdbbef7cbb8387a3cd482898cd4349ed))
* **proxy,agent:** implement HTTP proxy handler and agent environment ([8eb1bb7](https://github.com/andrewgibson-cic/slapenir/commit/8eb1bb75a8178ae9e74dc0c29531849e39eaf5e8))
* **sanitizer:** implement Aho-Corasick credential sanitization engine ([0130183](https://github.com/andrewgibson-cic/slapenir/commit/0130183e21d3f52a0dd13688d11a11d5663b7ea4))


### Bug Fixes

* **agent:** install s6-overlay from GitHub releases for Wolfi compatibility ([11eb005](https://github.com/andrewgibson-cic/slapenir/commit/11eb0050d43c6be568b2f7cb573448054ba9c43b))
* correct volume mount path in Step-CA init script ([d3ac65c](https://github.com/andrewgibson-cic/slapenir/commit/d3ac65c63f7a62b5e7d7aa589642c18c087cf7b8))
* **mtls:** update to rustls 0.22 API and fix compilation errors ([ae1142d](https://github.com/andrewgibson-cic/slapenir/commit/ae1142d6015665590ad8d94d4843ca944f098212))
* **ops:** add execute permissions to all shell scripts ([f2dfcc9](https://github.com/andrewgibson-cic/slapenir/commit/f2dfcc9af0c59f881f775127eb9969251cde8f91))
* **ops:** remove process substitution from init-step-ca script ([1718c84](https://github.com/andrewgibson-cic/slapenir/commit/1718c844c11e864d64d8123fd5f8a7240a8cbd10))
* **proxy:** bind to 0.0.0.0 instead of 127.0.0.1 for container networking ([013632f](https://github.com/andrewgibson-cic/slapenir/commit/013632f37d301819f756b584d70e60abef10e030))
* update actions/upload-artifact from v3 to v4 ([94da6e7](https://github.com/andrewgibson-cic/slapenir/commit/94da6e786ca98a6ede69b21f53671c1d0dc63440))
* update test-system.sh to reference docs/PROGRESS.md ([5ced4f2](https://github.com/andrewgibson-cic/slapenir/commit/5ced4f276573cc1bc7347e4e7da45354e416f1c4))


### Code Refactoring

* migrate agent from zsh to bash with auto-loaded environment ([0047631](https://github.com/andrewgibson-cic/slapenir/commit/0047631ec79250c32cc2fef84c402df06fb492fd))


### Documentation

* add CI/CD workflow and update README with test coverage ([4ec1b00](https://github.com/andrewgibson-cic/slapenir/commit/4ec1b00f2f193318da97b0a7c8c72805ff9d887c))
* add comprehensive mTLS setup guide ([b9c5e85](https://github.com/andrewgibson-cic/slapenir/commit/b9c5e85611da71eb88fbd3fab0628e41090ee1d3))
* add comprehensive README and system validation script ([d3ee79a](https://github.com/andrewgibson-cic/slapenir/commit/d3ee79a8f85fd22bdd31ad3d1e124b3ab564591b))
* add comprehensive test coverage report and update progress ([3b0d993](https://github.com/andrewgibson-cic/slapenir/commit/3b0d993b6c70970b3f954565ea2ed16d5d2a59e2))
* add next steps guide and finalize all documentation ([efe1c99](https://github.com/andrewgibson-cic/slapenir/commit/efe1c9911457f66d8510a89e18c5b7e326237205))
* organize documentation and update gitignore ([8aea2a3](https://github.com/andrewgibson-cic/slapenir/commit/8aea2a32b283a76602184dc2cb14a0a5bf1423b3))
* **readme:** add comprehensive Git credentials and make commands sections ([0f70891](https://github.com/andrewgibson-cic/slapenir/commit/0f7089105ea8acba56df3f482132bab064f1367c))
* **readme:** add comprehensive Make commands and Git credentials sections ([bc33de8](https://github.com/andrewgibson-cic/slapenir/commit/bc33de8b65eab3b33c094a7487c1033904997d69))
* **readme:** remove reference to non-existent QUICKSTART.md ([034ff23](https://github.com/andrewgibson-cic/slapenir/commit/034ff230240d7fde68766663baf95e3faa38234b))
* update documentation to reflect Phase 2 progress ([a2abb66](https://github.com/andrewgibson-cic/slapenir/commit/a2abb66aa41e672a77c9ee8a57c4b3928d765340))
* update PROGRESS.md with complete Phase 4 mTLS implementation ([ca4f5ee](https://github.com/andrewgibson-cic/slapenir/commit/ca4f5eeed2334b85245aae0f47e18b418b4065d4))
* update PROGRESS.md with metrics instrumentation completion ([3dde80c](https://github.com/andrewgibson-cic/slapenir/commit/3dde80cbb1ed49fb8d496c0b46eb884caaef069e))
* update README.md to reflect 95% project completion ([d1d3a47](https://github.com/andrewgibson-cic/slapenir/commit/d1d3a4731c76463f97a4f19892971aa14b498f86))
