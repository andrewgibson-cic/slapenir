## [1.8.13](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.12...v1.8.13) (2026-03-29)


### Bug Fixes

* **axum:** update wildcard route syntax for axum 0.8 ([c2b6327](https://github.com/andrewgibson-cic/slapenir/commit/c2b6327fed5ddc2e9f3d0d8d30bf1e882e013b45))

## [1.8.12](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.11...v1.8.12) (2026-03-29)


### Bug Fixes

* **deps)(deps:** bump the production-dependencies group across 1 directory with 8 updates ([a73c457](https://github.com/andrewgibson-cic/slapenir/commit/a73c457f4019a65d8e08c77f4e7238e52e987ccf))
* **deps:** pin rcgen to 0.12 to avoid breaking API changes ([89def6d](https://github.com/andrewgibson-cic/slapenir/commit/89def6dfa790afb1477621049aabcbc781950c77))

## [1.8.11](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.10...v1.8.11) (2026-03-28)


### Bug Fixes

* **ci:** allow dependency-review to continue on error ([c265ab5](https://github.com/andrewgibson-cic/slapenir/commit/c265ab527cbca11a857b4eac8ae9b8c000dc8a6e))

## [1.8.10](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.9...v1.8.10) (2026-03-28)


### Bug Fixes

* **sanitizer:** support N:1 dummy-to-real credential mapping ([02430b1](https://github.com/andrewgibson-cic/slapenir/commit/02430b1060b7764a054c02c950ba3ee1fd66e799))

## [1.8.9](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.8...v1.8.9) (2026-03-28)


### Bug Fixes

* **ci:** add certificate creation and health checks to load-tests job ([c771009](https://github.com/andrewgibson-cic/slapenir/commit/c771009e2e1082c82954ba5e562f5d44191ba936))

## [1.8.8](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.7...v1.8.8) (2026-03-28)


### Bug Fixes

* **ci:** add missing POSTGRES_PASSWORD to load-tests job ([3244431](https://github.com/andrewgibson-cic/slapenir/commit/3244431f558b8644a1497f3c03d69a9e6b748829))

## [1.8.7](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.6...v1.8.7) (2026-03-28)


### Bug Fixes

* **ci:** add proxy logging for debugging ([dca4a67](https://github.com/andrewgibson-cic/slapenir/commit/dca4a67f012df1cd9bfee0b5410a38120db1dfae))
* **ci:** create dummy certificates for proxy in CI ([2825959](https://github.com/andrewgibson-cic/slapenir/commit/28259596312148fbca56f8437231671994dbbb8b))

## [1.8.6](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.5...v1.8.6) (2026-03-28)


### Bug Fixes

* **ci:** disable proxy for Docker image pulls in CI ([6aaa705](https://github.com/andrewgibson-cic/slapenir/commit/6aaa7051261187b670a1c61d77b280b5eb2b846d))

## [1.8.5](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.4...v1.8.5) (2026-03-28)


### Bug Fixes

* **ci:** add dummy SSH_AUTH_SOCK for docker compose validation ([5e67e94](https://github.com/andrewgibson-cic/slapenir/commit/5e67e9475915d17d34e7bfe6dd34a0a0a7c19c9b))


### Documentation

* update README and security documentation with comprehensive setup instructions ([ee6a921](https://github.com/andrewgibson-cic/slapenir/commit/ee6a92172dd3ee7ab2628a118a99318e54a29ebf))

## [1.8.4](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.3...v1.8.4) (2026-03-27)


### Bug Fixes

* **ci:** add required passwords for docker compose in CI ([a19e225](https://github.com/andrewgibson-cic/slapenir/commit/a19e2253e2459540d3771a0a8e25ed9330b1aff4))

## [1.8.3](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.2...v1.8.3) (2026-03-27)


### Bug Fixes

* copy benches directory for Cargo manifest validation ([1bff3db](https://github.com/andrewgibson-cic/slapenir/commit/1bff3db410859fcc94cb3ba84f3d1683fc9b571a))

## [1.8.2](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.1...v1.8.2) (2026-03-27)


### Bug Fixes

* build only binary in Docker, skip benchmarks ([668c389](https://github.com/andrewgibson-cic/slapenir/commit/668c38968f604a6190a1639a4b0c0d1d628d35ac))

## [1.8.1](https://github.com/andrewgibson-cic/slapenir/compare/v1.8.0...v1.8.1) (2026-03-27)


### Bug Fixes

* correct .env.example comment syntax for docker compose ([dd849cb](https://github.com/andrewgibson-cic/slapenir/commit/dd849cbfc799777f51c802828375441279111ca5))

## [1.7.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.6.0...v1.7.0) (2026-03-27)


### Features

* add build tool override env vars to make shell ([cd1bad2](https://github.com/andrewgibson-cic/slapenir/commit/cd1bad2c91c3322c6568fc303fee58369dc78991))
* add build tool security validation to startup checks ([de6d872](https://github.com/andrewgibson-cic/slapenir/commit/de6d872dc1363b5d90590590fb238d366fbca14d))
* add code-graph-rag integration ([5865a12](https://github.com/andrewgibson-cic/slapenir/commit/5865a1250ebaa43636334477a839479de98079ad))
* add comprehensive testing infrastructure for production readiness ([069a65d](https://github.com/andrewgibson-cic/slapenir/commit/069a65d8f9f9e4cbbf16cc7953a48a33e4ba8e08))
* Add host git/SSH/GPG config for agent container ([44e9a26](https://github.com/andrewgibson-cic/slapenir/commit/44e9a26ab3ca2a33e453189feea3247b1518f0c7))
* Add host git/SSH/GPG config for agent container ([fc33650](https://github.com/andrewgibson-cic/slapenir/commit/fc3365059a87757565c74b1763509c494c8892b9))
* add MCP memory and knowledge tools to slapenir agent ([3819c40](https://github.com/andrewgibson-cic/slapenir/commit/3819c407ad3fe311b5a9f7b723034d57d8f2cfc4))
* add session lock file to opencode-wrapper ([3a99148](https://github.com/andrewgibson-cic/slapenir/commit/3a991482e100b7d9e81e5f8f49f0ccdfe6a2a9ff))
* add SSH config init and update agent setup scripts ([ceba86e](https://github.com/andrewgibson-cic/slapenir/commit/ceba86e2d4d37f37bf0c960bfe151352323cbad3))
* complete code-graph-rag integration ([e5438bc](https://github.com/andrewgibson-cic/slapenir/commit/e5438bc27e3f5ad16a620ed157e73aabe61d71e7))
* complete MCP memory and knowledge integration ([5587caa](https://github.com/andrewgibson-cic/slapenir/commit/5587caae55f9697ddfe6e16b8664e408eea1efcc))
* configure MCP knowledge server for air-gapped operation ([09d40db](https://github.com/andrewgibson-cic/slapenir/commit/09d40db3289f73553025103281b2c81d72aa0eb7))
* implement build tool wrappers with OpenCode detection ([fa24ee2](https://github.com/andrewgibson-cic/slapenir/commit/fa24ee2ca5d828a24cfa7b5e1dd0c3a905a952d8))
* implement session-based logging with rotation ([d193d40](https://github.com/andrewgibson-cic/slapenir/commit/d193d40eb016c5f863310a134279d2ad695135eb))
* integrate build tool wrappers into Dockerfile ([cf3d550](https://github.com/andrewgibson-cic/slapenir/commit/cf3d550bbaa75874d8e8bc40ac7aebf9f4a928ea))


### Bug Fixes

* add HF_HUB_OFFLINE=1 for air-gapped operation ([4a8e51b](https://github.com/andrewgibson-cic/slapenir/commit/4a8e51bdfa7ad1319327c08948604b527aeb3200))
* add iptables flush to shell-raw and shell-unrestricted ([6d8dd86](https://github.com/andrewgibson-cic/slapenir/commit/6d8dd86a62368ca8c27a59972e268ae52a568bc8))
* Add loop-prevention instructions for OpenCode agent ([cb378cb](https://github.com/andrewgibson-cic/slapenir/commit/cb378cbeb252539b3596650d3822afe6eb913708))
* Add loop-prevention instructions for OpenCode agent ([4fac6c2](https://github.com/andrewgibson-cic/slapenir/commit/4fac6c249248f299c87e95ba7cfa299136495bd6))
* add opencode session logging to /var/log/slapenir ([eafa555](https://github.com/andrewgibson-cic/slapenir/commit/eafa55559347e8cb636767fc8900e20d436105ea))
* add shell-unrestricted command and create test script ([8186079](https://github.com/andrewgibson-cic/slapenir/commit/8186079e7c7cb471a6b126680256bee11247567a))
* add shell-unrestricted command for direct internet access ([ff46bd1](https://github.com/andrewgibson-cic/slapenir/commit/ff46bd1b0e2e15077d8ff537213073cf210ccc8c))
* Agent container user and permissions improvements ([642b178](https://github.com/andrewgibson-cic/slapenir/commit/642b178c4efd6503567346058d25fd40103062df))
* **ci:** enable git credentials for semantic-release ([8f35f07](https://github.com/andrewgibson-cic/slapenir/commit/8f35f0770a5119b3b2e1841a84d3b78005033b81))
* **ci:** remove incomplete 'Upload test results' step blocking all workflows ([94c1d4d](https://github.com/andrewgibson-cic/slapenir/commit/94c1d4da7126269a415f4890b55f5e16f233712b))
* clean up setup-bashrc.sh and fix sed commands ([15de8bd](https://github.com/andrewgibson-cic/slapenir/commit/15de8bdb5e974b3c512b5c328d1a71eecafdc343))
* configure MCP knowledge server env vars for correct paths ([a99078b](https://github.com/andrewgibson-cic/slapenir/commit/a99078bd80d01a961f098d63037c8a08d041fd79))
* convert cgr-index to executable wrapper script ([f9c1609](https://github.com/andrewgibson-cic/slapenir/commit/f9c1609ff069969b0d3860ada662760441cc533a))
* **deps:** bump dependencies ([f49774e](https://github.com/andrewgibson-cic/slapenir/commit/f49774e6187dfe3e317d40c159ab5a12d30b65a5))
* Enable bash access for OpenCode agent with permission prompt ([7c28219](https://github.com/andrewgibson-cic/slapenir/commit/7c28219819d097ddc34c347a283d51e87d49ffcb))
* enable build tool execution with ALLOW_BUILD permission syntax ([8a73437](https://github.com/andrewgibson-cic/slapenir/commit/8a734372141f2316036fbc35adc7b317d6970a92))
* flush NAT table rules in shell-unrestricted for full network access ([ece9c43](https://github.com/andrewgibson-cic/slapenir/commit/ece9c4300bd5f2f7104848b45c79d2355d3676d2))
* improve singleton pattern and add workspace permission fix ([1c4b47b](https://github.com/andrewgibson-cic/slapenir/commit/1c4b47b43cf42fc93de5d099a4a759970cb78cb0))
* mount opencode.json as volume and remove orphan containers on down ([5d91fa2](https://github.com/andrewgibson-cic/slapenir/commit/5d91fa23c0d84b440b9c750a2411b55142c0bcb5))
* nest bash commands under bash key in opencode.json permissions ([2c0209b](https://github.com/andrewgibson-cic/slapenir/commit/2c0209bf11c15fc1af65fd8bb2b3801cd5ea7d85))
* override gradle.properties proxy settings in shell-unrestricted ([2f6194e](https://github.com/andrewgibson-cic/slapenir/commit/2f6194e23b11ea54d2b839962035c38b03ed79e7))
* patch code-graph-rag tool descriptions ([fe0e680](https://github.com/andrewgibson-cic/slapenir/commit/fe0e68070a9b94114dd17cc88c3d9d830269367b))
* remove duplicate .env sourcing that breaks shell-unrestricted ([87d6fc2](https://github.com/andrewgibson-cic/slapenir/commit/87d6fc229e33c6390c28af13df2c9c958a1a74a7))
* remove duplicate label in docker-compose.yml mcp-knowledge-data volume ([152c441](https://github.com/andrewgibson-cic/slapenir/commit/152c44165ee5a6a880e112c1f4487d30c90f0dfc))
* resolve clippy error and improve python type hints ([0dcfd52](https://github.com/andrewgibson-cic/slapenir/commit/0dcfd5297677bd0715ffac0c12fdfd9e1379e371))
* resolve Dockerfile build issues and update opencode.json permissions ([a935c07](https://github.com/andrewgibson-cic/slapenir/commit/a935c07849e614c75ba1ad0a93ceda7496a09c16))
* update MCP config format for code-graph-rag and refactor build wrappers ([b9552b7](https://github.com/andrewgibson-cic/slapenir/commit/b9552b7841431719e792c55d9863a8085b6f8190))
* update rustls to 0.23 with ring provider ([4a471dc](https://github.com/andrewgibson-cic/slapenir/commit/4a471dc721d9aca6ef002b17e7a76816d00bad4c))
* Use AGENTS.md for OpenCode instructions (correct mechanism) ([0a9e74e](https://github.com/andrewgibson-cic/slapenir/commit/0a9e74eea4a7f09c553b073996e232d5c92abe6e))
* use all-MiniLM-L6-v2 model (no auth required) ([88f45c4](https://github.com/andrewgibson-cic/slapenir/commit/88f45c4038c1117a8e2aa863a2a92ba055018662))
* use sed to comment out gradle.properties proxy settings ([4f98b3f](https://github.com/andrewgibson-cic/slapenir/commit/4f98b3fa82e2711913cfa6064a525bfbde214685))


### Code Refactoring

* improve code quality and security ([3571eb7](https://github.com/andrewgibson-cic/slapenir/commit/3571eb7507ece92037b966a149f753f63a1984ac))
* remove Ollama/Aider and improve git configuration ([a3e3999](https://github.com/andrewgibson-cic/slapenir/commit/a3e3999ec9c836039cf0afaa979058d2683726b2))


### Documentation

* add build tool restrictions to AGENTS.md for OpenCode ([1e7e8d6](https://github.com/andrewgibson-cic/slapenir/commit/1e7e8d6f95a0c2956633f8359f653fcba8cba04b))
* add logging configuration documentation ([66b568a](https://github.com/andrewgibson-cic/slapenir/commit/66b568a723ad176e15d7c4bd8322a701ff283e4c))
* consolidate and update documentation ([3e47d85](https://github.com/andrewgibson-cic/slapenir/commit/3e47d85bf260d1b9d90f464ae019f71830c263b3))
* fix documentation inconsistencies ([2b792f2](https://github.com/andrewgibson-cic/slapenir/commit/2b792f237582d39d8739eb7c67183dafa96b33fb))
* Streamline README and remove redundant documentation ([97cc899](https://github.com/andrewgibson-cic/slapenir/commit/97cc899a3f2c155e6f5932bb4483b1c6c5e41a14))
* update all READMEs with MCP tools and Code-Graph-RAG ([cd27ae9](https://github.com/andrewgibson-cic/slapenir/commit/cd27ae9b85f037af8121c584cf226fad0f919276))

## [1.7.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.6.0...v1.7.0) (2026-03-27)


### Features

* add build tool override env vars to make shell ([cd1bad2](https://github.com/andrewgibson-cic/slapenir/commit/cd1bad2c91c3322c6568fc303fee58369dc78991))
* add build tool security validation to startup checks ([de6d872](https://github.com/andrewgibson-cic/slapenir/commit/de6d872dc1363b5d90590590fb238d366fbca14d))
* add code-graph-rag integration ([5865a12](https://github.com/andrewgibson-cic/slapenir/commit/5865a1250ebaa43636334477a839479de98079ad))
* add comprehensive testing infrastructure for production readiness ([069a65d](https://github.com/andrewgibson-cic/slapenir/commit/069a65d8f9f9e4cbbf16cc7953a48a33e4ba8e08))
* Add host git/SSH/GPG config for agent container ([44e9a26](https://github.com/andrewgibson-cic/slapenir/commit/44e9a26ab3ca2a33e453189feea3247b1518f0c7))
* Add host git/SSH/GPG config for agent container ([fc33650](https://github.com/andrewgibson-cic/slapenir/commit/fc3365059a87757565c74b1763509c494c8892b9))
* add MCP memory and knowledge tools to slapenir agent ([3819c40](https://github.com/andrewgibson-cic/slapenir/commit/3819c407ad3fe311b5a9f7b723034d57d8f2cfc4))
* add session lock file to opencode-wrapper ([3a99148](https://github.com/andrewgibson-cic/slapenir/commit/3a991482e100b7d9e81e5f8f49f0ccdfe6a2a9ff))
* add SSH config init and update agent setup scripts ([ceba86e](https://github.com/andrewgibson-cic/slapenir/commit/ceba86e2d4d37f37bf0c960bfe151352323cbad3))
* complete code-graph-rag integration ([e5438bc](https://github.com/andrewgibson-cic/slapenir/commit/e5438bc27e3f5ad16a620ed157e73aabe61d71e7))
* complete MCP memory and knowledge integration ([5587caa](https://github.com/andrewgibson-cic/slapenir/commit/5587caae55f9697ddfe6e16b8664e408eea1efcc))
* configure MCP knowledge server for air-gapped operation ([09d40db](https://github.com/andrewgibson-cic/slapenir/commit/09d40db3289f73553025103281b2c81d72aa0eb7))
* implement build tool wrappers with OpenCode detection ([fa24ee2](https://github.com/andrewgibson-cic/slapenir/commit/fa24ee2ca5d828a24cfa7b5e1dd0c3a905a952d8))
* implement session-based logging with rotation ([d193d40](https://github.com/andrewgibson-cic/slapenir/commit/d193d40eb016c5f863310a134279d2ad695135eb))
* integrate build tool wrappers into Dockerfile ([cf3d550](https://github.com/andrewgibson-cic/slapenir/commit/cf3d550bbaa75874d8e8bc40ac7aebf9f4a928ea))


### Bug Fixes

* add HF_HUB_OFFLINE=1 for air-gapped operation ([4a8e51b](https://github.com/andrewgibson-cic/slapenir/commit/4a8e51bdfa7ad1319327c08948604b527aeb3200))
* add iptables flush to shell-raw and shell-unrestricted ([6d8dd86](https://github.com/andrewgibson-cic/slapenir/commit/6d8dd86a62368ca8c27a59972e268ae52a568bc8))
* Add loop-prevention instructions for OpenCode agent ([cb378cb](https://github.com/andrewgibson-cic/slapenir/commit/cb378cbeb252539b3596650d3822afe6eb913708))
* Add loop-prevention instructions for OpenCode agent ([4fac6c2](https://github.com/andrewgibson-cic/slapenir/commit/4fac6c249248f299c87e95ba7cfa299136495bd6))
* add opencode session logging to /var/log/slapenir ([eafa555](https://github.com/andrewgibson-cic/slapenir/commit/eafa55559347e8cb636767fc8900e20d436105ea))
* add shell-unrestricted command and create test script ([8186079](https://github.com/andrewgibson-cic/slapenir/commit/8186079e7c7cb471a6b126680256bee11247567a))
* add shell-unrestricted command for direct internet access ([ff46bd1](https://github.com/andrewgibson-cic/slapenir/commit/ff46bd1b0e2e15077d8ff537213073cf210ccc8c))
* Agent container user and permissions improvements ([642b178](https://github.com/andrewgibson-cic/slapenir/commit/642b178c4efd6503567346058d25fd40103062df))
* **ci:** enable git credentials for semantic-release ([8f35f07](https://github.com/andrewgibson-cic/slapenir/commit/8f35f0770a5119b3b2e1841a84d3b78005033b81))
* **ci:** remove incomplete 'Upload test results' step blocking all workflows ([94c1d4d](https://github.com/andrewgibson-cic/slapenir/commit/94c1d4da7126269a415f4890b55f5e16f233712b))
* clean up setup-bashrc.sh and fix sed commands ([15de8bd](https://github.com/andrewgibson-cic/slapenir/commit/15de8bdb5e974b3c512b5c328d1a71eecafdc343))
* configure MCP knowledge server env vars for correct paths ([a99078b](https://github.com/andrewgibson-cic/slapenir/commit/a99078bd80d01a961f098d63037c8a08d041fd79))
* convert cgr-index to executable wrapper script ([f9c1609](https://github.com/andrewgibson-cic/slapenir/commit/f9c1609ff069969b0d3860ada662760441cc533a))
* **deps:** bump dependencies ([f49774e](https://github.com/andrewgibson-cic/slapenir/commit/f49774e6187dfe3e317d40c159ab5a12d30b65a5))
* Enable bash access for OpenCode agent with permission prompt ([7c28219](https://github.com/andrewgibson-cic/slapenir/commit/7c28219819d097ddc34c347a283d51e87d49ffcb))
* enable build tool execution with ALLOW_BUILD permission syntax ([8a73437](https://github.com/andrewgibson-cic/slapenir/commit/8a734372141f2316036fbc35adc7b317d6970a92))
* flush NAT table rules in shell-unrestricted for full network access ([ece9c43](https://github.com/andrewgibson-cic/slapenir/commit/ece9c4300bd5f2f7104848b45c79d2355d3676d2))
* improve singleton pattern and add workspace permission fix ([1c4b47b](https://github.com/andrewgibson-cic/slapenir/commit/1c4b47b43cf42fc93de5d099a4a759970cb78cb0))
* mount opencode.json as volume and remove orphan containers on down ([5d91fa2](https://github.com/andrewgibson-cic/slapenir/commit/5d91fa23c0d84b440b9c750a2411b55142c0bcb5))
* nest bash commands under bash key in opencode.json permissions ([2c0209b](https://github.com/andrewgibson-cic/slapenir/commit/2c0209bf11c15fc1af65fd8bb2b3801cd5ea7d85))
* override gradle.properties proxy settings in shell-unrestricted ([2f6194e](https://github.com/andrewgibson-cic/slapenir/commit/2f6194e23b11ea54d2b839962035c38b03ed79e7))
* patch code-graph-rag tool descriptions ([fe0e680](https://github.com/andrewgibson-cic/slapenir/commit/fe0e68070a9b94114dd17cc88c3d9d830269367b))
* remove duplicate .env sourcing that breaks shell-unrestricted ([87d6fc2](https://github.com/andrewgibson-cic/slapenir/commit/87d6fc229e33c6390c28af13df2c9c958a1a74a7))
* remove duplicate label in docker-compose.yml mcp-knowledge-data volume ([152c441](https://github.com/andrewgibson-cic/slapenir/commit/152c44165ee5a6a880e112c1f4487d30c90f0dfc))
* resolve clippy error and improve python type hints ([0dcfd52](https://github.com/andrewgibson-cic/slapenir/commit/0dcfd5297677bd0715ffac0c12fdfd9e1379e371))
* resolve Dockerfile build issues and update opencode.json permissions ([a935c07](https://github.com/andrewgibson-cic/slapenir/commit/a935c07849e614c75ba1ad0a93ceda7496a09c16))
* update MCP config format for code-graph-rag and refactor build wrappers ([b9552b7](https://github.com/andrewgibson-cic/slapenir/commit/b9552b7841431719e792c55d9863a8085b6f8190))
* update rustls to 0.23 with ring provider ([4a471dc](https://github.com/andrewgibson-cic/slapenir/commit/4a471dc721d9aca6ef002b17e7a76816d00bad4c))
* Use AGENTS.md for OpenCode instructions (correct mechanism) ([0a9e74e](https://github.com/andrewgibson-cic/slapenir/commit/0a9e74eea4a7f09c553b073996e232d5c92abe6e))
* use all-MiniLM-L6-v2 model (no auth required) ([88f45c4](https://github.com/andrewgibson-cic/slapenir/commit/88f45c4038c1117a8e2aa863a2a92ba055018662))
* use sed to comment out gradle.properties proxy settings ([4f98b3f](https://github.com/andrewgibson-cic/slapenir/commit/4f98b3fa82e2711913cfa6064a525bfbde214685))


### Code Refactoring

* remove Ollama/Aider and improve git configuration ([a3e3999](https://github.com/andrewgibson-cic/slapenir/commit/a3e3999ec9c836039cf0afaa979058d2683726b2))


### Documentation

* add build tool restrictions to AGENTS.md for OpenCode ([1e7e8d6](https://github.com/andrewgibson-cic/slapenir/commit/1e7e8d6f95a0c2956633f8359f653fcba8cba04b))
* add logging configuration documentation ([66b568a](https://github.com/andrewgibson-cic/slapenir/commit/66b568a723ad176e15d7c4bd8322a701ff283e4c))
* consolidate and update documentation ([3e47d85](https://github.com/andrewgibson-cic/slapenir/commit/3e47d85bf260d1b9d90f464ae019f71830c263b3))
* fix documentation inconsistencies ([2b792f2](https://github.com/andrewgibson-cic/slapenir/commit/2b792f237582d39d8739eb7c67183dafa96b33fb))
* Streamline README and remove redundant documentation ([97cc899](https://github.com/andrewgibson-cic/slapenir/commit/97cc899a3f2c155e6f5932bb4483b1c6c5e41a14))
* update all READMEs with MCP tools and Code-Graph-RAG ([cd27ae9](https://github.com/andrewgibson-cic/slapenir/commit/cd27ae9b85f037af8121c584cf226fad0f919276))

## [1.7.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.6.0...v1.7.0) (2026-03-25)


### Features

* add build tool override env vars to make shell ([cd1bad2](https://github.com/andrewgibson-cic/slapenir/commit/cd1bad2c91c3322c6568fc303fee58369dc78991))
* add build tool security validation to startup checks ([de6d872](https://github.com/andrewgibson-cic/slapenir/commit/de6d872dc1363b5d90590590fb238d366fbca14d))
* add code-graph-rag integration ([5865a12](https://github.com/andrewgibson-cic/slapenir/commit/5865a1250ebaa43636334477a839479de98079ad))
* Add host git/SSH/GPG config for agent container ([44e9a26](https://github.com/andrewgibson-cic/slapenir/commit/44e9a26ab3ca2a33e453189feea3247b1518f0c7))
* Add host git/SSH/GPG config for agent container ([fc33650](https://github.com/andrewgibson-cic/slapenir/commit/fc3365059a87757565c74b1763509c494c8892b9))
* add MCP memory and knowledge tools to slapenir agent ([3819c40](https://github.com/andrewgibson-cic/slapenir/commit/3819c407ad3fe311b5a9f7b723034d57d8f2cfc4))
* add session lock file to opencode-wrapper ([3a99148](https://github.com/andrewgibson-cic/slapenir/commit/3a991482e100b7d9e81e5f8f49f0ccdfe6a2a9ff))
* add SSH config init and update agent setup scripts ([ceba86e](https://github.com/andrewgibson-cic/slapenir/commit/ceba86e2d4d37f37bf0c960bfe151352323cbad3))
* complete code-graph-rag integration ([e5438bc](https://github.com/andrewgibson-cic/slapenir/commit/e5438bc27e3f5ad16a620ed157e73aabe61d71e7))
* complete MCP memory and knowledge integration ([5587caa](https://github.com/andrewgibson-cic/slapenir/commit/5587caae55f9697ddfe6e16b8664e408eea1efcc))
* configure MCP knowledge server for air-gapped operation ([09d40db](https://github.com/andrewgibson-cic/slapenir/commit/09d40db3289f73553025103281b2c81d72aa0eb7))
* implement build tool wrappers with OpenCode detection ([fa24ee2](https://github.com/andrewgibson-cic/slapenir/commit/fa24ee2ca5d828a24cfa7b5e1dd0c3a905a952d8))
* implement session-based logging with rotation ([d193d40](https://github.com/andrewgibson-cic/slapenir/commit/d193d40eb016c5f863310a134279d2ad695135eb))
* integrate build tool wrappers into Dockerfile ([cf3d550](https://github.com/andrewgibson-cic/slapenir/commit/cf3d550bbaa75874d8e8bc40ac7aebf9f4a928ea))


### Bug Fixes

* add HF_HUB_OFFLINE=1 for air-gapped operation ([4a8e51b](https://github.com/andrewgibson-cic/slapenir/commit/4a8e51bdfa7ad1319327c08948604b527aeb3200))
* add iptables flush to shell-raw and shell-unrestricted ([6d8dd86](https://github.com/andrewgibson-cic/slapenir/commit/6d8dd86a62368ca8c27a59972e268ae52a568bc8))
* Add loop-prevention instructions for OpenCode agent ([cb378cb](https://github.com/andrewgibson-cic/slapenir/commit/cb378cbeb252539b3596650d3822afe6eb913708))
* Add loop-prevention instructions for OpenCode agent ([4fac6c2](https://github.com/andrewgibson-cic/slapenir/commit/4fac6c249248f299c87e95ba7cfa299136495bd6))
* add opencode session logging to /var/log/slapenir ([eafa555](https://github.com/andrewgibson-cic/slapenir/commit/eafa55559347e8cb636767fc8900e20d436105ea))
* add shell-unrestricted command and create test script ([8186079](https://github.com/andrewgibson-cic/slapenir/commit/8186079e7c7cb471a6b126680256bee11247567a))
* add shell-unrestricted command for direct internet access ([ff46bd1](https://github.com/andrewgibson-cic/slapenir/commit/ff46bd1b0e2e15077d8ff537213073cf210ccc8c))
* Agent container user and permissions improvements ([642b178](https://github.com/andrewgibson-cic/slapenir/commit/642b178c4efd6503567346058d25fd40103062df))
* **ci:** enable git credentials for semantic-release ([8f35f07](https://github.com/andrewgibson-cic/slapenir/commit/8f35f0770a5119b3b2e1841a84d3b78005033b81))
* **ci:** remove incomplete 'Upload test results' step blocking all workflows ([94c1d4d](https://github.com/andrewgibson-cic/slapenir/commit/94c1d4da7126269a415f4890b55f5e16f233712b))
* clean up setup-bashrc.sh and fix sed commands ([15de8bd](https://github.com/andrewgibson-cic/slapenir/commit/15de8bdb5e974b3c512b5c328d1a71eecafdc343))
* configure MCP knowledge server env vars for correct paths ([a99078b](https://github.com/andrewgibson-cic/slapenir/commit/a99078bd80d01a961f098d63037c8a08d041fd79))
* convert cgr-index to executable wrapper script ([f9c1609](https://github.com/andrewgibson-cic/slapenir/commit/f9c1609ff069969b0d3860ada662760441cc533a))
* **deps:** bump dependencies ([f49774e](https://github.com/andrewgibson-cic/slapenir/commit/f49774e6187dfe3e317d40c159ab5a12d30b65a5))
* Enable bash access for OpenCode agent with permission prompt ([7c28219](https://github.com/andrewgibson-cic/slapenir/commit/7c28219819d097ddc34c347a283d51e87d49ffcb))
* enable build tool execution with ALLOW_BUILD permission syntax ([8a73437](https://github.com/andrewgibson-cic/slapenir/commit/8a734372141f2316036fbc35adc7b317d6970a92))
* flush NAT table rules in shell-unrestricted for full network access ([ece9c43](https://github.com/andrewgibson-cic/slapenir/commit/ece9c4300bd5f2f7104848b45c79d2355d3676d2))
* improve singleton pattern and add workspace permission fix ([1c4b47b](https://github.com/andrewgibson-cic/slapenir/commit/1c4b47b43cf42fc93de5d099a4a759970cb78cb0))
* mount opencode.json as volume and remove orphan containers on down ([5d91fa2](https://github.com/andrewgibson-cic/slapenir/commit/5d91fa23c0d84b440b9c750a2411b55142c0bcb5))
* nest bash commands under bash key in opencode.json permissions ([2c0209b](https://github.com/andrewgibson-cic/slapenir/commit/2c0209bf11c15fc1af65fd8bb2b3801cd5ea7d85))
* override gradle.properties proxy settings in shell-unrestricted ([2f6194e](https://github.com/andrewgibson-cic/slapenir/commit/2f6194e23b11ea54d2b839962035c38b03ed79e7))
* patch code-graph-rag tool descriptions ([fe0e680](https://github.com/andrewgibson-cic/slapenir/commit/fe0e68070a9b94114dd17cc88c3d9d830269367b))
* remove duplicate .env sourcing that breaks shell-unrestricted ([87d6fc2](https://github.com/andrewgibson-cic/slapenir/commit/87d6fc229e33c6390c28af13df2c9c958a1a74a7))
* remove duplicate label in docker-compose.yml mcp-knowledge-data volume ([152c441](https://github.com/andrewgibson-cic/slapenir/commit/152c44165ee5a6a880e112c1f4487d30c90f0dfc))
* resolve Dockerfile build issues and update opencode.json permissions ([a935c07](https://github.com/andrewgibson-cic/slapenir/commit/a935c07849e614c75ba1ad0a93ceda7496a09c16))
* update MCP config format for code-graph-rag and refactor build wrappers ([b9552b7](https://github.com/andrewgibson-cic/slapenir/commit/b9552b7841431719e792c55d9863a8085b6f8190))
* update rustls to 0.23 with ring provider ([4a471dc](https://github.com/andrewgibson-cic/slapenir/commit/4a471dc721d9aca6ef002b17e7a76816d00bad4c))
* Use AGENTS.md for OpenCode instructions (correct mechanism) ([0a9e74e](https://github.com/andrewgibson-cic/slapenir/commit/0a9e74eea4a7f09c553b073996e232d5c92abe6e))
* use all-MiniLM-L6-v2 model (no auth required) ([88f45c4](https://github.com/andrewgibson-cic/slapenir/commit/88f45c4038c1117a8e2aa863a2a92ba055018662))
* use sed to comment out gradle.properties proxy settings ([4f98b3f](https://github.com/andrewgibson-cic/slapenir/commit/4f98b3fa82e2711913cfa6064a525bfbde214685))


### Code Refactoring

* remove Ollama/Aider and improve git configuration ([a3e3999](https://github.com/andrewgibson-cic/slapenir/commit/a3e3999ec9c836039cf0afaa979058d2683726b2))


### Documentation

* add build tool restrictions to AGENTS.md for OpenCode ([1e7e8d6](https://github.com/andrewgibson-cic/slapenir/commit/1e7e8d6f95a0c2956633f8359f653fcba8cba04b))
* add logging configuration documentation ([66b568a](https://github.com/andrewgibson-cic/slapenir/commit/66b568a723ad176e15d7c4bd8322a701ff283e4c))
* consolidate and update documentation ([3e47d85](https://github.com/andrewgibson-cic/slapenir/commit/3e47d85bf260d1b9d90f464ae019f71830c263b3))
* fix documentation inconsistencies ([2b792f2](https://github.com/andrewgibson-cic/slapenir/commit/2b792f237582d39d8739eb7c67183dafa96b33fb))
* Streamline README and remove redundant documentation ([97cc899](https://github.com/andrewgibson-cic/slapenir/commit/97cc899a3f2c155e6f5932bb4483b1c6c5e41a14))
* update all READMEs with MCP tools and Code-Graph-RAG ([cd27ae9](https://github.com/andrewgibson-cic/slapenir/commit/cd27ae9b85f037af8121c584cf226fad0f919276))

## [1.7.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.6.0...v1.7.0) (2026-03-03)


### Features

* Add host git/SSH/GPG config for agent container ([44e9a26](https://github.com/andrewgibson-cic/slapenir/commit/44e9a26ab3ca2a33e453189feea3247b1518f0c7))


### Bug Fixes

* Add loop-prevention instructions for OpenCode agent ([cb378cb](https://github.com/andrewgibson-cic/slapenir/commit/cb378cbeb252539b3596650d3822afe6eb913708))
* Agent container user and permissions improvements ([642b178](https://github.com/andrewgibson-cic/slapenir/commit/642b178c4efd6503567346058d25fd40103062df))
* Use AGENTS.md for OpenCode instructions (correct mechanism) ([0a9e74e](https://github.com/andrewgibson-cic/slapenir/commit/0a9e74eea4a7f09c553b073996e232d5c92abe6e))


### Documentation

* Streamline README and remove redundant documentation ([97cc899](https://github.com/andrewgibson-cic/slapenir/commit/97cc899a3f2c155e6f5932bb4483b1c6c5e41a14))

## [1.6.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.5.2...v1.6.0) (2026-03-02)


### Features

* Add comprehensive traffic enforcement tests to startup validation ([2b33c77](https://github.com/andrewgibson-cic/slapenir/commit/2b33c77f8d8f4609508579d91a6fce1f2ffa2ea6))


### Bug Fixes

* Correct traffic enforcement initialization for Wolfi container ([9f0c6e9](https://github.com/andrewgibson-cic/slapenir/commit/9f0c6e9880a711c6af8beeec7a924057fef578fd))
* Handle dmesg permission errors gracefully in runtime-monitor ([d2753a2](https://github.com/andrewgibson-cic/slapenir/commit/d2753a23f6033b757abdeea319575b5186833645))
* Route local LLM requests via Host header ([e1ad3b1](https://github.com/andrewgibson-cic/slapenir/commit/e1ad3b1a152375c6013d87751dbd875016ca1275))
* Update OpenCode config to use top-level model key ([a5d16aa](https://github.com/andrewgibson-cic/slapenir/commit/a5d16aa0d0170836f3d79d348124a9cdebf64fb5))

## [1.5.2](https://github.com/andrewgibson-cic/slapenir/compare/v1.5.1...v1.5.2) (2026-03-02)


### Bug Fixes

* Correct runtime-monitor run script for longrun service ([eb09e66](https://github.com/andrewgibson-cic/slapenir/commit/eb09e66c350b942d90343f8594cdadc7b3eb2048))

## [1.5.1](https://github.com/andrewgibson-cic/slapenir/compare/v1.5.0...v1.5.1) (2026-03-02)


### Bug Fixes

* Add traffic enforcement dependency to startup validation ([2d37690](https://github.com/andrewgibson-cic/slapenir/commit/2d3769007bedd64c04e20a2356a65556b5f9f6ea))
* fix/agent-connection-to-llama-server ([c44a272](https://github.com/andrewgibson-cic/slapenir/commit/c44a272e7b4ca4846b2a34615411d5383015f1dc))

## [1.5.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.4.0...v1.5.0) (2026-03-02)


### Features

* Enhanced security for internal:false with multi-layer protection ([d5b5a6e](https://github.com/andrewgibson-cic/slapenir/commit/d5b5a6e7ea7d826dd7ad1d0e527372d7f1c9b725))

## [1.4.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.3.0...v1.4.0) (2026-03-02)


### Features

* Add local LLM connectivity and network isolation tests to startup validation ([c20e094](https://github.com/andrewgibson-cic/slapenir/commit/c20e09472138be7b42b5f81b9189231e6024fe56))
* Set default provider and model for OpenCode ([7822105](https://github.com/andrewgibson-cic/slapenir/commit/782210568fc32117f15869b22c720056faf379fa))

## [1.3.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.2.3...v1.3.0) (2026-03-02)


### Features

* Add local LLM support with zero-trust network isolation ([76b7157](https://github.com/andrewgibson-cic/slapenir/commit/76b715789abdd4c55f478e7983ea9bc2f314d651))

## [1.2.3](https://github.com/andrewgibson-cic/slapenir/compare/v1.2.2...v1.2.3) (2026-03-02)


### Bug Fixes

* add proxy bypass for local llama server requests ([91276c0](https://github.com/andrewgibson-cic/slapenir/commit/91276c0ad518b8d245502819938c6bdd27a8ccf3))

## [1.2.2](https://github.com/andrewgibson-cic/slapenir/compare/v1.2.1...v1.2.2) (2026-03-02)


### Bug Fixes

* add proxy bypass for local llama server ([eeb8578](https://github.com/andrewgibson-cic/slapenir/commit/eeb85785033a137a2aff2cdec0a4f1ea75de9147))
* use correct opencode config path and enable OPENCODE_YOLO ([7b2a807](https://github.com/andrewgibson-cic/slapenir/commit/7b2a807264786a0ea32ae6c1ae6b8701de013218))

## [1.2.1](https://github.com/andrewgibson-cic/slapenir/compare/v1.2.0...v1.2.1) (2026-03-02)


### Bug Fixes

* resolve production readiness review issues ([ebd239e](https://github.com/andrewgibson-cic/slapenir/commit/ebd239ee5527220ec9f6510f522cf6011224e2f7))


### Code Refactoring

* remove aider-init service and update proxy configuration ([ecb50a0](https://github.com/andrewgibson-cic/slapenir/commit/ecb50a09ce7322a6edb3f1036a094879e5fad92d))

## [1.2.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.1.0...v1.2.0) (2026-03-02)


### Features

* add zero-leak local AI setup with OpenCode ([17a29ea](https://github.com/andrewgibson-cic/slapenir/commit/17a29eaf0971264606bb90492a41a56dd2ead65a))


### Bug Fixes

* add error handling and use env vars in traffic-enforcement.sh ([3ddc412](https://github.com/andrewgibson-cic/slapenir/commit/3ddc4128df2632afb590b728b01df1dc81f6e124))

## [1.1.0](https://github.com/andrewgibson-cic/slapenir/compare/v1.0.1...v1.1.0) (2026-02-24)


### Features

* **agent:** add Ollama local LLM support with Aider through proxy ([9496c75](https://github.com/andrewgibson-cic/slapenir/commit/9496c756a49c97677695cd9b9f8f2665b2c87d44))
* **auto-detect:** add PostgreSQL-based automatic secret detection ([32114fb](https://github.com/andrewgibson-cic/slapenir/commit/32114fbf2dc576863b54daf8558809db42fea890))
* **security:** add iptables-based traffic enforcement ([25d6660](https://github.com/andrewgibson-cic/slapenir/commit/25d6660e43cbc0f47ae039757cf02c95158d7147))


### Bug Fixes

* change network subnet from 172.21.0.0/24 to 172.30.0.0/24 to avoid conflict ([a7c8134](https://github.com/andrewgibson-cic/slapenir/commit/a7c8134fe1cc20cab7cacf71a50ca7fd52584e10))
* **ci:** add --force flag to cargo-audit install ([1c2c3f3](https://github.com/andrewgibson-cic/slapenir/commit/1c2c3f3475fdf849092f36667a11d9540ec61ae3))
* **ci:** add --ignore flags to cargo audit in test.yml and release.yml ([f694ce2](https://github.com/andrewgibson-cic/slapenir/commit/f694ce2308fa031df4e03a0b579bbcfede792146))
* **ci:** force cargo audit step to always succeed ([61be61f](https://github.com/andrewgibson-cic/slapenir/commit/61be61f912e382c3f1dc29299342d7e224e81e6f))
* **ci:** improve cargo audit with explicit ignores and debug output ([6ccecb5](https://github.com/andrewgibson-cic/slapenir/commit/6ccecb56529bd03d81b2d4c1df8afbdb096158e0))
* integrate auto-detection database into proxy startup ([3d6d7fd](https://github.com/andrewgibson-cic/slapenir/commit/3d6d7fdcf000b4314b2989aa7f2c2558e9e269b))
* only collect dummy patterns for strategies with real credentials ([a39c040](https://github.com/andrewgibson-cic/slapenir/commit/a39c0407635642976d032b2d538f71a696e0fb4a))
* **security:** add deny.toml to ignore RSA advisory in cargo-deny ([ff32eb7](https://github.com/andrewgibson-cic/slapenir/commit/ff32eb7a994d2873e8ae96e10ae9846bb06d6a34))
* **security:** resolve cargo audit vulnerabilities ([febe66b](https://github.com/andrewgibson-cic/slapenir/commit/febe66bf430169d570bb50e516f296e78575f040))
* **security:** resolve critical sanitization bypass vulnerabilities ([9e4a42b](https://github.com/andrewgibson-cic/slapenir/commit/9e4a42b04501eca81f73be7ead65b58085e8d256))
* use docker-compose (v1) instead of docker compose (v2) ([bf58fd8](https://github.com/andrewgibson-cic/slapenir/commit/bf58fd8a2c4a241002e035b9d87793ea88565c6b))


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
* **agent:** add secure Git credentials via PATs ([8b4904e](https://github.com/andrewgibson-cic/slapenir/commit/8b4904e9b5b713d5f0437dc56e084b372f71a89b))
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
* **ops:** remove process substitution from init-step-ca script ([59956e1](https://github.com/andrewgibson-cic/slapenir/commit/59956e1f4fdb2e48b25e5e32ed98c0e58d80e078))
* properly export environment variables to s6 container environment ([694e787](https://github.com/andrewgibson-cic/slapenir/commit/694e7871c6e8c778a59a9940607bff088bec5cc8))
* **proxy:** bind to 0.0.0.0 instead of 127.0.0.1 for container networking ([462f4b9](https://github.com/andrewgibson-cic/slapenir/commit/462f4b9cad1046072760ba3e7cfdfca1bef71c25))
* update actions/upload-artifact from v3 to v4 ([45f43a5](https://github.com/andrewgibson-cic/slapenir/commit/45f43a5403b164491047f89456d2f4e2bd266727))


### Code Refactoring

* migrate agent from zsh to bash with auto-loaded environment ([dab0daf](https://github.com/andrewgibson-cic/slapenir/commit/dab0daf1473ff5ff7d296fc12cf7bc77991ba416))


### Documentation

* add CI/CD workflow and update README with test coverage ([86af578](https://github.com/andrewgibson-cic/slapenir/commit/86af578a5ddfec5af9421d2868acd4ad07e05349))
* add comprehensive mTLS setup guide ([fc5bd27](https://github.com/andrewgibson-cic/slapenir/commit/fc5bd27a7fe347b4044cdb6b8c121d7b4691ef70))
* add comprehensive README and system validation script ([53388f8](https://github.com/andrewgibson-cic/slapenir/commit/53388f80f3fca3aaa59a51b70e3d8fc2d4fbbb06))
* organize documentation and update gitignore ([fc66aa5](https://github.com/andrewgibson-cic/slapenir/commit/fc66aa529efd5be4b180e26da9778c8417e24e87))
* update documentation to reflect Phase 2 progress ([6d0e0e7](https://github.com/andrewgibson-cic/slapenir/commit/6d0e0e7d464368c0d21fac6c7c3a9794ac49e93a))
