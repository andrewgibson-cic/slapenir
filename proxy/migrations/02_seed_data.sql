-- SLAPENIR Auto-Detection Seed Data - 70+ API definitions

-- AI/LLM APIs
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('openai', 'OpenAI', 'OpenAI API for GPT models', 'ai_llm', ARRAY['OPENAI_API_KEY', 'OPENAI_TOKEN'], 'bearer', 'DUMMY_OPENAI', ARRAY['api.openai.com', '*.openai.com'], 'https://platform.openai.com/docs'),
('anthropic', 'Anthropic', 'Anthropic Claude API', 'ai_llm', ARRAY['ANTHROPIC_API_KEY', 'ANTHROPIC_TOKEN'], 'bearer', 'DUMMY_ANTHROPIC', ARRAY['api.anthropic.com', '*.anthropic.com'], 'https://docs.anthropic.com'),
('gemini', 'Google Gemini', 'Google Gemini API', 'ai_llm', ARRAY['GEMINI_API_KEY', 'GOOGLE_AI_KEY'], 'bearer', 'DUMMY_GEMINI', ARRAY['generativelanguage.googleapis.com', '*.googleapis.com'], 'https://ai.google.dev/docs'),
('mistral', 'Mistral AI', 'Mistral AI LLM API', 'ai_llm', ARRAY['MISTRAL_API_KEY'], 'bearer', 'DUMMY_MISTRAL', ARRAY['api.mistral.ai', '*.mistral.ai'], 'https://docs.mistral.ai'),
('cohere', 'Cohere', 'Cohere API', 'ai_llm', ARRAY['COHERE_API_KEY', 'CO_API_KEY'], 'bearer', 'DUMMY_COHERE', ARRAY['api.cohere.ai', '*.cohere.ai'], 'https://docs.cohere.com'),
('replicate', 'Replicate', 'Replicate AI models', 'ai_llm', ARRAY['REPLICATE_API_TOKEN', 'REPLICATE_API_KEY'], 'bearer', 'DUMMY_REPLICATE', ARRAY['api.replicate.com', '*.replicate.com'], 'https://replicate.com/docs'),
('huggingface', 'Hugging Face', 'Hugging Face inference API', 'ai_llm', ARRAY['HUGGINGFACE_TOKEN', 'HF_TOKEN'], 'bearer', 'DUMMY_HF', ARRAY['huggingface.co', '*.huggingface.co'], 'https://huggingface.co/docs'),
('perplexity', 'Perplexity AI', 'Perplexity search API', 'ai_llm', ARRAY['PERPLEXITY_API_KEY', 'PPLX_API_KEY'], 'bearer', 'DUMMY_PERPLEXITY', ARRAY['api.perplexity.ai', '*.perplexity.ai'], 'https://docs.perplexity.ai'),
('groq', 'Groq', 'Groq fast inference', 'ai_llm', ARRAY['GROQ_API_KEY'], 'bearer', 'DUMMY_GROQ', ARRAY['api.groq.com', '*.groq.com'], 'https://console.groq.com/docs'),
('deepseek', 'DeepSeek', 'DeepSeek AI API', 'ai_llm', ARRAY['DEEPSEEK_API_KEY'], 'bearer', 'DUMMY_DEEPSEEK', ARRAY['api.deepseek.com', '*.deepseek.com'], 'https://platform.deepseek.com/docs'),
('stability', 'Stability AI', 'Stability AI image generation', 'ai_llm', ARRAY['STABILITY_API_KEY'], 'bearer', 'DUMMY_STABILITY', ARRAY['api.stability.ai', '*.stability.ai'], 'https://platform.stability.ai/docs'),
('voyage', 'Voyage AI', 'Voyage embeddings', 'ai_llm', ARRAY['VOYAGE_API_KEY'], 'bearer', 'DUMMY_VOYAGE', ARRAY['api.voyageai.com', '*.voyageai.com'], 'https://docs.voyageai.com'),
('jina', 'Jina AI', 'Jina embeddings', 'ai_llm', ARRAY['JINA_API_KEY'], 'bearer', 'DUMMY_JINA', ARRAY['api.jina.ai', '*.jina.ai'], 'https://docs.jina.ai');

