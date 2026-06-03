---
name: jira-story-virtual-service
description: Read a Jira user story and create a Parasoft Virtualize virtual service with safe defaults, uniqueness checks, and required approval gates. Use when a prompt mentions Jira ticket to virtual service creation or Virtualize MCP automation.
argument-hint: <JIRA-KEY>
---

# Jira Story -> Virtual Service (Virtualize MCP)

Use this skill to reliably convert a Jira user story into a deployed Parasoft Virtualize virtual service, with consistent defaults and safety checks.

## Purpose

Given a Jira ticket key (for example, `PROJ-123`), read the story with Atlassian MCP tools, infer virtual service behavior, and create/deploy a Virtualize service that matches the story.

## Required MCP Context

- Jira cloudId is fixed: `parasoft-demo.atlassian.net`
- Expected servers:
  - `jira-remote`
  - `virtualize`

## Inputs

- `jira_ticket` (required): Jira issue key, such as `PROJ-123`

## Mandatory Guardrails

1. Jira cloudId guardrail
- Always call Jira tools with `cloudId: parasoft-demo.atlassian.net`
- Never derive or guess cloudId from URLs, usernames, or emails

2. Service naming guardrail
- Infer service name from the Jira story when confidence is high
- If confidence is low, use the Jira ticket key as the default name
- Call `manageVirtualServices action=list` to enumerate all MCP-managed virtual services; each entry is of the form `<serviceName> (Base path: ...)` — collect the set of existing service names from these entries
- Note: a single `list` call satisfies the uniqueness checks for guardrails 2, 3, and 4 simultaneously; do not make redundant calls
- If the inferred name already exists, append `-1`, `-2`, etc. until the name is unique

3. Port selection guardrail
- If no confident port is present in the story, default to `38000`
- Call `manageVirtualServices action=list` to enumerate all MCP-managed virtual services; each entry includes a base path URL of the form `http://localhost:{port}/{deployment}` — parse the port from each base path URL to build the set of occupied ports
- Note: only services created through the MCP tool are visible; ports used by non-MCP services on the same Virtualize instance cannot be detected this way
- Starting from the inferred or default port, choose the lowest port not already present in the occupied set
- Never reuse an occupied port

4. Deployment prefix guardrail
- If no confident deployment prefix is present, default to repo name `VirtualizeMCPDemo`
- From the `manageVirtualServices action=list` result (already collected for guardrails 2 and 3), parse the deployment path segment from each base path URL of the form `http://localhost:{port}/{deployment}` to build the set of occupied deployment prefixes
- If the inferred or default deployment prefix already exists, append `-1`, `-2`, etc. until the prefix is unique

## Procedure

1. Read Jira story
- Fetch and analyze the Jira story for:
  - HTTP method(s)
  - endpoint path(s)
  - query/path parameters
  - request schema/body examples
  - response schema/body examples
  - behavior rules and status expectations
  - optional service name, deployment, and port hints

2. Resolve required values and approvals
- Resolve and finalize:
  - service name
  - deployment prefix
  - port
  - interactions to create
  - assumptions/defaults
- If any mandatory gate is not satisfied, stop and ask for explicit approval/input

3. Create virtual service
- Create and deploy service via Virtualize MCP
- Leverage virtualize-* skills as needed for request/response file enrichment
  - When constructing response content, inspect each response property for fields like dateTimes, timestamps, and auto-generated ID characteristics. For any such field, apply inline expressions per the virtualize-inline-expressions skill rather than hard-coding the example value from the story.
- Include at least one catch-all `200` response so requests with values deviating from story examples still receive `200`

4. Verification and final output
- Confirm deployment success by testing the endpoint before finishing
- Provide concise summary:
  - service name
  - deployment prefix
  - endpoint(s)
  - port
  - assumptions/defaults used
- End with exact lines:
  - `TEST_METHOD=<METHOD>`
  - `FULL_TEST_URL=http://hostname:port/deployment/full/path?param=value`

## Suggested Invocation

- Natural language example: `Create a Virtualize service from Jira ticket PROJ-123`
- Slash command example: `/jira-story-virtual-service PROJ-123`