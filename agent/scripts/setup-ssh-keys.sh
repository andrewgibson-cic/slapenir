#!/bin/bash
# Setup SSH keys for git operations in SLAPENIR Agent

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔑 SSH Key Setup for Git${NC}"
echo ""

# Check if SSH directory exists
if [ ! -d "/home/agent/.ssh" ]; then
    mkdir -p /home/agent/.ssh
    chmod 700 /home/agent/.ssh
fi

# Check if key already exists
if [ -f "/home/agent/.ssh/id_ed25519" ]; then
    echo -e "${YELLOW}⚠️  SSH key already exists${NC}"
    echo ""
    echo "Your public key:"
    echo "----------------------------------------"
    cat /home/agent/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    echo ""
    echo "Options:"
    echo "  1. Use existing key (shown above)"
    echo "  2. Generate new key (will overwrite existing)"
    echo ""
    read -p "Enter choice (1 or 2): " choice
    
    if [ "$choice" != "2" ]; then
        echo -e "${GREEN}✅ Using existing SSH key${NC}"
        exit 0
    fi
fi

# Generate new SSH key
echo -e "${BLUE}Generating new SSH key...${NC}"
echo ""
read -p "Enter your email address: " email

if [ -z "$email" ]; then
    email="agent@slapenir.local"
fi

ssh-keygen -t ed25519 -C "$email" -f /home/agent/.ssh/id_ed25519 -N ""

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ SSH key generated successfully!${NC}"
    echo ""
    echo -e "${BLUE}📋 Your public key (add this to GitHub):${NC}"
    echo "========================================"
    cat /home/agent/.ssh/id_ed25519.pub
    echo "========================================"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Copy the key above"
    echo "2. Go to: https://github.com/settings/keys"
    echo "3. Click 'New SSH key'"
    echo "4. Paste the key and save"
    echo "5. Test with: ssh -T git@github.com"
    echo ""
else
    echo -e "${RED}❌ Failed to generate SSH key${NC}"
    exit 1
fi

# Set proper permissions
chmod 600 /home/agent/.ssh/id_ed25519
chmod 644 /home/agent/.ssh/id_ed25519.pub

# Configure SSH to accept GitHub's host key
if [ ! -f "/home/agent/.ssh/config" ]; then
    cat > /home/agent/.ssh/config << 'EOF'
Host github.com
    StrictHostKeyChecking accept-new
    UserKnownHostsFile=/home/agent/.ssh/known_hosts

Host *
    StrictHostKeyChecking ask
EOF
    chmod 600 /home/agent/.ssh/config
    echo -e "${GREEN}✅ SSH config created${NC}"
fi

echo ""
echo -e "${GREEN}Setup complete!${NC}"
echo ""