---
title: SOAVirt Inline Expressions for Dynamic Responses
description: Update SOAVirt virtual asset responses with dynamic values extracted from requests, timestamps, headers, and URLs
type: skill
scope: workspace
---

# SOAVirt Inline Expressions for Dynamic Responses

Use inline expressions in SOAVirt response files to dynamically populate values based on incoming requests, generate timestamps, extract headers, or use URL parameters.

## Syntax

All inline expressions use the `${{=expression}}` format.

### Rules
- Use **single quotes only** in expressions (`'` not `"`)
- Do not use curly brackets `{}` inside expressions or default values
- Default values use the `#` separator: `${{=expression#defaultValue}}`

---

## Date-Time Manipulation

### Current Time with Offset
```
${{=sv:date-math('offset', 'outFormat')}}
```
Example: `${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}`

Use explicit date patterns for `outFormat`.
Avoid aliases such as `ISO8601`, which may fail depending on runtime date parser support.

#### ⚠ Avoid literal `T` and `Z` inside a format string argument
The Virtualize date parser treats `T` and `Z` as pattern letters (or a combined `TZ` timezone token), so embedding them directly in a format string causes a runtime error such as `Unknown pattern letter: TZ`.

**Do NOT do this:**
```
${{=sv:date-math('0h', 'yyyy-MM-ddTHH:mm:ss.SSS')}}Z
```

**ISO 8601 workaround — split into two expressions:**
```
${{=sv:date-math('0h', 'yyyy-MM-dd')}}T${{=sv:date-math('0h', 'HH:mm:ss.SSS')}}Z
```
This produces output like `2026-06-02T16:49:14.827Z` by placing the literal `T` and `Z` as plain text between and after the two `date-math` calls.

**Offset format:** `'1y 2M 3d 4h 5m 6s'` (can be positive or negative, units optional)

### Specify a Date with Offset
```
${{=sv:date-math('offset', 'format', 'date')}}
```
Example: `${{=sv:date-math('1y', 'yyyy-MM-dd', '2022-08-11')}}`

### Different Input/Output Formats
```
${{=sv:date-math('offset', 'outFormat', 'date', 'inFormat')}}
```
Example: `${{=sv:date-math('1y', 'MM/yyyy', '2022-08-11', 'yyyy-MM-dd')}}`

### With Default Value
```
${{=sv:date-math('1y', 'yyyy-MM-dd', /root/date/text())#2000-01-01}}
```

---

## Extract Request Values (XPath)

Extract JSON/XML values from the incoming request:

```
${{=/root/fieldName/text()}}
```

Example request:
```xml
<root>
  <accountNumber>12345</accountNumber>
  <transactionId>abc-xyz</transactionId>
</root>
```

Response:
```json
{
  "requestedAccount": "${{=/root/accountNumber/text()}}",
  "correlationId": "${{=/root/transactionId/text()}}"
}
```

---

## Extract Headers

```
${{=sv:header('headerName')}}
```

With index (if multiple headers with same name):
```
${{=sv:header('headerName', 2)}}
```

With default:
```
${{=sv:header('Authorization')#noAuth}}
```

---

## Extract URL Parameters

```
${{=sv:url-parameter('parameterName')}}
```

Example: Request to `GET /api?accountId=999&type=premium`
```json
{
  "account": "${{=sv:url-parameter('accountId')}}",
  "tier": "${{=sv:url-parameter('type')}}"
}
```

Result:
```json
{
  "account": "999",
  "tier": "premium"
}
```

---

## Extract URL Path Segments

```
${{=sv:url-path(index)}}
```

Example: URL `http://localhost:9080/api/v1/cards/accounts/123`
- `${{=sv:url-path(0)}}` → `api`
- `${{=sv:url-path(1)}}` → `v1`
- `${{=sv:url-path(2)}}` → `cards`
- `${{=sv:url-path(3)}}` → `accounts`
- `${{=sv:url-path(4)}}` → `123`

---

## Common Patterns

### Echo request with dynamic timestamp
```json
{
  "requestedId": "${{=/root/id/text()}}",
  "processedAt": "${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}"
}
```

### Correlation using request parameter
```json
{
  "correlationId": "${{=sv:url-parameter('traceId')#unknown}}",
  "timestamp": "${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}"
}
```

### Extract from header
```json
{
  "userId": "${{=sv:header('X-User-ID')#anonymous}}",
  "requestPath": "${{=sv:url-path(1)}}",
  "createdAt": "${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}"
}
```

---

## When to Use

- **Dynamic timestamps:** Use `sv:date-math` to generate fresh timestamps for each response
- **Request correlation:** Extract request IDs/trace IDs with XPath or URL parameters
- **User-based responses:** Extract user identifiers from headers or request paths
- **Audit/logging:** Include request details in responses for traceability

---

## Validating Requests Before Using Inline Expressions

Before adding an inline expression to a response, always check the corresponding request file to ensure the data exists:

### Example: Check Request for XPath Extraction

**Request file** (`accounts_generic_request.txt`):
```
GET /accounts/1234
```

**Response** (`accounts_generic_response.txt`):
```json
{
  "accountNumber": "${{=/root/accountNumber/text()}}"
}
```

❌ **PROBLEM:** The request has no XML/JSON body, so `/root/accountNumber/text()` will fail.

✅ **SOLUTION:** Extract from the URL path instead:
```json
{
  "accountNumber": "${{=sv:url-path(3)}}",
  "timestamp": "${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}"
}
```

### Example: Check Request for Header Extraction

**Request file**:
```
GET /api/transaction
Authorization: Bearer token123
X-User-ID: user456
```

**Response**:
```json
{
  "userId": "${{=sv:header('X-User-ID')}}",
  "requestedBy": "${{=sv:header('X-User-Name')#unknown}}"
}
```

✅ **WORKS:** `X-User-ID` exists in request, will extract `user456`

⚠️ **FALLBACK:** `X-User-Name` doesn't exist, will use default value `unknown`

---

## Troubleshooting

### Error: `Unknown pattern letter` from `sv:date-math`

Cause: The date format contains unsupported pattern letters or uses an alias not recognized by the runtime parser.

Fix:
- Use explicit supported patterns such as `yyyy-MM-dd HH:mm:ss`
- Do not use aliases like `ISO8601`

Example:
- ❌ `${{=sv:date-math('0h', 'ISO8601')}}`
- ✅ `${{=sv:date-math('0h', 'yyyy-MM-dd HH:mm:ss')}}`

---

## How to Apply to Assets

1. Edit the response file: `workspace/VirtualAssets/generated_by_mcp/{asset-name}/{asset-name}_files/{response-file}.txt`
2. **Review the corresponding request file** to identify available fields:
   - Check `{response-file}_request.txt` or sample requests for the asset
   - Identify field names, headers, URL parameters, and path segments available in incoming requests
   - Verify that values you want to extract actually exist in the request payload
3. Add inline expressions in the JSON/XML payload based on what's available in the request
4. Save and upload to staging: `mcp_soavirt-serve_manageVirtualServices` with `update` action
5. Commit changes with `commitFromStaging`