-- Cloud Providers
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('aws', 'Amazon Web Services', 'AWS services with SigV4', 'cloud_provider', ARRAY['AWS_ACCESS_KEY_ID'], 'aws_sigv4', 'DUMMY_AWS', ARRAY['*.amazonaws.com', '*.amazonaws.com.cn'], 'https://docs.aws.amazon.com'),
('azure_openai', 'Azure OpenAI', 'Azure OpenAI Service', 'cloud_provider', ARRAY['AZURE_OPENAI_KEY', 'AZURE_OPENAI_API_KEY'], 'bearer', 'DUMMY_AZURE_OPENAI', ARRAY['*.openai.azure.com', '*.azure.com'], 'https://learn.microsoft.com/azure/cognitive-services/openai'),
('azure', 'Microsoft Azure', 'Azure services', 'cloud_provider', ARRAY['AZURE_API_KEY', 'AZURE_CLIENT_SECRET'], 'bearer', 'DUMMY_AZURE', ARRAY['*.azure.com', 'management.azure.com'], 'https://docs.microsoft.com/azure'),
('gcp', 'Google Cloud Platform', 'Google Cloud services', 'cloud_provider', ARRAY['GOOGLE_APPLICATION_CREDENTIALS', 'GCP_API_KEY'], 'bearer', 'DUMMY_GCP', ARRAY['*.googleapis.com', 'cloud.google.com'], 'https://cloud.google.com/docs'),
('digitalocean', 'DigitalOcean', 'DigitalOcean cloud', 'cloud_provider', ARRAY['DIGITALOCEAN_TOKEN', 'DO_API_TOKEN'], 'bearer', 'DUMMY_DO', ARRAY['api.digitalocean.com', '*.digitalocean.com'], 'https://docs.digitalocean.com'),
('vercel', 'Vercel', 'Vercel deployment', 'cloud_provider', ARRAY['VERCEL_TOKEN', 'VERCEL_API_KEY'], 'bearer', 'DUMMY_VERCEL', ARRAY['api.vercel.com', '*.vercel.com'], 'https://vercel.com/docs'),
('netlify', 'Netlify', 'Netlify deployment', 'cloud_provider', ARRAY['NETLIFY_AUTH_TOKEN', 'NETLIFY_API_KEY'], 'bearer', 'DUMMY_NETLIFY', ARRAY['api.netlify.com', '*.netlify.com'], 'https://docs.netlify.com'),
('heroku', 'Heroku', 'Heroku cloud platform', 'cloud_provider', ARRAY['HEROKU_API_KEY', 'HEROKU_TOKEN'], 'bearer', 'DUMMY_HEROKU', ARRAY['api.heroku.com', '*.heroku.com'], 'https://devcenter.heroku.com');

