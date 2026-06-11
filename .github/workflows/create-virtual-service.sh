#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
PVA_OUT="$REPO_ROOT/pva.txt"

ts() {
  echo "[$(date '+%H:%M:%S')] $*"
}

die() {
  echo "::error::$*" >&2
  exit 1
}

: "${COPILOT_GITHUB_TOKEN:?Missing COPILOT_GITHUB_TOKEN}"
: "${ATLASSIAN_BASIC_AUTH:?Missing ATLASSIAN_BASIC_AUTH}"
: "${VIRTUALIZE_AUTH_TOKEN:?Missing VIRTUALIZE_AUTH_TOKEN}"
: "${VIRTUALIZE_MCP_URL:?Missing VIRTUALIZE_MCP_URL}"
: "${JIRA_TICKET:?Missing JIRA_TICKET}"

ts "Registering MCP servers..."
copilot mcp remove jira-remote-cicd > /dev/null 2>&1 || true
copilot mcp remove virtualize-cicd > /dev/null 2>&1 || true

copilot mcp add \
  --transport http \
  --header "Authorization: Basic ${ATLASSIAN_BASIC_AUTH}" \
  --env ATLASSIAN_BASE_URL=https://parasoft-demo.atlassian.net \
  jira-remote-cicd \
  https://mcp.atlassian.com/v1/mcp

copilot mcp add \
  --transport http \
  --header "Authorization: Basic ${VIRTUALIZE_AUTH_TOKEN}" \
  virtualize-cicd \
  "${VIRTUALIZE_MCP_URL}"

ts "Running create phase for ticket ${JIRA_TICKET}..."
CREATE_PROMPT=$(JIRA_TICKET="${JIRA_TICKET}" envsubst < "$SCRIPT_DIR/create-virtual-service-prompt.md")
rm -f "$PVA_OUT"

set +e
(
  cd "$REPO_ROOT"
  timeout 600 copilot --allow-all --no-ask-user -p "$CREATE_PROMPT" < /dev/null | tee "$PVA_OUT"
)
create_exit=${PIPESTATUS[0]}
set -e

if grep -q "^MCP_ERROR:" "$PVA_OUT" 2>/dev/null; then
  grep "^MCP_ERROR:" "$PVA_OUT"
  die "Agent reported MCP tool unavailability"
fi
if [[ $create_exit -eq 124 ]]; then
  die "Create step timed out after 600s"
fi
if [[ $create_exit -ne 0 ]]; then
  die "Create step failed with exit code $create_exit"
fi

grep -Eq '^`?TEST_METHOD=[^`]+`?[[:space:]]*$' "$PVA_OUT" || {
  tail -30 "$PVA_OUT" || true
  die "Missing TEST_METHOD in pva.txt"
}
grep -Eq '^`?FULL_TEST_URL=[^`]+`?[[:space:]]*$' "$PVA_OUT" || {
  tail -30 "$PVA_OUT" || true
  die "Missing FULL_TEST_URL in pva.txt"
}

ts "Create phase output validated."
grep -E '^`?(TEST_METHOD|FULL_TEST_URL|FULL_EXTERNAL_URL)=' "$PVA_OUT" || true

ts "Running verification phase..."
VERIFY_PROMPT="$(cat "$SCRIPT_DIR/verify-virtual-service-prompt.md")"
VERIFY_PROMPT="$VERIFY_PROMPT
$(cat "$PVA_OUT")"

set +e
(
  cd "$REPO_ROOT"
  timeout 300 copilot --allow-all --no-ask-user -p "$VERIFY_PROMPT" < /dev/null
)
verify_exit=$?
set -e

if [[ $verify_exit -eq 124 ]]; then
  echo "::warning::Verification timed out after 300s"
  exit 0
fi
if [[ $verify_exit -ne 0 ]]; then
  die "Verify step failed with exit code $verify_exit"
fi

ts "Verification completed successfully."