# Issue tracker: Vikunja (self-hosted)

Issues and specs for this repo live in the local Vikunja instance — no git
hosting involved, just the task UI plus a REST API agents can drive.

- **UI**: `http://127.0.0.1:3456` (single binary serves frontend + API,
  sqlite backend, localhost-only)
- **First run**: register the first account — it automatically becomes admin.
  Create one project per repo you plan (e.g. project `dotfiles` for `~/nix`),
  then set `service.enableregistration = false` in
  `modules/services/vikunja.nix` to close registration.
- **Agent access (MCP, preferred)**: opencode talks to the tracker through
  the `vikunja` MCP server declared in `opencode.json` (stdio bridge,
  works against the current 2.6 API). It needs one env var in opencode's
  environment — create the value once in the Vikunja UI under Avatar →
  Settings → API tokens, then export it before starting opencode:
  `export VIKUNJA_API_TOKEN='<token>'`. The token carries your full API
  permissions (the bridge runs in safe mode: deletes stay off unless
  `ENABLE_TASK_DELETE`/`ENABLE_LABEL_DELETE` are set).
- **Agent access (raw REST)**: `Authorization: Bearer <same token>` against
  `http://127.0.0.1:3456/api/v1`. Exact request schemas:
  <https://vikunja.io/docs/api>. Key endpoints: `/projects`,
  `/projects/{id}/tasks`, `/tasks/{id}`, `/tasks/{id}/comments`,
  `/tasks/{id}/labels`, `/tasks/{id}/relations`, `/tasks/{id}/assignees`.
- **Future (native MCP)**: once nixpkgs ships Vikunja ≥ 2.7, drop the bridge
  for the built-in endpoint — `remote` type, URL
  `http://127.0.0.1:3456/api/v2/mcp`, bearer token minted under
  Avatar → Settings → MCP with a permission preset (read-only or typed
  read+write instead of a full API token).

## Conventions

- Labels categorize work and drive filters: `wayfinder:map`,
  `wayfinder:research`, `wayfinder:prototype`, `wayfinder:grilling`,
  `wayfinder:task`. Create them on the fly from the task's labels field.
- Discussion goes in task comments, appended over time — never rewritten.
- Task IDs are global numbers (shown as `#<id>`); in everything humans read,
  refer to tasks by title with the link behind it, never by bare ID.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a parent task with one **subtask** per
ticket, all inside one Vikunja project per effort.

- **Map**: a task labeled `wayfinder:map` carrying the Notes /
  Decisions-so-far / Fog body in its description.
- **Child ticket**: a task linked to the map via the native `subtask`
  relation (sidebar → Relations → Add a relation → `subtask`), labeled
  `wayfinder:<type>`, with the question in its description.
- **Blocking**: the native `blocked by` relation (same Relations sidebar).
  It is enforced: a task cannot be marked done while its blockers are open.
- **Frontier**: open, unblocked, unclaimed children. In the UI use the filter
  `done = false && open_relations != blocked` scoped to the map's subtasks;
  first by task ID wins.
- **Claim**: assign the ticket to yourself **first**, before any work, so
  concurrent sessions skip it. An open, unassigned ticket is unclaimed.
- **Resolve**: post the answer as a comment, mark the task done, then append
  a one-line pointer (gist + link) to the map's Decisions-so-far.
