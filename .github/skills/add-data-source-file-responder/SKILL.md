---
title: Add CSV Datasource to Existing File Responder
description: "Use when a Virtualize asset already exists and you need to add or update a CSV datasource, bind request-to-row correlation, parameterize a requestResponseFiles success response, and verify live behavior after creation from Jira, cards.md, or MCP."
type: skill
scope: workspace
---

# Add CSV Datasource to Existing File Responder

Use this skill to retrofit one success interaction of one file-based Message Responder with a CSV datasource.

## Use When

- baseline asset already exists
- exactly one target PVA, one `Responder Suite`, and one file-based Message Responder can be isolated
- responder uses `response.inputMode=requestResponseFiles`
- one success interaction can be updated without disturbing preserved exact-match interactions

## Do Not Use When

- service creation, broad redesign, or multi-responder mutation is required
- the task needs database or Excel datasources
- the request/response topology cannot be isolated deterministically
- the requirement demands explicit invalid-input fallback interactions such as custom `500` behavior

## Required Inputs

- target asset name or exact PVA path
- datasource name, or permission to use `Generated Data Source`
- CSV columns and rows
- correlation mapping: `urlPaths`, `urlParameters`, or explicit `xmlMessage`
- target success interaction
- response field mappings
- optional inline-expression mappings
- verification mode: `smoke-200` or `full-story`
- optional normalized packet and `actionPlan` from [inspect-normalize-delegate-datasource](../inspect-normalize-delegate-datasource/SKILL.md)

If `actionPlan` is provided, it controls execution. Do not widen scope beyond it.

## Stop Immediately If

- more than one plausible target PVA matches
- the responder is not a file-based Message Responder in `requestResponseFiles` mode
- the success interaction cannot be isolated safely
- CSV rows cannot be derived deterministically
- the source implies branching behavior but does not define the decision matrix
- the prompt does not provide exact rows and does not explicitly authorize synthetic sample rows
Retrofit one success interaction of one `requestResponseFiles` Message Responder with a CSV datasource.

## Contract

Use when: the asset already exists; one target PVA, one `Responder Suite`, and one file-based Message Responder can be isolated; one success interaction can be changed without disturbing preserved exact-match interactions.

Do not use when: service creation, broad redesign, multi-responder mutation, DB/Excel datasources, or custom invalid-input fallback interactions are required.

Required inputs: target asset ref, datasource name, CSV columns and rows, correlation mapping (`urlPaths`, `urlParameters`, or explicit `xmlMessage`), target success interaction, response field mappings, optional inline-expression mappings, verification mode, and optionally a normalized packet plus `actionPlan`.

If `actionPlan` exists, only run flagged phases. Expected flags: `needsCsvFileCreate`, `needsCsvContentUpload`, `needsDatasourceCreate`, `needsDatasourceUpdate`, `needsResponsePatch`, `needsResponderBindingUpdate`, `needsRedeploy`, `needsVerification`.

Stop immediately if: the target or responder is ambiguous; the responder is not `requestResponseFiles`; the success interaction cannot be isolated safely; CSV rows, correlation, or response mappings are not deterministic; the source implies branching behavior without a decision matrix; synthetic rows would be needed without explicit authorization; or the requirement expects custom invalid-input fallback behavior outside narrow datasource-retrofit scope.

## ID Map

| ID | APIs |
| --- | --- |
| deployed virtual asset id | `POST /v6/virtualAssets/redeployments` |
| PVA path id | `GET /v6/children?id=...` |
| responder id | `GET` and `PUT /v6/tools/messageResponders?id=...` |
| file id | `GET /v6/files/download`, `POST /v6/files/upload?id=...` |

## Embedded API Contract Fragments

Use these local contract fragments instead of re-reading the full SOAVirt OpenAPI file during routine datasource-retrofit work.

### CSV datasource create

- Endpoint: `POST /v6/datasources/csv`
- Required request fields: `name`, `parent`, `location`, `separator`, `quote`
- `parent.id` must point to a writable suite-level container for this workflow
- In this repo and server flow, use the `Responder Suite` id, not the `.pva` file id
- `location.id` points to the CSV file id

Shape:

```json
{
   "name": "Generated Data Source",
   "parent": { "id": "/.../PGT-20.pva/Responder Suite" },
   "location": { "id": "/.../pgt20_loan_matrix.csv" },
   "separator": ",",
   "quote": "\"",
   "firstRowSpecifiesColumnNames": true,
   "trimLeadingAndTrailingWhitespace": true
}
```

### Message responder update

- Endpoint: `PUT /v6/tools/messageResponders?id=<url-encoded-responder-id>`
- Build body from captured responder `GET` payload
- Remove read-only envelope fields such as `id`, `url`, `relationships`
- Keep unchanged responder fields intact
- Send encoded query in URL first, then JSON body second
- Do not combine `curl -G` query construction with body `--data` in same `PUT`

Shape:

```json
{
   "dataSource": "Generated Data Source",
   "dataSourceCorrelation": {
      "urlPaths": [],
      "urlParameters": [
         { "parameterName": "amount", "columnName": "amount" },
         { "parameterName": "downPayment", "columnName": "downPayment" }
      ],
      "xmlMessage": []
   }
}
```

## Workflow

