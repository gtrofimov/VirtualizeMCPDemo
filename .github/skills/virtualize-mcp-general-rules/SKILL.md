---
title: Virtualize MCP General Rules
description: General guardrails and known behaviors when using the Virtualize MCP tools to create and manage virtual services.
type: skill
scope: workspace
---
# Virtualize MCP General Rules

These rules apply whenever using the `manageVirtualServices` MCP tool (or any Virtualize MCP tool) to create or manage virtual services. They encode known tool behaviors and common agent mistakes to avoid.

---

## Initial Asset Creation Boundary

Initial PVA creation must use Virtualize MCP tools only.

- Never create the initial virtual asset through REST APIs, local file generation, staging-directory commits, or any other fallback workflow.
- If the required Virtualize MCP creation tool is unavailable in the current session, stop initial asset creation immediately and report that blocker instead of attempting a substitute path.
- REST and file-level APIs may be used only after a baseline asset already exists, and only when a downstream skill explicitly permits post-creation mutation.

---

## Pre-Creation Uniqueness Checks

Before creating any virtual service, run a single `manageVirtualServices action=list` call to enumerate all existing MCP-managed services. Each entry is of the form:

```
<serviceName> (Base path: http://localhost:{port}/{deployment})
```

From this single response, collect three sets:
- **Occupied names** — the `<serviceName>` portion of each entry
- **Occupied ports** — the `{port}` segment parsed from each base path URL
- **Occupied deployment prefixes** — the `{deployment}` segment parsed from each base path URL

One `list` call satisfies all three checks — do not make redundant calls.

> Note: only services created through the MCP tool are visible; names, ports, and deployment prefixes used by non-MCP services on the same Virtualize instance cannot be detected this way.

### Service name uniqueness
- If the intended service name already exists in the occupied set, append `-1`, `-2`, etc. until the name is unique.

### Port uniqueness
- If the source workflow or story defines an explicit port, treat that as required unless the user approves a change.
- If the source workflow or story defines a port range, choose the lowest port in that range that is not present in the occupied set.
- Only when no source-defined port constraint exists, start from the default port (`38000`) and choose the lowest port not present in the occupied set.
- Do not silently fall back outside a source-defined range.
- Never reuse an occupied port.

### Deployment prefix uniqueness
- If the intended deployment prefix already exists in the occupied set, append `-1`, `-2`, etc. until the prefix is unique.

---

## Request Content Path Format

When calling `manageVirtualServices` with `action=create` or `action=update`, the `requestContent` field must contain **only the raw API path** — never the deployment prefix.

**Correct:**
```
POST /parabank/services/bank/requestLoan?customerId=12212&amount=1000 HTTP/1.1
Content-Type: application/json
```

**Incorrect (deployment prefix included):**
```
POST /VirtualizeMCPDemo/parabank/services/bank/requestLoan?customerId=12212&amount=1000 HTTP/1.1
Content-Type: application/json
```

### Why

The `deployment` and `requestContent` parameters are independent concerns:

- `deployment` is the proxy path the tool registers at the given port (e.g., `/VirtualizeMCPDemo`). It is not part of the request-matching file content.
- `requestContent` is stored verbatim in the request file used by the responder for matching.
- The tool constructs the example invocation URL as `http://localhost:{port}/{deployment}/{requestContent path}`. Including the deployment in the requestContent path causes it to appear twice in the URL.

### How matching works at runtime

When a client calls `http://localhost:{port}/{deployment}/{apiPath}`, the proxy layer strips the deployment prefix and routes to the responder. The responder then matches against the stored request file path. Because Virtualize path matching allows any number of leading path segments to be prepended to the configured path (see `virtualize-correlation-matching-rules`), a stored path of `/parabank/services/bank/requestLoan` correctly matches an incoming internal path of `/requestLoan/parabank/services/bank/requestLoan`.

### Diagnostic signal

If the `manageVirtualServices create` response returns an example URL that contains the deployment prefix twice (e.g., `/VirtualizeMCPDemo/VirtualizeMCPDemo/...`), this is a clear indicator that the deployment prefix was incorrectly included in `requestContent`. Delete the service and recreate it with only the raw API path.

---

## Empty Request Bodies

When a story specifies that the request body is empty (no payload), the request file must truly contain no payload — not even `{}`.

- Virtualize matching is payload-sensitive: a request file with no payload will fail to match an incoming request that carries any body content, and vice versa.
- When testing empty-body interactions, send POST requests that genuinely omit any body content.

---

## Validating Wildcard Interactions

The `manageVirtualServices action=describe` output does not faithfully reflect wildcard (`?{*}`) interactions at runtime. A wildcard interaction may appear absent or non-matching in `describe` output but work correctly against live requests.

- Always validate wildcard interactions by sending live test requests to the deployed endpoint.
- Do not conclude a wildcard is broken based solely on `describe` output.

---

## Downloading, Modifying, and Re-uploading Request/Response Files

It is normal and expected for an agent to download the request/response files of an existing virtual service in order to enrich or extend them — for example, to add inline expressions, correlation rules, or additional interactions — and then re-upload the modified files back to the server. Use the following guidance any time this pattern is needed.

## Virtualize REST Write Guardrails

For REST create and update operations, validate the writable target type before mutation. Do not infer allowed parent containers from filename or path shape alone.

For HTTP writes that require both query parameters and a JSON body, avoid mixed transport construction patterns such as `curl -G` plus body `--data` in the same call. Build the encoded URL first, then send the body with a plain `POST` or `PUT`.

When the same REST contract detail has already been proven stable for a workflow, prefer embedding that narrow contract fragment in the owning skill instead of re-reading the full SOAVirt schema on every run. Re-open the schema only when the workflow reaches an uncovered endpoint, an ambiguous field, or a server-version mismatch.

### Choosing an approach

Before downloading and re-uploading files, consider whether a simpler path applies:

- **Fixing or replacing the response for a specific interaction** (e.g. correcting an inline expression, changing a status code) — call `manageVirtualServices action=update` with `requestContent` set to the matching request and `responseContent` set to the corrected response. No download or file manipulation is needed.
- **Adding a new interaction** — same as above; each `action=update` call appends a new request/response pair.
- **Bulk modifications across many interactions, or changes that cannot be expressed via `requestContent`/`responseContent`** — use the `directoryPath` or staging workflow below.

### Preferred approach — `directoryPath` on `update`

After downloading and modifying files locally, call `manageVirtualServices` with `action=update` and `directoryPath` set to the local directory containing the modified files. This bypasses the upload API entirely and is the simplest path.

### Alternative — upload zip and `commitFromStaging`

If the `directoryPath` approach is not applicable, use the full staging workflow:

1. **Download** — call `manageVirtualServices action=download`. The tool creates a staging directory on the server and returns the zip download URL and staging path.
2. **Modify** — download the zip, extract, edit the request/response files locally.
3. **Re-upload** — POST the modified zip back to the staging path using `multipart/form-data` with a field named `file`:
   ```
   POST /soavirt/api/v6/files/upload?id=<stagingPath>&replace=true
   Content-Type: multipart/form-data; boundary=<boundary>

   --<boundary>
   Content-Disposition: form-data; name="file"; filename="<service>.zip"
   Content-Type: application/zip

   <binary zip content>
   --<boundary>--
   ```
   The endpoint returns `HTTP 415` for `application/octet-stream` or `application/zip` as the top-level content type — `multipart/form-data` is the only accepted form.
4. **Commit** — call `manageVirtualServices action=update` with `commitFromStaging` set to the staging directory name returned in step 1.
