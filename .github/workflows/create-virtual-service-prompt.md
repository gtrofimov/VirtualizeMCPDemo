Read each of the following skill files IN FULL before taking any other action:
  .github/skills/jira-story-virtual-service/SKILL.md
  .github/skills/virtualize-mcp-general-rules/SKILL.md
  .github/skills/virtualize-correlation-matching-rules/SKILL.md
  .github/skills/virtualize-inline-expressions/SKILL.md
  .github/skills/virtualize-asset-validation-instructions/SKILL.md

STRICT GUARDRAILS:
1. You have two MCP servers: jira-remote and virtualize.
2. Use jira-remote MCP tools to fetch the Jira story.
3. Use virtualize manageVirtualServices MCP tool to create and deploy the service.
4. If manageVirtualServices is not available, output exactly: MCP_ERROR: manageVirtualServices tool not available
5. Do not use shell commands, curl, python, or direct REST calls to perform Jira or Virtualize operations.
6. On any MCP failure, report and stop immediately.

Fetch Jira ticket ${JIRA_TICKET} and create/deploy a matching virtual service.