-- Finance & Crypto
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('binance', 'Binance', 'Binance cryptocurrency exchange API', 'finance', ARRAY['BINANCE_API_KEY', 'BINANCE_API_SECRET'], 'hmac', 'DUMMY_BINANCE', ARRAY['api.binance.com', 'api1.binance.com', 'api2.binance.com', 'api3.binance.com', 'data-api.binance.vision', '*.binance.com'], 'https://binance-docs.github.io/apidocs'),
('coinbase', 'Coinbase', 'Coinbase cryptocurrency exchange', 'finance', ARRAY['COINBASE_API_KEY', 'COINBASE_API_SECRET'], 'hmac', 'DUMMY_COINBASE', ARRAY['api.coinbase.com', '*.coinbase.com'], 'https://docs.cloud.coinbase.com'),
('kraken', 'Kraken', 'Kraken cryptocurrency exchange', 'finance', ARRAY['KRAKEN_API_KEY', 'KRAKEN_API_SECRET'], 'hmac', 'DUMMY_KRAKEN', ARRAY['api.kraken.com', '*.kraken.com'], 'https://docs.kraken.com/rest'),
('stripe', 'Stripe', 'Stripe payment processing', 'finance', ARRAY['STRIPE_SECRET_KEY', 'STRIPE_API_KEY'], 'bearer', 'DUMMY_STRIPE', ARRAY['api.stripe.com', '*.stripe.com'], 'https://stripe.com/docs/api'),
('paypal', 'PayPal', 'PayPal payment API', 'finance', ARRAY['PAYPAL_CLIENT_SECRET', 'PAYPAL_ACCESS_TOKEN'], 'bearer', 'DUMMY_PAYPAL', ARRAY['api.paypal.com', '*.paypal.com'], 'https://developer.paypal.com/api'),
('square', 'Square', 'Square payment processing', 'finance', ARRAY['SQUARE_ACCESS_TOKEN', 'SQUARE_API_KEY'], 'bearer', 'DUMMY_SQUARE', ARRAY['connect.squareup.com', '*.squareup.com'], 'https://developer.squareup.com'),
('plaid', 'Plaid', 'Plaid financial data API', 'finance', ARRAY['PLAID_SECRET', 'PLAID_API_KEY'], 'bearer', 'DUMMY_PLAID', ARRAY['*.plaid.com', 'api.plaid.com'], 'https://plaid.com/docs'),
('twilio', 'Twilio', 'Twilio communication API', 'finance', ARRAY['TWILIO_AUTH_TOKEN', 'TWILIO_API_KEY'], 'bearer', 'DUMMY_TWILIO', ARRAY['api.twilio.com', '*.twilio.com'], 'https://www.twilio.com/docs');

-- Developer Tools
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('github', 'GitHub', 'GitHub API for repositories', 'developer_tools', ARRAY['GITHUB_TOKEN', 'GH_TOKEN'], 'bearer', 'DUMMY_GITHUB', ARRAY['api.github.com', 'github.com', '*.github.com'], 'https://docs.github.com'),
('gitlab', 'GitLab', 'GitLab API for repositories', 'developer_tools', ARRAY['GITLAB_TOKEN', 'GITLAB_API_KEY'], 'bearer', 'DUMMY_GITLAB', ARRAY['gitlab.com', '*.gitlab.com', 'api.gitlab.com'], 'https://docs.gitlab.com/ee/api'),
('bitbucket', 'Bitbucket', 'Bitbucket API', 'developer_tools', ARRAY['BITBUCKET_TOKEN', 'BITBUCKET_APP_PASSWORD'], 'bearer', 'DUMMY_BITBUCKET', ARRAY['api.bitbucket.org', '*.bitbucket.org'], 'https://developer.atlassian.com/bitbucket'),
('dockerhub', 'Docker Hub', 'Docker Hub registry', 'developer_tools', ARRAY['DOCKER_TOKEN', 'DOCKER_HUB_TOKEN'], 'bearer', 'DUMMY_DOCKER', ARRAY['hub.docker.com', 'registry.hub.docker.com', '*.docker.com'], 'https://docs.docker.com/docker-hub/api'),
('npm', 'npm', 'npm package registry', 'developer_tools', ARRAY['NPM_TOKEN', 'NPM_API_KEY'], 'bearer', 'DUMMY_NPM', ARRAY['registry.npmjs.org', '*.npmjs.com', '*.npmjs.org'], 'https://docs.npmjs.com'),
('pypi', 'PyPI', 'Python package repository', 'developer_tools', ARRAY['PYPI_API_TOKEN', 'TWINE_PASSWORD'], 'bearer', 'DUMMY_PYPI', ARRAY['upload.pypi.org', 'pypi.org', '*.pypi.org'], 'https://docs.pypi.org'),
('render', 'Render', 'Render cloud platform', 'developer_tools', ARRAY['RENDER_API_KEY', 'RENDER_TOKEN'], 'bearer', 'DUMMY_RENDER', ARRAY['api.render.com', '*.render.com'], 'https://render.com/docs'),
('railway', 'Railway', 'Railway deployment', 'developer_tools', ARRAY['RAILWAY_TOKEN', 'RAILWAY_API_KEY'], 'bearer', 'DUMMY_RAILWAY', ARRAY['api.railway.app', '*.railway.app'], 'https://docs.railway.app');

