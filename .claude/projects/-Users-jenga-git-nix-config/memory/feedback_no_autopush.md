---
name: No auto-push after commits
description: Never push to remote without explicit user approval — commit only, then ask
type: feedback
---

Always commit locally and stop. Ask the user before running `git push`.

**Why:** The user wants to review commits before they go to the remote. On at least one occasion, an error was already pushed before they could catch it — they would have spotted it if given the chance to review first.

**How to apply:** After `git commit`, do not chain `&& git push`. Instead, report what was committed and ask "shall I push?" or wait for the user to say "ok push" / "commit and push".
