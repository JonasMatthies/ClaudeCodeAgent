# ClaudeCodeAgent

Marketplace-Repo für eigene Claude-Code-Plugins. Sprache: Deutsch.

- Plugin „dirigent“ liegt in `plugins/dirigent/` (Skill, Agenten, Hook, Befehle), Marketplace in `.claude-plugin/marketplace.json`.
- Nach jeder Änderung: `bash tests/test_dirigent.sh`, `claude plugin validate plugins/dirigent` und `claude plugin validate .`. Ergebnis zeigen.
- Bei Änderungen am Plugin `version` in `plugins/dirigent/.claude-plugin/plugin.json` und in `marketplace.json` erhöhen.
- Hintergrund und Quellen der Designentscheidungen: `docs/RECHERCHE.md`.
