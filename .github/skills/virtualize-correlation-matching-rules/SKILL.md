---
title: Virtualize Request-Response Correlation and Matching Rules
description: How to create or update Virtualize virtual asset responses to correlate with a given request.
type: skill
scope: workspace
---
# Virtualize Request-Response Correlation and Matching Rules

When creating or updating a Virtualize virtual asset, you can define correlation and matching rules to ensure that incoming requests are correctly matched to the appropriate response based on their content.


## Correlation and matching rules
- Request correlation inputs:
  - Correlate primarily from the request first line: HTTP method, URL path, and URL query parameters
  - Also correlate on the request body content specified after headers when a body exists
  - Do not use request headers as correlation keys; headers present in request files are informational and must not drive match selection
- Path matching behavior:
  - Incoming requests are allowed to have any number of additional URL path segments prepended
  - The final path segments of the incoming request must match the configured request path segments in the request file
  - When multiple candidates match, select the candidate with the greatest number of matching path segments
  - If multiple candidates tie on segment count, select the candidate whose filename comes first alphabetically
- Multi-interaction implementation guidance:
  - When the task context implies multiple request/response behaviors for the same endpoint, create distinct interactions that preserve deterministic matching under the rules above
  - Prefer explicit exact-match interactions for known story examples before adding broader patterns

## Wildcard rules
- Wildcards are supported, but exact matches always take precedence over wildcard matches
- URL path wildcard forms:
  - `*` in a path segment to match any value in that segment
  - `{parameterName}` in a path segment to match any value in that segment
  - The text used inside `{parameterName}` is descriptive only and does not change matching behavior
- URL query wildcard form:
  - Use `?{*}` as the full query-string wildcard to match any query value set
  - Example pattern: `POST /parabank/services/bank/billpay?{*}`
- Payload wildcard form:
  - Use `{*}` as the entire payload to match any request body
- Regex and pattern limitations:
  - Regular expressions are not supported for URL or payload matching
  - To model distinct non-wildcard variants, create separate exact request/response pairs rather than relying on regex-like patterns

---

## When to Use

- **Creating or modifying request/response file pairs tied to a virtual service**
- **Creating exact match responses that correlate to a specific request pattern defined in a request file**
- **Creating a catch-all response that uses wildcard correlation to match any request**