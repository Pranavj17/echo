#!/bin/bash

###############################################################################
# ECHO - System Status Monitor
#
# Checks the health and status of all ECHO agents and infrastructure
###############################################################################

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Database configuration
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-echo_org_dev}"
DB_USER="${DB_USER:-postgres}"

# Redis configuration
REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

# Agent roles
AGENTS=(
  "ceo"
  "cto"
  "chro"
  "operations_head"
  "product_manager"
  "senior_architect"
  "uiux_engineer"
  "senior_developer"
  "test_lead"
)

###############################################################################
# Utility Functions
###############################################################################

print_header() {
  echo -e "\n${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BOLD}${CYAN}  $1${NC}"
  echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_status() {
  local status=$1
  local message=$2

  case $status in
    "ok")
      echo -e "  ${GREEN}✓${NC} $message"
      ;;
    "warning")
      echo -e "  ${YELLOW}⚠${NC} $message"
      ;;
    "error")
      echo -e "  ${RED}✗${NC} $message"
      ;;
    "info")
      echo -e "  ${BLUE}ℹ${NC} $message"
      ;;
  esac
}

###############################################################################
# Infrastructure Checks
###############################################################################

check_postgres() {
  print_header "PostgreSQL Status"

  if command -v psql &> /dev/null; then
    if PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
      print_status "ok" "PostgreSQL is ${GREEN}RUNNING${NC} on $DB_HOST:$DB_PORT"

      # Get database size
      local db_size=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT pg_size_pretty(pg_database_size('$DB_NAME'));" 2>/dev/null | xargs)
      print_status "info" "Database size: $db_size"

      # Get table counts
      local tables=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
        SELECT
          'decisions: ' || COUNT(*) || ' | ' ||
          'messages: ' || (SELECT COUNT(*) FROM messages) || ' | ' ||
          'workflows: ' || (SELECT COUNT(*) FROM workflow_executions)
        FROM decisions;
      " 2>/dev/null | xargs)
      print_status "info" "Records: $tables"

      return 0
    else
      print_status "error" "PostgreSQL is ${RED}NOT ACCESSIBLE${NC}"
      print_status "info" "Try: pg_ctl -D /usr/local/var/postgres start"
      return 1
    fi
  else
    print_status "warning" "psql not found in PATH"
    return 1
  fi
}

check_redis() {
  print_header "Redis Status"

  if command -v redis-cli &> /dev/null; then
    if redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping &>/dev/null; then
      print_status "ok" "Redis is ${GREEN}RUNNING${NC} on $REDIS_HOST:$REDIS_PORT"

      # Get memory usage
      local mem_used=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" INFO memory 2>/dev/null | grep used_memory_human | cut -d: -f2 | tr -d '\r')
      print_status "info" "Memory used: $mem_used"

      # Get number of keys
      local keys=$(redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" DBSIZE 2>/dev/null | cut -d: -f2 | xargs)
      print_status "info" "Keys: $keys"

      return 0
    else
      print_status "error" "Redis is ${RED}NOT ACCESSIBLE${NC}"
      print_status "info" "Try: redis-server --daemonize yes"
      return 1
    fi
  else
    print_status "warning" "redis-cli not found in PATH"
    return 1
  fi
}

###############################################################################
# Agent Health Checks
###############################################################################

check_agent_health() {
  print_header "Agent Health Status"

  if ! command -v psql &> /dev/null; then
    print_status "error" "Cannot check agent health - psql not available"
    return 1
  fi

  # Query agent_status table
  local query="
    SELECT
      role,
      status,
      EXTRACT(EPOCH FROM (NOW() - last_heartbeat))::INTEGER as seconds_ago,
      version
    FROM agent_status
    ORDER BY role;
  "

  local result=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' -c "$query" 2>/dev/null)

  if [ -z "$result" ]; then
    print_status "warning" "No agents have sent heartbeats yet"
    echo ""
    print_status "info" "Expected agents:"
    for agent in "${AGENTS[@]}"; do
      echo -e "    - $agent"
    done
    return 1
  fi

  local healthy=0
  local degraded=0
  local down=0

  echo -e "${BOLD}  Role                Status      Last Heartbeat    Version${NC}"
  echo -e "  ────────────────────────────────────────────────────────────────"

  while IFS='|' read -r role status seconds_ago version; do
    local age_display

    if [ "$seconds_ago" -lt 60 ]; then
      age_display="${seconds_ago}s ago"
    else
      age_display="$((seconds_ago / 60))m ago"
    fi

    # Determine health
    if [ "$seconds_ago" -lt 30 ]; then
      # Healthy
      echo -e "  ${GREEN}●${NC} $(printf '%-18s' "$role") ${GREEN}HEALTHY${NC}     $age_display    ${version:-N/A}"
      ((healthy++))
    elif [ "$seconds_ago" -lt 60 ]; then
      # Degraded
      echo -e "  ${YELLOW}●${NC} $(printf '%-18s' "$role") ${YELLOW}DEGRADED${NC}    $age_display    ${version:-N/A}"
      ((degraded++))
    else
      # Down
      echo -e "  ${RED}●${NC} $(printf '%-18s' "$role") ${RED}DOWN${NC}        $age_display    ${version:-N/A}"
      ((down++))
    fi
  done <<< "$result"

  echo ""
  print_status "info" "Summary: ${GREEN}$healthy healthy${NC}, ${YELLOW}$degraded degraded${NC}, ${RED}$down down${NC}"

  if [ "$down" -gt 0 ]; then
    return 1
  else
    return 0
  fi
}

###############################################################################
# Workflow Status
###############################################################################

check_workflows() {
  print_header "Workflow Status"

  if ! command -v psql &> /dev/null; then
    print_status "error" "Cannot check workflows - psql not available"
    return 1
  fi

  # Count workflows by status
  local query="
    SELECT
      status,
      COUNT(*)
    FROM workflow_executions
    GROUP BY status
    ORDER BY
      CASE status
        WHEN 'running' THEN 1
        WHEN 'paused' THEN 2
        WHEN 'completed' THEN 3
        WHEN 'failed' THEN 4
      END;
  "

  local result=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' -c "$query" 2>/dev/null)

  if [ -z "$result" ]; then
    print_status "info" "No workflows executed yet"
    return 0
  fi

  while IFS='|' read -r status count; do
    case $status in
      "running")
        print_status "info" "${CYAN}Running:${NC} $count workflow(s)"
        ;;
      "paused")
        print_status "warning" "${YELLOW}Paused:${NC} $count workflow(s)"
        ;;
      "completed")
        print_status "ok" "${GREEN}Completed:${NC} $count workflow(s)"
        ;;
      "failed")
        print_status "error" "${RED}Failed:${NC} $count workflow(s)"
        ;;
    esac
  done <<< "$result"

  # Show recent workflows
  local recent=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT
      id,
      workflow_name,
      status,
      inserted_at
    FROM workflow_executions
    ORDER BY inserted_at DESC
    LIMIT 3;
  " 2>/dev/null)

  if [ ! -z "$recent" ]; then
    echo ""
    print_status "info" "Recent workflows:"
    echo "$recent" | sed 's/^/    /'
  fi
}

