---
title: Virtualize Asset Validation Instructions
description: Instructions for validating the behavior of a Virtualize virtual asset
type: skill
scope: workspace
---
# Virtualize Asset Validation Instructions

When testing a Virtualize virtual asset, follow these instructions to validate the asset's behavior against expected outcomes.

## Environment Detection
Before running any test commands, detect the current shell environment:
- **Linux / macOS / WSL / Git Bash**: use the Unix toolchain (see below).
- **Windows PowerShell / pwsh**: use the PowerShell toolchain (see below).

To detect automatically, check for `$PSVersionTable` (present in PowerShell) or the `$SHELL` environment variable (present in Unix shells). When uncertain, prefer PowerShell on Windows and Unix tools on all other platforms.

## Testing Policy
- Do not use Python scripts or Python one-liners for testing APIs, parsing responses, or validating results.
- Choose the toolchain that matches the active shell environment (see sections below).
- Keep test commands short, reproducible, and easy to rerun from terminal history.
- In this VS Code agent environment, use `run_in_terminal` for live validation commands.
- Execute validation through terminal/shell tooling. Do not use VS Code UI commands, placeholder commands, or command probes such as `noop`, `workbench.action.terminal.sendSequence`, or `workbench.action.closeMessages` as substitutes for live HTTP checks.
- Do not use `run_vscode_command` or VS Code tasks to drive API validation when direct terminal execution is available.

## Unix Toolchain (Linux / macOS / WSL / Git Bash)
- For API testing, prefer `curl` commands with clear request headers and payloads:
  ```sh
  curl -i -sS -X GET "http://localhost:9080/api/endpoint" -H "Accept: application/json"
  ```
- For response checks, prefer shell-native tools such as `grep`, `sed`, `awk`.
- If structured JSON validation is required, use `jq` instead of Python:
  ```sh
  curl -sS http://localhost:9080/api/endpoint | jq '.fieldName'
  ```

## PowerShell Toolchain (Windows PowerShell / pwsh)
- For API testing, use `Invoke-RestMethod` (returns parsed objects) or `Invoke-WebRequest` (returns raw response):
  ```powershell
  $response = Invoke-RestMethod -Uri "http://localhost:9080/api/endpoint" -Method GET -Headers @{ Accept = "application/json" }
  ```
- To inspect status codes, use `Invoke-WebRequest` and check the `StatusCode` property:
  ```powershell
  $r = Invoke-WebRequest -Uri "http://localhost:9080/api/endpoint" -Method GET
  $r.StatusCode   # e.g. 200
  ```
- For JSON field validation, use `ConvertFrom-Json` (equivalent to `jq`):
  ```powershell
  $json = Invoke-RestMethod -Uri "http://localhost:9080/api/endpoint"
  $json.fieldName
  ```
- For text pattern matching (equivalent to `grep`), use `Select-String`:
  ```powershell
  $r.Content | Select-String "expectedValue"
  ```
- Avoid using the `curl` alias in Windows PowerShell; it maps to `Invoke-WebRequest` but behaves differently from the Unix `curl` binary.

## Preferred Workflow
1. Detect the active shell environment.
2. Run API calls using the appropriate toolchain above.
3. Validate status codes and required fields with the matching shell tools.
4. Keep test commands short, reproducible, and easy to rerun from terminal history.
5. If a first post-change validation is required, run the live shell command immediately; do not detour through editor-command experiments.
6. If a validation command can be run directly in terminal, do not route through task runners or VS Code command wrappers first.

## Datasource Responder Validation

When a requestResponseFiles responder uses datasource row correlation, treat live validation as required acceptance criteria, not an optional spot check.

Minimum validation matrix:
1. one live request for each configured datasource row
2. one live request with an unsupported correlation value
3. one live request with a missing required correlation input when the request shape makes that meaningful
4. confirmation that the response does not contain unresolved literal placeholders such as `${...}`

Validation rules:
- verify the expected status and mapped response fields for each configured datasource row
- if unmatched datasource rows return a Virtualize correlation-error response such as `404`, record that exact behavior
- if the requirement source expected a different invalid-input status such as `500`, report the divergence as a failure or escalation point
- for deployed assets, validate live behavior after redeploy, not only the REST mutation results

Unix example pattern:

```sh
curl -i -sS "http://localhost:38000/VirtualizeMCPDemo/api/v1/cards/accounts/1234"
curl -i -sS "http://localhost:9095/VirtualizeMCPDemo/parabank/services/bank/requestLoan?customerId=12212&amount=1000&downPayment=100&fromAccountId=13344"
curl -i -sS "http://localhost:9095/VirtualizeMCPDemo/parabank/services/bank/requestLoan?customerId=12212&amount=9999&downPayment=100&fromAccountId=13344"
```

PowerShell example pattern:

```powershell
$ok = Invoke-WebRequest -Uri "http://localhost:9095/VirtualizeMCPDemo/parabank/services/bank/requestLoan?customerId=12212&amount=1000&downPayment=100&fromAccountId=13344" -Method GET
$bad = Invoke-WebRequest -Uri "http://localhost:9095/VirtualizeMCPDemo/parabank/services/bank/requestLoan?customerId=12212&amount=9999&downPayment=100&fromAccountId=13344" -Method GET -SkipHttpErrorCheck
$ok.StatusCode
$bad.StatusCode
```

## Scope
These instructions apply to all testing actions in this repository.