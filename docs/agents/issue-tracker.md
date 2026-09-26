# Issue tracker: Notion

Issues and specs for this repo live in Notion, reached by agents through
Notion's official hosted MCP (`https://mcp.notion.com/mcp`, Streamable
HTTP). No local services, no tokens in config: auth is OAuth, completed
interactively in opencode on first use, and respects your existing
workspace permissions.

## One-time setup

1. In Notion, create one database per effort (e.g. `Wayfinder – <effort>`)
   with these properties:
   - `Title` (title), `Type` (select: `map`, `research`, `prototype`,
     `grilling`, `task`), `Status` (select: `Not started`, `In progress`,
     `Done`), `Assignee` (person), `Parent` (relation → same database),
     `Blocked by` (relation → same database).
2. In opencode, let the `notion` MCP entry trigger the OAuth flow once.

## Conventions

- The `Type` select carries the `wayfinder:<type>` vocabulary; the map row
  itself is `Type = map`.
- Discussion accrues in page comments, appended over time — never rewritten.
- Rows are identified by title in everything humans read, with the Notion
  link behind the name, never a bare ID.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a row with one **child row** per
ticket, all inside one database per effort.

- **Map**: a row with `Type = map` carrying the Notes / Decisions-so-far /
  Fog body in the page content.
- **Child ticket**: a row linked to the map via the `Parent` relation, with
  `Type = research|prototype|grilling|task` and the question in the page
  content.
- **Blocking**: the `Blocked by` relation. Notion does not enforce it, so
  the agent must check: a ticket is unblocked only when every row it lists
  has `Status = Done`.
- **Frontier**: open, unblocked, unclaimed children — query the database for
  `Status != Done` and `Assignee` empty, then drop any whose `Blocked by`
  targets aren't all `Done`; first by creation order wins. Mirror it as a
  saved database view for the visual check.
- **Claim**: set `Assignee` to yourself **first**, before any work, so
  concurrent sessions skip it. An open, unassigned ticket is unclaimed.
- **Resolve**: post the answer as a comment, set `Status = Done`, then
  append a one-line pointer (gist + link) to the map's Decisions-so-far.
