# Power Automate — Tips & Gotchas

## Expression Pitfalls
- `coalesce("", fallback)` returns `""` NOT `fallback` — use `if(empty(...), fallback, value)` instead
- `sort()` does NOT support sorting by object key — pass pre-sorted arrays or use Select+Sort workaround
- `join()` on array of objects fails silently — only works on string arrays
- `@parameters('$authentication')` in action inputs causes `ContainsUnsupportedParameterFunctionExpressions` — solution flows use connection reference `runtimeSource: embedded`, remove the explicit parameter

## Unsupported Functions
- `createObject()` does NOT exist in Power Automate expressions — use a Compose action with literal JSON `{"key": "value"}` instead, then reference via `outputs('Compose_Name')`
- To build an array of objects: use separate Compose actions for each object, then `union(createArray(outputs('Obj1')), createArray(outputs('Obj2')))`

## runAfter Conditions
- Error handlers must include `Skipped` in runAfter, not just `[Failed, TimedOut]` — upstream actions that are Skipped won't trigger handlers otherwise

## SharePoint OData Filters
- Lookup columns need `/Value` path: `PertainTo/Value eq 'Creation'` not `PertainTo eq 'Creation'`
- But safer to skip Lookup columns in OData and discriminate post-fetch via Switch
- Choice columns return plain string, Lookup columns return object — use `coalesce(items()?['Col/Value'], items()?['Col'])` to handle both

## Base64 Content Extraction
- SPO files return base64 body — `base64ToString(body('Get_File_Content')['$content'])`
- For XML wrapped in markdown code fences: `first(split(last(split(base64ToString(...), '```xml')), '```'))`

## Solution Deployment
- Always remove `@parameters('$authentication')` from all action inputs before import
- `pac solution pack` must complete before `pac solution import`
- "Publish All Customizations" takes ~3 min after import
- Bump `Version` in `Solution.xml` before every pack

## Connection References
- Solution flows use `runtimeSource: embedded` — connections are resolved at runtime via connection references, not explicit auth parameters

## Creating Flows Programmatically
- `pac solution pack` validates RootComponent GUIDs against the environment — you CANNOT add a new flow to a solution via pack if it doesn't already exist in Dataverse
- To create a new flow programmatically: POST to Dataverse Web API `/api/data/v9.2/workflows` with `clientdata` containing the flow JSON, then `pac solution add-solution-component --componentType 29` to add it to the solution
- Child flows require the parent flow to be in a solution — the Flow Management API (`api.flow.microsoft.com`) rejects flows with child flow calls if created outside a solution (`ChildFlowsUnsupportedForNonSolutionFlows`)
- To get an HTTP trigger URL programmatically: POST to `api.flow.microsoft.com/.../triggers/manual/listCallbackUrl` — the URL is NOT stored in the Dataverse workflow record
- To set an environment variable value via API: POST to `/api/data/v9.2/environmentvariablevalues` with `EnvironmentVariableDefinitionId@odata.bind`

## Bing Search API — RETIRED
- Bing Search API v7 (`api.bing.microsoft.com/v7.0/search`) is **retired** as of 2026 — returns "endpoint no longer available"
- The `shared_bingsearch` connector in Power Automate also no longer works
- Alternatives: ScrapingBee (Google search proxy), OpenAI web search, or Google Custom Search API
- See: https://aka.ms/BingAPIsRetirement

## PAC CLI — Local Dev
- `pac code run` starts a local proxy (default port 8080) that serves `power.config.json` and proxies Dataverse API calls with your authenticated session
- It auto-generates the test harness URL: `https://apps.powerapps.com/play/e/{ENV_ID}/app/local?_localAppUrl=http://localhost:{VITE_PORT}/&_localConnectionUrl=http://localhost:8080/`
- The proxy handles auth transparently — your React app makes normal SDK calls via `getClient(dataSourcesInfo)` and they hit live Dataverse through the proxy
- Must be authenticated first (`pac auth create` or existing profile) — uses the connected user shown in `Connected as ...` output

## OpenAI API — web_search_preview
- `web_search_preview` tool is ONLY available on the **Responses API** (`/v1/responses`), NOT on Chat Completions (`/v1/chat/completions`)
- Chat Completions returns: `Invalid value: 'web_search_preview'. Supported values are: 'function' and 'custom'.`
- Responses API uses `instructions` + `input` instead of `messages` array
- Response body uses `output_text` instead of `choices[0].message.content`
- Valid `search_context_size` values: `"low"`, `"medium"`, `"high"` — `"medium"` is recommended

## PowerApp Response Schema
- `kind: "PowerApp"` responses require ALL response actions (success + error) to have **identical schemas** — same fields, same types
- If you add a field to `Return_Success`, you MUST add the same field to `Return_Error` — otherwise flow activation fails: `ActionSchemaInvalid: schema definitions for actions with same status code must match`
- PowerApp responses serialize everything as strings — arrays become JSON strings, use `json()` to parse on the receiving end

## Solution Import — Flow Deactivation
- Adding or changing a **connection reference** in a flow definition causes the flow to be **deactivated** after solution import
- Always check flow status after import: `statecode=1` means Active, `statecode=0` means Inactive
- Reactivate via: `PATCH workflows({id}) {"statecode":1,"statuscode":2}`
- SPO connection references (`shared_sharepointonline`) are especially sensitive — if the `connectionReferenceLogicalName` doesn't exist in the target environment, the flow deactivates silently

## Project for the Web (Premium Planner) — Task CRUD
- Cannot directly CRUD `msdyn_projecttask` via Dataverse API — returns `You cannot directly do 'Create' operation to 'msdyn_projecttask'`
- Must use the **OperationSet pattern**: (1) `msdyn_CreateOperationSetV1` → get OperationSetId, (2) `msdyn_PssCreateV1` / `msdyn_PssUpdateV1` to queue changes, (3) `msdyn_ExecuteOperationSetV1` to commit
- `msdyn_progress` is a decimal 0.0–1.0, NOT a percentage (0–100) — values >1.0 fail with `percent outside of bounds`
- `msdyn_scheduledstart` / `msdyn_scheduledend` are **read-only** (computed by scheduling engine) — use `msdyn_start` / `msdyn_finish` instead
- All changes in a single OperationSet are atomic — if one fails, all fail
- OperationSet expires after execution — cannot reuse, must create a new one for each batch

## Azure CLI for Power Platform APIs
- `az account get-access-token --resource https://service.flow.microsoft.com` — token for Flow Management API
- `az account get-access-token --resource https://org{id}.crm.dynamics.com` — token for Dataverse Web API
- `az account get-access-token --resource https://graph.microsoft.com` — token for SharePoint via Graph API
