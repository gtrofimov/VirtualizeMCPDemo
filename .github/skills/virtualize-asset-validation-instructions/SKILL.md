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

## Scope
These instructions apply to all testing actions in this repository.