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

## Source-of-Truth Rule

If the user input contains a ticket-shaped key such as `PGT-20` or `PROJ-123`, treat Jira as the only authoritative source for story details on the first pass.

- Always fetch the real Jira issue before inferring behavior from local repo files, skills, cards, or examples.
- Local repo materials may be used only as supplemental implementation context after the Jira issue has been read.
- If the Jira lookup fails, the Jira tools are unavailable, or the issue cannot be read, stop and report that blocker.
- Do not silently fall back to local examples or similarly named repo content unless the user explicitly approves that fallback.

## Mandatory Guardrails

1. Jira cloudId guardrail
- Always call Jira tools with `cloudId: parasoft-demo.atlassian.net`
- Never derive or guess cloudId from URLs, usernames, or emails

2. Jira-key resolution guardrail
- If the prompt includes a ticket-shaped key matching `[A-Z]+-\d+`, you must resolve that issue from Jira before creating or modifying a service.
- Do not treat local sample stories, local docs, or skill examples as substitutes for the Jira issue.
- If no exact Jira issue can be read, stop and surface the blocker instead of inferring the story from local context.

3. Service naming guardrail
- Infer service name from the Jira story when confidence is high
- If confidence is low, use the Jira ticket key as the default name

4. Port selection guardrail
- If the story defines an explicit port, use it
- If the story defines a port range, choose the lowest unoccupied port within that range
- If the story defines both a preferred port and a range, the chosen port must satisfy the range
- If no confident port or range is present in the story, default to `38000`
- Never ignore a story-defined port constraint in favor of the generic `38000` default

5. Deployment prefix guardrail
- If no confident deployment prefix is present, default to the repo name `VirtualizeMCPDemo`

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
- If the input was a ticket-shaped key, complete this Jira fetch before reading local story examples for implementation help.
- If local repo materials describe a similar endpoint but disagree with Jira or are less specific, Jira wins.
- If the story implies branching behavior such as approval versus denial, valid versus invalid inputs, or multiple success outcomes, confirm that it also defines a deterministic decision matrix.
- If the story provides only one example but implies multiple behavioral outcomes, stop and ask for the missing matrix instead of inventing datasource rows or fallback behavior silently.

2. Resolve required values and approvals
- Resolve and finalize:
  - service name
  - deployment prefix
  - port
  - interactions to create
  - assumptions/defaults
- Treat an explicit story-defined port or port range as higher priority than skill defaults or prior examples.
- If every port in the story-defined range is occupied, stop and report that constraint conflict instead of silently falling back outside the range.
- If any mandatory gate is not satisfied, stop and ask for explicit approval/input

3. Create virtual service
- Create and deploy service via Virtualize MCP
- Leverage virtualize-* skills as needed for request/response file enrichment
  - When constructing response content, inspect each response property for fields like dateTimes, timestamps, auto-generated ID characteristics, or any request parameters that appear to be echoed back in the response. For any such field, apply inline expressions per the virtualize-inline-expressions skill rather than hard-coding the example value from the story.
- Include at least one catch-all `200` response for valid request shapes so requests with values deviating from examples still receive a `200` response.

4. Verification and final output
- Confirm deployment success by testing the endpoint from terminal toolchain before finishing
- In this VS Code agent environment, use `run_in_terminal` for live HTTP validation.
- Never use `run_vscode_command`, VS Code tasks, terminal send-sequence helpers, or editor-command probes for API validation.
- Do not use VS Code UI commands or placeholder commands such as `noop` to validate HTTP behavior
- Provide concise summary:
  - service name
  - deployment prefix
  - endpoint(s)
  - port
  - assumptions/defaults used
- End with exact lines:
  - `TEST_METHOD=<METHOD>`
  - `FULL_TEST_URL=http://hostname:port/deployment/full/path?param=value`
  - `FULL_EXTERNAL_URL=http://<resolved-external-ip>:port/deployment/full/path?param=value`
    - Resolve the external IP from the base path URL returned by the `manageVirtualServices create` response (e.g. the example invocation URL it returns). Use that IP verbatim — do not substitute `localhost` or guess the hostname.

## Suggested Invocation

- Natural language example: `Create a Virtualize service from Jira ticket PROJ-123`
- Slash command example: `/jira-story-virtual-service PROJ-123`