###############################################################################
# Message Queue Status
###############################################################################

check_messages() {
  print_header "Message Queue Status"

  if ! command -v psql &> /dev/null; then
    print_status "error" "Cannot check messages - psql not available"
    return 1
  fi

  # Unread messages by recipient
  local query="
    SELECT
      to_role,
      COUNT(*) as unread
    FROM messages
    WHERE read = false
    GROUP BY to_role
    ORDER BY unread DESC;
  "

  local result=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' -c "$query" 2>/dev/null)

  if [ -z "$result" ]; then
    print_status "ok" "All messages processed ✓"
  else
    print_status "warning" "Unread messages detected:"
    while IFS='|' read -r to_role count; do
      echo -e "    ${YELLOW}→${NC} $to_role: $count unread"
    done <<< "$result"
  fi

  # Failed message processing
  local failed=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT COUNT(*) FROM messages WHERE processing_error IS NOT NULL;
  " 2>/dev/null | xargs)

  if [ "$failed" -gt 0 ]; then
    print_status "error" "${RED}$failed${NC} message(s) failed processing"
  fi

  # Total messages
  local total=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT COUNT(*) FROM messages;
  " 2>/dev/null | xargs)

  echo ""
  print_status "info" "Total messages: $total"
}

###############################################################################
# Decision Status
###############################################################################

check_decisions() {
  print_header "Decision Status"

  if ! command -v psql &> /dev/null; then
    print_status "error" "Cannot check decisions - psql not available"
    return 1
  fi

  # Decisions by mode
  local query="
    SELECT
      mode,
      COUNT(*)
    FROM decisions
    GROUP BY mode
    ORDER BY COUNT(*) DESC;
  "

  local result=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -A -F'|' -c "$query" 2>/dev/null)

  if [ -z "$result" ]; then
    print_status "info" "No decisions recorded yet"
    return 0
  fi

  echo -e "${BOLD}  Decision Mode       Count${NC}"
  echo -e "  ─────────────────────────────"
  while IFS='|' read -r mode count; do
    echo -e "  $(printf '%-18s' "$mode") $count"
  done <<< "$result"

  # Pending decisions
  local pending=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
    SELECT COUNT(*) FROM decisions WHERE status = 'pending';
  " 2>/dev/null | xargs)

  if [ "$pending" -gt 0 ]; then
    echo ""
    print_status "warning" "${YELLOW}$pending${NC} decision(s) pending"
  fi
}

###############################################################################
# System Summary
###############################################################################