-- Communication
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('slack_bot', 'Slack Bot', 'Slack bot token (xoxb-)', 'communication', ARRAY['SLACK_BOT_TOKEN'], 'bearer', 'xoxb-DUMMY', ARRAY['slack.com', '*.slack.com'], 'https://api.slack.com'),
('slack_app', 'Slack App', 'Slack app token (xapp-)', 'communication', ARRAY['SLACK_APP_TOKEN'], 'bearer', 'xapp-DUMMY', ARRAY['slack.com', '*.slack.com'], 'https://api.slack.com'),
('slack_webhook', 'Slack Webhook', 'Slack incoming webhook', 'communication', ARRAY['SLACK_WEBHOOK_URL', 'SLACK_WEBHOOK'], 'bearer', 'DUMMY_SLACK_WEBHOOK', ARRAY['hooks.slack.com', '*.slack.com'], 'https://api.slack.com/messaging/webhooks'),
('discord', 'Discord', 'Discord bot API', 'communication', ARRAY['DISCORD_TOKEN', 'DISCORD_BOT_TOKEN'], 'bearer', 'DUMMY_DISCORD', ARRAY['discord.com', '*.discord.com', 'discordapp.com'], 'https://discord.com/developers/docs'),
('telegram', 'Telegram', 'Telegram bot API', 'communication', ARRAY['TELEGRAM_BOT_TOKEN', 'TELEGRAM_API_KEY'], 'bearer', 'DUMMY_TELEGRAM', ARRAY['api.telegram.org', '*.telegram.org'], 'https://core.telegram.org/bots/api'),
('teams', 'Microsoft Teams', 'Microsoft Teams webhook', 'communication', ARRAY['TEAMS_WEBHOOK_URL', 'MS_TEAMS_WEBHOOK'], 'bearer', 'DUMMY_TEAMS', ARRAY['outlook.office.com', '*.office.com', '*.microsoft.com'], 'https://docs.microsoft.com/microsoftteams/platform'),
('sendgrid', 'SendGrid', 'SendGrid email API', 'communication', ARRAY['SENDGRID_API_KEY'], 'bearer', 'DUMMY_SENDGRID', ARRAY['api.sendgrid.com', '*.sendgrid.com'], 'https://docs.sendgrid.com'),
('mailgun', 'Mailgun', 'Mailgun email API', 'communication', ARRAY['MAILGUN_API_KEY'], 'bearer', 'DUMMY_MAILGUN', ARRAY['api.mailgun.net', '*.mailgun.net'], 'https://documentation.mailgun.com');

