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
