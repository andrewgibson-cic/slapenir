#!/bin/bash
# Setup bashrc to automatically source .env file

cat > /home/agent/.bashrc << 'EOF'
# SLAPENIR Agent .bashrc
# Auto-generated - automatically sources environment variables

# Source .env if it exists
if [ -f /home/agent/.env ]; then
    set -a
    source /home/agent/.env
    set +a
fi

# Bash completion
if [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
fi

# Colorful prompt
PS1='\[\033[01;32m\]agent@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Useful aliases
alias ll='ls -lah'
alias python='python3'
alias pip='pip3'

# Environment info
export EDITOR=vi
export LANG=en_US.UTF-8

EOF

chmod 644 /home/agent/.bashrc
chown agent:agent /home/agent/.bashrc 2>/dev/null || true

echo "✅ .bashrc configured to auto-source .env"