print_summary() {
  print_header "System Summary"

  local postgres_ok=0
  local redis_ok=0
  local agents_ok=0

  # Check if services are up
  if PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -c '\q' 2>/dev/null; then
    postgres_ok=1
  fi

  if command -v redis-cli &> /dev/null && redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" ping &>/dev/null; then
    redis_ok=1
  fi

  # Count healthy agents
  local healthy_count=0
  if [ "$postgres_ok" -eq 1 ]; then
    healthy_count=$(PGPASSWORD="${DB_PASSWORD:-postgres}" psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d "$DB_NAME" -t -c "
      SELECT COUNT(*)
      FROM agent_status
      WHERE EXTRACT(EPOCH FROM (NOW() - last_heartbeat)) < 30;
    " 2>/dev/null | xargs || echo "0")
  fi

  if [ "$healthy_count" -gt 0 ]; then
    agents_ok=1
  fi

  # Overall status
  if [ "$postgres_ok" -eq 1 ] && [ "$redis_ok" -eq 1 ] && [ "$agents_ok" -eq 1 ]; then
    echo -e "  ${GREEN}●${NC} System Status: ${BOLD}${GREEN}OPERATIONAL${NC}"
  elif [ "$postgres_ok" -eq 1 ] && [ "$redis_ok" -eq 1 ]; then
    echo -e "  ${YELLOW}●${NC} System Status: ${BOLD}${YELLOW}DEGRADED${NC} (no healthy agents)"
  else
    echo -e "  ${RED}●${NC} System Status: ${BOLD}${RED}DOWN${NC}"
  fi

  echo ""
  echo -e "  ${BOLD}Infrastructure:${NC}"
  [ "$postgres_ok" -eq 1 ] && echo -e "    ${GREEN}✓${NC} PostgreSQL" || echo -e "    ${RED}✗${NC} PostgreSQL"
  [ "$redis_ok" -eq 1 ] && echo -e "    ${GREEN}✓${NC} Redis" || echo -e "    ${RED}✗${NC} Redis"

  if [ "$postgres_ok" -eq 1 ]; then
    echo ""
    echo -e "  ${BOLD}Agents:${NC}"
    echo -e "    ${GREEN}✓${NC} $healthy_count / ${#AGENTS[@]} agents healthy"
  fi

  echo ""
}

###############################################################################
# Main Menu
###############################################################################

show_help() {
  cat << EOF
${BOLD}ECHO System Status Monitor${NC}

${BOLD}USAGE:${NC}
  ./echo.sh [COMMAND]

${BOLD}COMMANDS:${NC}
  status      Show full system status (default)
  agents      Show only agent health
  infra       Show only infrastructure (PostgreSQL, Redis)
  workflows   Show only workflow status
  messages    Show only message queue status
  decisions   Show only decision status
  summary     Show quick system summary
  help        Show this help message

${BOLD}ENVIRONMENT VARIABLES:${NC}
  DB_HOST     PostgreSQL host (default: localhost)
  DB_PORT     PostgreSQL port (default: 5432)
  DB_NAME     Database name (default: echo_org)
  DB_USER     Database user (default: postgres)
  DB_PASSWORD Database password (default: postgres)
  REDIS_HOST  Redis host (default: localhost)
  REDIS_PORT  Redis port (default: 6379)

${BOLD}EXAMPLES:${NC}
  ./echo.sh                    # Show full status
  ./echo.sh agents             # Check only agents
  ./echo.sh summary            # Quick overview
  DB_HOST=prod.db ./echo.sh    # Check production database

EOF
}

###############################################################################
# Main
###############################################################################

main() {
  local command="${1:-status}"

  case $command in
    status)
      echo -e "${BOLD}${CYAN}"
      echo "  ███████╗ ██████╗██╗  ██╗ ██████╗ "
      echo "  ██╔════╝██╔════╝██║  ██║██╔═══██╗"
      echo "  █████╗  ██║     ███████║██║   ██║"
      echo "  ██╔══╝  ██║     ██╔══██║██║   ██║"
      echo "  ███████╗╚██████╗██║  ██║╚██████╔╝"
      echo "  ╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝ "
      echo -e "${NC}"
      echo -e "  ${BOLD}Executive Coordination & Hierarchical Organization${NC}"
      echo ""

      check_postgres
      check_redis
      check_agent_health
      check_workflows
      check_messages
      check_decisions
      print_summary
      ;;

    agents)
      check_agent_health
      ;;

    infra)
      check_postgres
      check_redis
      ;;

    workflows)
      check_workflows
      ;;

    messages)
      check_messages
      ;;

    decisions)
      check_decisions
      ;;

    summary)
      print_summary
      ;;

    help|--help|-h)
      show_help
      ;;

    *)
      echo -e "${RED}Error: Unknown command '$command'${NC}"
      echo ""
      show_help
      exit 1
      ;;
  esac
}

# Run main function
main "$@"
