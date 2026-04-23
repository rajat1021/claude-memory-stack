# React + TypeScript — Tips & Gotchas

## Power Apps Code Components (PCF)
- Build: `npx vite build` — NEVER `npm run build` (tsc fails on auto-generated service files like `MicrosoftDataverseService.ts`)
- Deploy: `pac code push`
- Data sources must be registered in both `power.config.json` AND `dataSourcesInfo.ts`

## Local Dev with Power Apps Test Harness
- Run two processes: `vite --port 3000` (React app) + `pac code run` (proxy on port 8080)
- `pac code run` reads `power.config.json` and outputs the full test harness URL
- URL pattern: `https://apps.powerapps.com/play/e/{ENV_ID}/app/local?_localAppUrl=http://localhost:3000/&_localConnectionUrl=http://localhost:8080/`
- This gives you a real Power Apps shell with live Dataverse data + Vite hot reload — no mocks needed
- `npm run dev` in the project runs both in parallel (`vite & pac code run & wait`), but running them separately gives better control
- `VITE_USE_MOCKS=true` is only needed when running Vite standalone without `pac code run`

## State Management
- Avoid re-fetching full lists in completion handlers (causes page wipe/flicker) — only update the specific state that changed
- For loading states, pair `setLoading(true)` with `finally { setLoading(false) }` — never leave loading stuck on error

## Power Apps Iframe Restrictions
- `window.history.replaceState()` crashes in Power Apps iframe — causes blank page. Don't use URL manipulation in production custom pages.
- `navigator.clipboard.writeText()` may fail in iframe — always provide a fallback (show text in tooltip)
- `window.parent.location` throws cross-origin error — wrap in try/catch, never assume access
- `new URL(window.location.href)` can also fail — use string concatenation as fallback

## TypeScript
- Add optional properties to shared types: `topic?: string` not `topic: string | undefined` (the former allows omission)
- Use discriminated unions for message types rather than a single type with many optional fields
