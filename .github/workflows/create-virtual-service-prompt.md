Read each of the following skill files IN FULL before taking any other action:
  .github/skills/jira-story-virtual-service/SKILL.md
  .github/skills/virtualize-mcp-general-rules/SKILL.md

After you fetch and read the Jira story, read additional skill files only if the story requires them:
  - Read .github/skills/virtualize-correlation-matching-rules/SKILL.md if request-to-response correlation or matching rules are needed.
  - Read .github/skills/virtualize-inline-expressions/SKILL.md if dynamic values, extracted fields, timestamps, headers, or URL-derived response data are needed.
  - Do not read .github/skills/virtualize-asset-validation-instructions/SKILL.md in this create phase; that skill belongs to the verify phase.

STRICT GUARDRAILS:
1. You have two MCP servers: jira-remote-cicd and virtualize-cicd.
2. Use jira-remote-cicd MCP tools to fetch the Jira story.
3. Use virtualize-cicd manageVirtualServices MCP tool to create and deploy the service.
4. If manageVirtualServices is not available, output exactly: MCP_ERROR: manageVirtualServices tool not available
5. Do not use shell commands, curl, python, or direct REST calls to perform Jira or Virtualize operations.
6. On any MCP failure, report and stop immediately.

Fetch Jira ticket ${JIRA_TICKET} and create/deploy a matching virtual service.
