# Build Network event model (prototype)

This prototype intentionally keeps the collaboration payloads small and JSON-based so they can ride on the existing signed Friends relay transport.

Suggested logical types:

- `idea`: title, summary, tags, author, created_at, status
- `build_room`: title, goal, repo_url, roles_needed, tasks, members, source_idea_id
- `setup_card`: title, theme, plugins, shell, terminal, editor, wallpaper_url, notes
- `test_request`: title, artifact_url, version, environment_tags, requested_tags, notes
- `test_result`: request_id, result (`pass`/`issue`), environment_tags, note

All payloads must be bounded before relay publication. Do not include secrets or arbitrary command output. Setup cards are metadata only in v1.