-- Data & Analytics
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('sentry', 'Sentry', 'Sentry error tracking', 'data_analytics', ARRAY['SENTRY_AUTH_TOKEN', 'SENTRY_API_KEY'], 'bearer', 'DUMMY_SENTRY', ARRAY['sentry.io', '*.sentry.io'], 'https://docs.sentry.io'),
('datadog', 'Datadog', 'Datadog monitoring', 'data_analytics', ARRAY['DD_API_KEY', 'DATADOG_API_KEY'], 'bearer', 'DUMMY_DD', ARRAY['api.datadoghq.com', '*.datadoghq.com'], 'https://docs.datadoghq.com'),
('newrelic', 'New Relic', 'New Relic observability', 'data_analytics', ARRAY['NEW_RELIC_API_KEY', 'NEWRELIC_API_KEY'], 'bearer', 'DUMMY_NR', ARRAY['api.newrelic.com', '*.newrelic.com'], 'https://docs.newrelic.com'),
('grafana', 'Grafana Cloud', 'Grafana Cloud metrics', 'data_analytics', ARRAY['GRAFANA_API_KEY', 'GRAFANA_TOKEN'], 'bearer', 'DUMMY_GRAFANA', ARRAY['grafana.com', '*.grafana.com', 'api.grafana.com'], 'https://grafana.com/docs'),
('segment', 'Segment', 'Segment analytics', 'data_analytics', ARRAY['SEGMENT_WRITE_KEY', 'SEGMENT_API_KEY'], 'bearer', 'DUMMY_SEGMENT', ARRAY['api.segment.io', '*.segment.com'], 'https://segment.com/docs'),
('amplitude', 'Amplitude', 'Amplitude analytics', 'data_analytics', ARRAY['AMPLITUDE_API_KEY'], 'bearer', 'DUMMY_AMPLITUDE', ARRAY['api.amplitude.com', '*.amplitude.com'], 'https://developers.amplitude.com'),
('mixpanel', 'Mixpanel', 'Mixpanel analytics', 'data_analytics', ARRAY['MIXPANEL_API_SECRET', 'MIXPANEL_TOKEN'], 'bearer', 'DUMMY_MIXPANEL', ARRAY['api.mixpanel.com', '*.mixpanel.com'], 'https://developer.mixpanel.com'),
('posthog', 'PostHog', 'PostHog analytics', 'data_analytics', ARRAY['POSTHOG_API_KEY', 'POSTHOG_PERSONAL_API_KEY'], 'bearer', 'DUMMY_POSTHOG', ARRAY['app.posthog.com', '*.posthog.com'], 'https://posthog.com/docs');

-- Productivity
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('notion', 'Notion', 'Notion workspace API', 'productivity', ARRAY['NOTION_API_KEY', 'NOTION_TOKEN', 'NOTION_INTEGRATION_TOKEN'], 'bearer', 'DUMMY_NOTION', ARRAY['api.notion.com', '*.notion.com'], 'https://developers.notion.com'),
('linear', 'Linear', 'Linear issue tracking', 'productivity', ARRAY['LINEAR_API_KEY', 'LINEAR_TOKEN'], 'bearer', 'DUMMY_LINEAR', ARRAY['api.linear.app', '*.linear.app'], 'https://developers.linear.app'),
('asana', 'Asana', 'Asana project management', 'productivity', ARRAY['ASANA_ACCESS_TOKEN', 'ASANA_API_KEY'], 'bearer', 'DUMMY_ASANA', ARRAY['api.asana.com', '*.asana.com'], 'https://developers.asana.com'),
('trello', 'Trello', 'Trello board management', 'productivity', ARRAY['TRELLO_API_KEY', 'TRELLO_TOKEN'], 'bearer', 'DUMMY_TRELLO', ARRAY['api.trello.com', '*.trello.com'], 'https://developer.atlassian.com/cloud/trello'),
('jira', 'Jira', 'Jira issue tracking', 'productivity', ARRAY['JIRA_API_TOKEN', 'JIRA_TOKEN', 'ATLASSIAN_API_TOKEN'], 'bearer', 'DUMMY_JIRA', ARRAY['*.atlassian.net', 'api.atlassian.com'], 'https://developer.atlassian.com/cloud/jira'),
('airtable', 'Airtable', 'Airtable database API', 'productivity', ARRAY['AIRTABLE_API_KEY', 'AIRTABLE_TOKEN'], 'bearer', 'DUMMY_AIRTABLE', ARRAY['api.airtable.com', '*.airtable.com'], 'https://airtable.com/developers'),
('figma', 'Figma', 'Figma design API', 'productivity', ARRAY['FIGMA_TOKEN', 'FIGMA_API_KEY'], 'bearer', 'DUMMY_FIGMA', ARRAY['api.figma.com', '*.figma.com'], 'https://www.figma.com/developers/api');