1. Discover and cache ids with `GET /v6/virtualAssets`, `GET /v6/children`, `GET /v6/tools/messageResponders`, and `GET /v6/descendants/files`. Preserve the full responder payload for later `PUT`. Inspect the live descendants payload shape first; this repo may return `children`.

2. Isolate the success interaction. Download request files first, classify interactions, preserve exact-match error interactions, then download only the target success response file. Matching rules come from [virtualize-correlation-matching-rules](../virtualize-correlation-matching-rules/SKILL.md).

3. Check request breadth before datasource work. If behavior varies by path or query value, an exact sample request may block datasource correlation. Query-style broad form:

```http
GET /parabank/services/bank/requestLoan?{*} HTTP/1.1
```

If broadening is required but not authorized, stop and escalate.

4. Build desired state and no-op decisions from request breadth, CSV content, success response content, and responder datasource block. If all requested mutations are already satisfied, return no-op.

5. Create or update the CSV file with the hardened path only: `POST /v6/files`, then `POST /v6/files/upload?id=<csvFileId>&replace=true`, then re-download and verify exact content. Folder-target upload is compatibility-only.

6. Create or update the datasource with `POST` or `PUT /v6/datasources/csv`. Verify the writable parent type before `POST`. Do not infer `parent.id` from the `.pva` path alone. In this repo and server flow, datasource creation for a file-based responder is expected under the `Responder Suite` id, for example `/.../PGT-20.pva/Responder Suite`. Verify the datasource record, its columns, and at least one expected row.

7. Decide unmatched-row behavior before continuing. Record one outcome: correlation failure acceptable, broader workflow required for explicit fallback behavior, or requirement under-specified. Validated runtime fact: unmatched rows returned a Virtualize correlation-error `404` even when responder `returnStatus` stayed `500`.

8. Patch only the selected success response. Use `${column}` for datasource-backed fields. Use [virtualize-inline-expressions](../virtualize-inline-expressions/SKILL.md) for dynamic fields such as `${{=sv:date-math('0d', 'yyyy-MM-dd')}}`, `sv:url-path(...)`, and `sv:url-parameter('fromAccountId')`. Re-download after upload.

9. Bind the datasource on the responder. Build `PUT /v6/tools/messageResponders` from the captured `GET` payload. Preserve unchanged fields. Update only datasource-specific fields.

If using `curl`, do not combine `-G` with body `--data` in the same `PUT` request. Encode the responder id into the final URL first, then send the JSON body separately with a plain `PUT`. Treat query encoding as mutation-critical: a malformed query string can fail before the responder payload is evaluated.

Path example:

```json
{
   "dataSource": "Generated Data Source",
   "dataSourceCorrelation": {
      "urlPaths": [{ "pathTemplate": "/api/v1/cards/accounts/{accountNumber}", "pathParameterName": "accountNumber", "columnName": "accountNumber" }],
      "urlParameters": [],
      "xmlMessage": []
   }
}
```

Query example:

```json
{
   "dataSource": "Generated Data Source",
   "dataSourceCorrelation": {
      "urlPaths": [],
      "urlParameters": [
         { "parameterName": "amount", "columnName": "amount" },
         { "parameterName": "downPayment", "columnName": "downPayment" }
      ],
      "xmlMessage": []
   }
}
```

10. Re-read and redeploy if live. Re-read the responder after `PUT`. If the asset is deployed, redeploy after any responder or request/response file mutation.

## Verification

Structural checks: datasource exists under the target asset; columns and rows match the uploaded CSV; responder points to the datasource; correlation matches the intended request value; success response contains the intended placeholders or inline expressions; preserved exact-match error interactions remain unchanged; broadened request, if used, still isolates the intended success interaction.

`smoke-200` minimum matrix: one live success request for each configured datasource row, `200` for each configured success row, expected mapped values, no unresolved `${...}` placeholders, one unsupported correlation value test, and one missing required correlation input test when meaningful.

`full-story` adds explicit source-defined error-path checks. Fail or escalate if observed fallback behavior diverges from the source contract.

## Examples

Cards-style:

```text
Asset: PGT-21
CSV: accountNumber,accountCentre with three rows
Correlation: urlPaths /api/v1/cards/accounts/{accountNumber} -> accountNumber
Verification: smoke-200
```

Loan-style:

```text
Asset: PGT-20
First verify the success request is broad enough, or broaden it in a broader workflow.
CSV: amount,approved,message,loanProviderName
Correlation: urlParameters amount -> amount
Inline field example: accountId -> sv:url-parameter('fromAccountId')
Verification: full-story, including unsupported and missing amount tests
```

Wrapper-driven:

```text
Use the normalized packet and actionPlan from inspect-normalize-delegate-datasource. If all requested mutations are already satisfied, return no-op. Otherwise perform only the flagged phases, redeploy only when required, and verify per the selected mode.
```

## Notes

- file-id upload after `POST /v6/files` is the default hardened path
- datasource binding here is responder-level, not virtual-asset data-group configuration
- this skill is topology-specific, not source-specific
- for `POST /v6/datasources/csv`, `parent.id` must be verified as a writable suite-level container before create
- for responder `PUT` calls with query params and JSON body, build the encoded URL first and send the body second; do not mix `curl -G` query construction with body payload submission
- re-read the responder after `PUT` and fail the workflow if expected datasource fields are absent
- explicit invalid-input fallback interaction authoring is out of scope
- explicit invalid-input fallback interaction authoring is out of scope