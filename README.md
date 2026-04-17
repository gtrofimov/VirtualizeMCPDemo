# VirtualizeMCPDemo

A showcase of how to use **GitHub Actions** (self-hosted runner) with AI
automation to read a Jira user story and automatically create and deploy a
virtual service on a locally-running **Parasoft Virtualize** server — all
orchestrated by **GitHub Copilot CLI** via the **Model Context Protocol (MCP)**.

---

## How it works

```
┌───────────────────────────────────────────────────────────────────┐
│  GitHub Actions  (self-hosted runner on the same host as          │
│                   Parasoft Virtualize)                            │
│                                                                   │
│  ┌───────────────────────────────────────────────────────────┐    │
│  │  GitHub Copilot CLI  (programmatic / --no-ask-user)       │    │
│  │                                                           │    │
│  │   ┌──────────────────┐    ┌───────────────────────────┐   │    │
│  │   │  Jira MCP Server │    │  Virtualize MCP Server    │   │    │
│  │   │  (Atlassian      │    │  (local HTTP endpoint)    │   │    │
│  │   │   Remote MCP)    │    │                           │   │    │
│  │   │  • get_issue     │    │  • list_virtual_services  │   │    │
│  │   │  • search_issues │    │  • create_virtual_service │   │    │
│  │   │  • …             │    │  • deploy / start / stop  │   │    │
│  │   └──────────────────┘    └───────────────────────────┘   │    │
│  └───────────────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────────────┘
```

1. You trigger the workflow (`workflow_dispatch`) with a Jira ticket number.
2. Copilot CLI reads the story via the **Atlassian Remote MCP Server** (`mcp.atlassian.com`).
3. Copilot extracts the API specification from the story and calls the
   **Parasoft Virtualize MCP Server** (running locally on the runner) to
   create and deploy the virtual service.
4. The workflow verifies the deployed service responds with HTTP 200 using
   the test URL the agent emits as part of its summary.

---

## Repository layout

```
.
├── .github/
│   └── workflows/
│       └── create-virtual-service.yml   # GitHub Actions workflow
├── docs/
│   ├── setup.md                         # Full setup guide
│   └── jira-story-format.md             # Required Jira story structure
└── mcp.json                             # MCP server config reference (documentation)
```

---

## Quick start

### 1 — Prerequisites

| Requirement | Notes |
|---|---|
| Self-hosted GitHub Actions runner | Must be on the same machine as Parasoft Virtualize |
| Parasoft Virtualize | With the MCP Server enabled and running |
| GitHub Copilot Business subscription | Required to use Copilot CLI |
| Atlassian Jira Cloud | API token from [id.atlassian.com](https://id.atlassian.com/manage-profile/security/api-tokens) |
| Node.js 20+ | Required to install Copilot CLI via npm |

### 2 — Configure GitHub Secrets

Add the following secrets in **Settings → Secrets and variables → Actions**:

| Secret | Description |
|---|---|
| `COPILOT_PAT` | Fine-grained PAT with **Copilot Requests** permission |
| `ATLASSIAN_BASIC_AUTH` | `base64(your-email@example.com:your-api-token)` — see setup guide |
| `VIRTUALIZE_AUTH_TOKEN` | `base64(virtualize-user:virtualize-password)` |
| `VIRTUALIZE_MCP_URL` | URL of the Virtualize MCP Server HTTP endpoint |

### 3 — Configure MCP servers

The workflow writes `~/.copilot/mcp-config.json` on the runner automatically
from your secrets. See **`mcp.json`** in the repo root for the reference
structure, and **[docs/setup.md](docs/setup.md)** for details on enabling
API token auth in Atlassian Rovo and the Virtualize MCP Server.

### 4 — Write your Jira story

See **[docs/jira-story-format.md](docs/jira-story-format.md)** for the
recommended story structure that gives the agent everything it needs.

### 5 — Run the workflow

Go to **Actions → Create Virtual Service from Jira Story → Run workflow**,
enter your Jira ticket number, and click **Run workflow**.

---

## Customisation

- **Change the prompt**: edit the prompt heredoc in the `Run Copilot Agent - Create Virtual Service from Jira Story` step of the workflow.
- **Lock down tool permissions**: the workflow uses `--yolo` (all tools allowed) as a workaround for a known Copilot CLI bug where `--allow-tool` does not work in `--prompt` / `-p` mode ([issue #1592](https://github.com/github/copilot-cli/issues/1592)). Once that bug is fixed, replace `--yolo` with `--allow-tool='jira-remote' --allow-tool='virtualize'`.
- **Different Virtualize MCP URL**: update the `VIRTUALIZE_MCP_URL` secret.
- **Additional workflow triggers** (e.g. on issue label): extend the `on:` block in the workflow file.

---

## Detailed setup

See **[docs/setup.md](docs/setup.md)** for step-by-step instructions including
self-hosted runner registration and Parasoft Virtualize MCP Server configuration.
