#!/bin/bash
# Setup script for ECHO agents in Claude Desktop

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo -e "${BLUE}  ECHO - Claude Desktop Setup${NC}"
echo -e "${BLUE}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo ""

# Detect OS and set config path
if [[ "$OSTYPE" == "darwin"* ]]; then
    CONFIG_DIR="$HOME/Library/Application Support/Claude"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    CONFIG_DIR="$HOME/.config/Claude"
else
    echo -e "${RED}✗ Unsupported OS: $OSTYPE${NC}"
    exit 1
fi

CONFIG_FILE="$CONFIG_DIR/claude_desktop_config.json"

echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"
echo ""

# Check PostgreSQL
echo -n "  PostgreSQL... "
if pg_isready -q; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo -e "${YELLOW}  Start with: brew services start postgresql${NC}"
    exit 1
fi

# Check Redis
echo -n "  Redis... "
if redis-cli ping > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo -e "${YELLOW}  Start with: brew services start redis${NC}"
    exit 1
fi

# Check database exists
echo -n "  Database (echo_org_dev)... "
if psql -lqt | cut -d \| -f 1 | grep -qw echo_org_dev; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}! Not found - will create${NC}"
    cd apps/echo_shared
    mix ecto.create
    mix ecto.migrate
    cd ../..
fi

# Check if agents are built
echo ""
echo -e "${YELLOW}Step 2: Checking agent executables...${NC}"
echo ""

AGENTS=("ceo" "cto" "product_manager")
MISSING_AGENTS=()

for agent in "${AGENTS[@]}"; do
    echo -n "  $agent... "
    if [[ -x "apps/$agent/$agent" ]]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}! Not built${NC}"
        MISSING_AGENTS+=("$agent")
    fi
done

if [[ ${#MISSING_AGENTS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Building missing agents...${NC}"
    for agent in "${MISSING_AGENTS[@]}"; do
        echo "  Building $agent..."
        cd "apps/$agent"
        mix deps.get > /dev/null 2>&1
        mix escript.build
        cd ../..
    done
    echo -e "${GREEN}✓ All agents built${NC}"
fi

# Get absolute path to ECHO directory
ECHO_DIR=$(pwd)

echo ""
echo -e "${YELLOW}Step 3: Creating Claude Desktop configuration...${NC}"
echo ""

# Create config directory if it doesn't exist
mkdir -p "$CONFIG_DIR"

# Backup existing config if it exists
if [[ -f "$CONFIG_FILE" ]]; then
    BACKUP_FILE="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}  Backing up existing config to:${NC}"
    echo "  $BACKUP_FILE"
    cp "$CONFIG_FILE" "$BACKUP_FILE"

    # Try to merge with existing config
    echo -e "${YELLOW}  Merging with existing configuration...${NC}"

    # Create temporary config with ECHO agents
    cat > /tmp/echo_agents.json << EOF
{
  "echo-ceo": {
    "command": "$ECHO_DIR/apps/ceo/ceo",
    "env": {
      "DB_HOST": "localhost",
      "DB_PORT": "5432",
      "DB_NAME": "echo_org_dev",
      "DB_USER": "postgres",
      "DB_PASSWORD": "postgres",
      "REDIS_HOST": "localhost",
      "REDIS_PORT": "6379"
    }
  },
  "echo-cto": {
    "command": "$ECHO_DIR/apps/cto/cto",
    "env": {
      "DB_HOST": "localhost",
      "DB_PORT": "5432",
      "DB_NAME": "echo_org_dev",
      "DB_USER": "postgres",
      "DB_PASSWORD": "postgres",
      "REDIS_HOST": "localhost",
      "REDIS_PORT": "6379"
    }
  },
  "echo-product-manager": {
    "command": "$ECHO_DIR/apps/product_manager/product_manager",
    "env": {
      "DB_HOST": "localhost",
      "DB_PORT": "5432",
      "DB_NAME": "echo_org_dev",
      "DB_USER": "postgres",
      "DB_PASSWORD": "postgres",
      "REDIS_HOST": "localhost",
      "REDIS_PORT": "6379"
    }
  }
}
EOF

    # Merge configurations using jq if available
    if command -v jq &> /dev/null; then
        jq -s '.[0].mcpServers + .[1] | {mcpServers: .}' "$CONFIG_FILE" /tmp/echo_agents.json > /tmp/merged_config.json
        mv /tmp/merged_config.json "$CONFIG_FILE"
        echo -e "${GREEN}  ✓ Merged with existing servers${NC}"
    else
        echo -e "${YELLOW}  ! jq not found - creating new config (old config backed up)${NC}"
        cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "echo-ceo": {
      "command": "$ECHO_DIR/apps/ceo/ceo",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-cto": {
      "command": "$ECHO_DIR/apps/cto/cto",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-product-manager": {
      "command": "$ECHO_DIR/apps/product_manager/product_manager",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    }
  }
}
EOF
    fi
    rm -f /tmp/echo_agents.json
else
    # Create new config
    cat > "$CONFIG_FILE" << EOF
{
  "mcpServers": {
    "echo-ceo": {
      "command": "$ECHO_DIR/apps/ceo/ceo",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-cto": {
      "command": "$ECHO_DIR/apps/cto/cto",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    },
    "echo-product-manager": {
      "command": "$ECHO_DIR/apps/product_manager/product_manager",
      "env": {
        "DB_HOST": "localhost",
        "DB_PORT": "5432",
        "DB_NAME": "echo_org_dev",
        "DB_USER": "postgres",
        "DB_PASSWORD": "postgres",
        "REDIS_HOST": "localhost",
        "REDIS_PORT": "6379"
      }
    }
  }
}
EOF
fi

echo -e "${GREEN}  ✓ Configuration created at:${NC}"
echo "  $CONFIG_FILE"

echo ""
echo -e "${YELLOW}Step 4: Testing agent executables...${NC}"
echo ""

for agent in "${AGENTS[@]}"; do
    echo -n "  Testing $agent... "
    if timeout 2s "apps/$agent/$agent" < /dev/null > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
    else
        # Agent should timeout waiting for stdin, which is expected
        echo -e "${GREEN}✓ (waiting for input)${NC}"
    fi
done

echo ""
echo -e "${GREEN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}╺━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╸${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo ""
echo "  1. ${YELLOW}Restart Claude Desktop completely${NC}"
echo "     (Quit and reopen, not just close window)"
echo ""
echo "  2. ${YELLOW}Verify agents are connected:${NC}"
echo "     In Claude Desktop, ask: 'List all available MCP tools'"
echo ""
echo "  3. ${YELLOW}Try a simple test:${NC}"
echo "     'Use the CEO agent to review organizational health'"
echo ""
echo "  4. ${YELLOW}Monitor system health:${NC}"
echo "     Run: ./echo.sh summary"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "  - CLAUDE_DESKTOP_SETUP.md - Detailed setup guide"
echo "  - DEMO_GUIDE.md - Demo scenarios and examples"
echo "  - AGENT_INTEGRATION_GUIDE.md - Agent implementation details"
echo ""
echo -e "${YELLOW}Configuration file:${NC} $CONFIG_FILE"
echo ""
echo -e "${GREEN}Happy collaborating with ECHO agents! 🤖${NC}"
echo ""
