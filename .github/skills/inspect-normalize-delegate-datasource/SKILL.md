---
title: Inspect Normalize Delegate Datasource
description: "Use when a Virtualize asset already exists and you need to inspect it through REST, normalize desired datasource-backed response behavior into a deterministic packet, compute whether any changes are needed, and delegate datasource mutation only when required."
type: skill
scope: workspace
---

# Inspect Normalize Delegate Datasource

Inspect an existing Virtualize asset, normalize datasource intent into a deterministic packet, compute whether work is needed, and delegate only the necessary mutation.

## Contract

Use when: the baseline asset already exists; one PVA, one responder suite, and one file-based Message Responder can be isolated; the responder uses `requestResponseFiles`; and you want a no-op-capable wrapper around [add-data-source-file-responder](../add-data-source-file-responder/SKILL.md).

Stop immediately if: the target or responder topology is ambiguous; success or preserved interactions cannot be isolated safely; CSV rows, correlation, or response mappings are not deterministic; the source implies branching behavior without a decision matrix; or the requirement mandates explicit invalid-input fallback behavior outside narrow datasource-retrofit scope.

Required inputs: target asset ref, requirement source (`jira`, `file`, or `prompt`), datasource name, CSV columns and rows, correlation mapping, target success interaction, preserved interactions, response field mappings, optional inline-expression mappings, fallback-behavior expectation, and verification mode.

## ID Map

| ID | APIs |
| --- | --- |
| deployed virtual asset id | `POST /v6/virtualAssets/redeployments` |
| PVA path id | `GET /v6/children?id=...` |
| responder id | `GET` and `PUT /v6/tools/messageResponders?id=...` |
| file id | `GET /v6/files/download`, `POST /v6/files/upload?id=...` |

## Embedded API Contract Fragments

Use these local contract fragments instead of re-reading the full SOAVirt OpenAPI file during routine inspection and normalization.

### Datasource topology facts

- `POST /v6/datasources/csv` requires `name`, `parent`, `location`, `separator`, and `quote`
- For responder-driven CSV flows in this repo, `parent.id` must be verified as a writable suite-level container
- Expected parent for this topology: `Responder Suite`
- `.pva` file ids are not valid datasource-create parents for this flow

### Responder write facts

- `PUT /v6/tools/messageResponders` uses query parameter `id=<url-encoded-responder-id>`
- Mutation body should be derived from live responder `GET`
- Preserve unchanged fields; remove read-only envelope fields before `PUT`
- Query encoding is part of mutation correctness, not shell incidental detail

## Workflow

1. Inspect once and cache ids with `GET /v6/virtualAssets`, `GET /v6/children`, `GET /v6/tools/messageResponders`, `GET /v6/descendants/files`, and targeted file downloads. Inspect the live descendants payload shape first; this repo may return `children`.

1a. Resolve writable parent types before any create mutation. Do not infer writable parent ids from path shape alone. For `POST /v6/datasources/csv`, verify the live accepted `parent.id` type first. In this repo and server flow, datasource creation for a file responder is expected under the `Responder Suite` id, not the `.pva` file id.

2. Validate compatibility. Confirm `requestResponseFiles` mode, safe success-interaction isolation, preserved exact-match interactions, and a request file broad enough for the intended datasource-driven variation. If the request is too exact, either mark request broadening as required or stop and escalate.

3. Normalize into one packet containing `targetAssetRef`, `requirementSourceType`, `requirementSourceRef`, `virtualAssetId`, `targetPvaId`, `responderSuiteId`, `responderId`, `requestResponseFolderId`, `targetSuccessInteraction`, `preservedInteractions`, `datasourceName`, `csvColumns`, `csvRows`, `correlationMapping`, `responseFieldMappings`, `inlineExpressionMappings`, `fallbackBehaviorExpectation`, `currentState`, `desiredState`, `actionPlan`, and `verificationMode`.

4. Build state summaries. `currentState` must capture request breadth, CSV and datasource state, success response basis, responder binding, and deployed/enabled status. `desiredState` must capture desired request breadth, CSV, datasource, success response, responder binding, fallback expectation, and verification mode.

5. Compute the action plan. Required flags: `needsRequestFileBroadening`, `needsCsvFileCreate`, `needsCsvContentUpload`, `needsDatasourceCreate`, `needsDatasourceUpdate`, `needsResponsePatch`, `needsResponderBindingUpdate`, `needsRedeploy`, `needsVerification`. Set each from current-versus-desired comparison. If request broadening is needed but not authorized, stop and escalate. If datasource creation is needed but the writable parent type has not been verified, stop mutation and inspect topology first. If all mutation flags are false, return no-op.

6. Delegate only when needed. Pass the normalized packet and action plan to [add-data-source-file-responder](../add-data-source-file-responder/SKILL.md). That skill owns concrete mutation, responder `PUT`, redeploy, and live verification.

7. Preserve hardened runtime rules: file-id upload is the default write path, no-op writes should be skipped, responder `PUT` bodies must preserve unchanged fields, deployed assets must be redeployed after mutation, unresolved `${...}` placeholders are a verification failure, unmatched datasource rows may produce Virtualize correlation-error `404`, and explicit invalid-input fallback interactions are outside narrow datasource-retrofit scope.

8. Verify or return no-op. `smoke-200` minimum matrix: one live success request per datasource row, `200` for each configured success row, expected mapped values, no unresolved `${...}` placeholders, one unsupported correlation value test, and one missing required correlation input test when meaningful. `full-story` adds explicit source-defined error-path checks. If observed fallback behavior diverges from the source contract, fail or escalate.

## Output

Success with work: inspected asset summary, normalized packet summary, executed action list, verification result.

Success with no work: inspected asset summary, normalized packet summary, explicit no-op result.

Failure: exact compatibility gate, normalization gap, or validation failure.

## Examples

Cards-style:

```text
Asset: PGT-21
Source: file / cards.md
CSV: accountNumber,accountCentre with three rows
Correlation: urlPaths /api/v1/cards/accounts/{accountNumber} -> accountNumber
Verification: smoke-200
```

Loan-style:

```text
Asset: PGT-20
Source: jira / PGT-20
Check whether the success request is broad enough before delegation.
CSV: amount,approved,message,loanProviderName
Correlation: urlParameters amount -> amount
Fallback expectation: stop and escalate if explicit 500 handling is required
Verification: full-story
```

## Notes

- this skill is source-agnostic but topology-constrained
- no-op is a first-class success outcome
- do not absorb concrete mutation logic from the datasource skill
- treat writable parent type as part of the mutation contract, not as an implementation detail
- for CSV datasource creation in responder-driven flows, prefer verified `Responder Suite` parent ids over inferred `.pva` ids