-- Infrastructure
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('cloudflare', 'Cloudflare', 'Cloudflare DNS and CDN', 'infrastructure', ARRAY['CLOUDFLARE_API_TOKEN', 'CLOUDFLARE_API_KEY'], 'bearer', 'DUMMY_CF', ARRAY['api.cloudflare.com', '*.cloudflare.com'], 'https://api.cloudflare.com'),
('fastly', 'Fastly', 'Fastly CDN API', 'infrastructure', ARRAY['FASTLY_API_TOKEN', 'FASTLY_API_KEY'], 'bearer', 'DUMMY_FASTLY', ARRAY['api.fastly.com', '*.fastly.com'], 'https://developer.fastly.com'),
('pagerduty', 'PagerDuty', 'PagerDuty incident management', 'infrastructure', ARRAY['PAGERDUTY_API_KEY', 'PAGERDUTY_TOKEN'], 'bearer', 'DUMMY_PAGERDUTY', ARRAY['api.pagerduty.com', '*.pagerduty.com'], 'https://developer.pagerduty.com'),
('opsgenie', 'Opsgenie', 'Opsgenie alerting', 'infrastructure', ARRAY['OPSGENIE_API_KEY', 'OPSGENIE_TOKEN'], 'bearer', 'DUMMY_OPSGENIE', ARRAY['api.opsgenie.com', '*.opsgenie.com'], 'https://docs.opsgenie.com'),
('consul', 'HashiCorp Consul', 'Consul service mesh', 'infrastructure', ARRAY['CONSUL_HTTP_TOKEN', 'CONSUL_TOKEN'], 'bearer', 'DUMMY_CONSUL', ARRAY['consul.io', '*.consul.io'], 'https://developer.hashicorp.com/consul'),
('vault', 'HashiCorp Vault', 'Vault secrets management', 'infrastructure', ARRAY['VAULT_TOKEN', 'VAULT_API_KEY'], 'bearer', 'DUMMY_VAULT', ARRAY['vault.io', '*.vault.io'], 'https://developer.hashicorp.com/vault'),
('terraform', 'Terraform Cloud', 'Terraform Cloud API', 'infrastructure', ARRAY['TERRAFORM_TOKEN', 'TF_API_TOKEN'], 'bearer', 'DUMMY_TF', ARRAY['app.terraform.io', '*.terraform.io'], 'https://developer.hashicorp.com/terraform/cloud-docs');

-- Other
INSERT INTO api_definitions (name, display_name, description, category, env_vars, strategy_type, dummy_prefix, allowed_hosts, documentation_url) VALUES
('serper', 'Serper', 'Google Search API via Serper', 'other', ARRAY['SERPER_API_KEY'], 'bearer', 'DUMMY_SERPER', ARRAY['google.serper.dev', '*.serper.dev'], 'https://serper.dev'),
('serpapi', 'SerpAPI', 'Search engine results API', 'other', ARRAY['SERPAPI_API_KEY'], 'bearer', 'DUMMY_SERPAPI', ARRAY['serpapi.com', '*.serpapi.com'], 'https://serpapi.com/search-api'),
('elevenlabs', 'ElevenLabs', 'Text-to-speech API', 'other', ARRAY['ELEVENLABS_API_KEY', 'XI_API_KEY'], 'bearer', 'DUMMY_ELEVENLABS', ARRAY['api.elevenlabs.io', '*.elevenlabs.io'], 'https://elevenlabs.io/docs'),
('assemblyai', 'AssemblyAI', 'Speech-to-text API', 'other', ARRAY['ASSEMBLYAI_API_KEY'], 'bearer', 'DUMMY_ASSEMBLYAI', ARRAY['api.assemblyai.com', '*.assemblyai.com'], 'https://www.assemblyai.com/docs'),
('deepgram', 'Deepgram', 'Speech recognition API', 'other', ARRAY['DEEPGRAM_API_KEY'], 'bearer', 'DUMMY_DEEPGRAM', ARRAY['api.deepgram.com', '*.deepgram.com'], 'https://developers.deepgram.com');
