# Setup Guide

This document walks through every step needed to get the
**VirtualizeMCPDemo** workflow running end-to-end.

---

## 1. Register a self-hosted GitHub Actions runner

The workflow must run on the same machine (or network) as your
Parasoft Virtualize server so the agent can reach the locally-deployed
Virtualize MCP Server.

1. In your GitHub repository go to **Settings → Actions → Runners → New self-hosted runner**.
2. Select the OS of the machine running Virtualize, then follow the
   on-screen installation commands.
3. Start the runner service (`./run.sh` or install as a service with `./svc.sh install && ./svc.sh start`).
4. Verify it appears as **Idle** in the Runners list.

> **Tip:** assign a custom label (e.g. `virtualize-host`) to the runner
> and update `runs-on` in the workflow file accordingly.

---

## 2. Install runtime prerequisites on the runner machine

| Tool | Minimum version | Install guide |
|------|----------------|---------------|
| Node.js | 20 LTS | <https://nodejs.org> |
| npm | 10+ | Bundled with Node.js |

The workflow installs GitHub Copilot CLI automatically via `npm install -g @github/copilot`.
No other runtime dependencies are required.

---

## 3. Start the Parasoft Virtualize MCP Server

Consult your Parasoft Virtualize documentation for the exact steps to start
the built-in MCP Server. In general:

1. Open Virtualize and navigate to the MCP Server settings.
2. Start the server and note its HTTP endpoint URL.
3. Confirm it is reachable from the runner machine:
   ```bash
   curl http://localhost:9080/soavirt/mcp
   ```
4. Set the `VIRTUALIZE_MCP_URL` secret to that full URL.

---

## 4. Add GitHub Actions secrets

In **Settings → Secrets and variables → Actions → New repository secret**,
add each of the following:

| Secret name | Where to get the value |
|-------------|------------------------|
| `COPILOT_PAT` | Fine-grained PAT with **Copilot Requests** permission — create at <https://github.com/settings/personal-access-tokens/new> |
| `ATLASSIAN_BASIC_AUTH` | Run `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("email@example.com:api-token"))` in PowerShell |
| `VIRTUALIZE_AUTH_TOKEN` | Run `[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("username:password"))` in PowerShell |
| `VIRTUALIZE_MCP_URL` | HTTP endpoint of the Virtualize MCP Server (step 3) |

> **Atlassian API token auth**: In your Atlassian Admin console go to
> **Rovo → MCP server** and enable **Allow authentication via API token**.
> Then generate a Rovo API token at <https://id.atlassian.com/manage-profile/security/api-tokens>.

---

## 5. (Optional) Test locally before running in CI

```powershell
# Install Copilot CLI
npm install -g @github/copilot

# Write MCP config
$atlassianAuth = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("email@example.com:api-token"))
$virtAuth      = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("user:password"))

mkdir ~/.copilot -Force
@"
{
  "mcpServers": {
    "jira-remote": {
      "type": "http",
      "url": "https://mcp.atlassian.com/v1/mcp",
      "headers": { "Authorization": "Basic $atlassianAuth" },
      "tools": ["*"]
    },
    "virtualize": {
      "type": "http",
      "url": "http://localhost:9080/soavirt/mcp",
      "headers": { "Authorization": "Basic $virtAuth" },
      "tools": ["*"]
    }
  }
}
"@ | Set-Content ~/.copilot/mcp-config.json

# Run the agent
$env:COPILOT_GITHUB_TOKEN = "<your-PAT>"
copilot -p "Jira ticket: PROJ-123. Read the story and create the virtual service it describes." `
  --allow-tool='mcp(*)' --no-ask-user
```

---

## 6. Trigger the workflow

1. Go to **Actions → Create Virtual Service from Jira Story**.
2. Click **Run workflow**.
3. Enter the Jira ticket number (e.g. `PROJ-123`).
4. Optionally override the Virtualize server URL or enable **dry run** mode.
5. Click **Run workflow** to start.

The agent log and a JSON summary are available as a downloadable artifact
once the run completes.
