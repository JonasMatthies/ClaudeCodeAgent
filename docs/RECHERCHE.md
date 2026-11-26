# Recherche: Wie baut man Orchestrierung mit gemischten Modellen effizient auf?

Stand: 26.11.2026, Claude Code 2.1.332.

## Ergebnisse und was daraus im Plugin wurde

| Befund | Quelle | Umsetzung |
| --- | --- | --- |
| Subagenten haben eigene `model`- und `effort`-Felder (`low` … `max`). Pro Aufruf kann man `model` (nur Alias) und `effort` überschreiben. Reihenfolge: Aufruf → Frontmatter → `CLAUDE_CODE_SUBAGENT_MODEL` → Modell des Hauptgesprächs | [Sub-agents](https://code.claude.com/docs/en/sub-agents) | Frontmatter-Standards je Agent; der Skill verlangt explizites `model` und `effort` bei jedem Aufruf |
| Ohne Modellangabe **erben** Subagenten still das teure Modell des Hauptgesprächs. Ein Erfahrungsbericht: 1–2 Mio. Opus-Tokens pro Aufgabe | [DEV-Postmortem](https://dev.to/akashy/my-agent-orchestrator-burned-1-2m-opus-tokens-per-task-heres-the-postmortem-2k7g) | Feste Modelle in jeder Agent-Definition, `general-purpose`, `Explore` und `fork` sind verboten |
| Eingebauter `Explore` nutzt im Abo den Alias `opus`, `general-purpose` erbt das Hauptmodell | [Sub-agents](https://code.claude.com/docs/en/sub-agents) | Eigener `scout` auf Haiku |
| Subagenten bekommen ihren eigenen Prompt plus CLAUDE.md, aber **keinen** Chatverlauf. Forks erben alles | [Sub-agents](https://code.claude.com/docs/en/sub-agents) | Auftragsvorlage (ZIEL/KONTEXT/VORGABEN/ABNAHME/BERICHT) und strenge Berichtsformate |
| Effort-Stufen low/medium/high/xhigh/max werden von Opus, Sonnet und Haiku 5.5 unterstützt, Standard ist `medium` | [Model config](https://code.claude.com/docs/en/model-config) | Matrix im Skill: Haiku low für Suche und Mechanik, Sonnet medium/high für Umsetzung und Review, Opus high/xhigh nur für schwere Teilprobleme |
| Subagenten verbrauchen eigenes Kontingent, kleinere Modelle senken die Kosten. `/usage` zeigt ihren Anteil | [Costs](https://code.claude.com/docs/en/costs) | Haiku und Sonnet als Standard |
| Ein Limit für alle Modelle in Claude und Claude Code. Opus kostet pro Zug ein Mehrfaches von Sonnet, Sonnet mehr als Haiku. Fable hat bei manchen Plänen ein eigenes Wochenlimit | [Models, usage & limits](https://support.claude.com/en/articles/14552983-models-usage-and-limits-in-claude-code), [Usage limits](https://support.claude.com/en/articles/11647753-how-do-usage-and-length-limits-work), [Claude Code mit Pro/Max](https://support.claude.com/en/articles/11145838-using-claude-code-with-your-pro-or-max-plan) | Antwort zum Nutzungslimit im README |
| Multi-Agent braucht insgesamt viel mehr Tokens (Anthropic: Agent ≈ 4×, Multi-Agent ≈ 15× eines Chats). Jede Übergabe kostet, kalte Caches verteuern das zusätzlich | [Orchestrator vs. Routing](https://heybento.ai/blog/frontier-model-orchestrator), [DEV-Postmortem](https://dev.to/akashy/my-agent-orchestrator-burned-1-2m-opus-tokens-per-task-heres-the-postmortem-2k7g) | Abschnitt 0 im Skill: kleine oder eng verzahnte Aufgaben selbst erledigen |
| Billige Modelle mit vielen Wiederholungen können teurer sein als einmal das passende Modell | [Fable-5-Orchestrator-Playbook](https://www.developersdigest.tech/blog/fable-5-orchestrator-model-playbook), [Haiku 5.5 für Subagenten](https://beam.ai/agentic-insights/claude-haiku-5-5-subagents) | Eskalationsleiter: nach 2 Fehlschlägen eine Stufe höher |
| Bewährte Rollenverteilung: starkes Modell für Zerlegung, Konfliktlösung und Synthese; Sonnet für Code und Tests; Haiku für Suche, Klassifikation und Lesen | [Smart Orchestrator](https://www.mindstudio.ai/blog/smart-orchestrator-cheaper-sub-agent-models-claude-code), [Opus plans, Haiku executes](https://dev.to/max_quimby/opus-plans-haiku-executes-the-agent-cost-stack-13h0), [SPOQ (arXiv)](https://arxiv.org/pdf/2606.03115) | Die fünf Agentenrollen |
| Prüfung zuerst automatisch (Tests), Review-Agent nur bei Risiko | [Subagent-Architektur](https://clouatre.ca/posts/orchestrating-ai-agents-subagent-architecture/) und Superpowers `subagent-driven-development` | Abschnitt 5 im Skill |
| Plugin-Hooks: `UserPromptSubmit` kann Kontext ergänzen oder den Prompt blockieren (mit Rückmeldung, ohne Modellaufruf) | [Hooks](https://code.claude.com/docs/en/hooks), [Plugins reference](https://code.claude.com/docs/en/plugins-reference) | Schalter „dirigent an/aus“ ohne Tokenkosten |

## Verworfene Alternativen

- **`opusplan`:** Opus plant im Plan-Modus, Sonnet führt aus. Einfach, aber ohne Zerlegung,
  ohne Kontexttrennung und ohne Haiku.
- **Agent Teams:** etwa 7× Tokens im Plan-Modus und für Einzelpersonen-Projekte zu schwer.
- **Eigenes Programm mit dem Agent SDK:** mehr Kontrolle, aber deutlich mehr Aufwand und außerhalb der normalen Claude-Code-Sitzungen.
- **Alles in CLAUDE.md:** würde in jedem Projekt dauerhaft Kontext kosten. Ein Skill wird nur bei Bedarf geladen.

## Gemessener Testlauf

`claude -p --model sonnet`: Delegation einer Dateisuche an `dirigent:scout`:
Haiku-Anteil ca. 0,00035 $ gegenüber 0,079 $ im Hauptmodell. Die eigentliche Arbeit lief also auf
Haiku, die Kosten entstanden fast nur durch die Übergabe im Hauptmodell. Das bestätigt Regel 0
im Skill: Winzige Aufgaben lohnen die Delegation nicht.
