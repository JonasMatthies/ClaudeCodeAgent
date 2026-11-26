# ClaudeCodeAgent – Plugin „Dirigent“

Ein Claude-Code-Plugin für Code-, App- und Systemprojekte. Das Hauptmodell (z. B. Opus) wird zum
**Dirigenten**: Es zerlegt große Aufgaben in Teilschritte, wählt für jeden Schritt das
**günstigste ausreichende Modell und die passende Effort-Stufe** (low/medium/high/xhigh), gibt den
Agenten **nur den nötigen Kontext** mit und prüft das Ergebnis, zuerst automatisch über Tests und
dann gezielt.

Wie es zu diesem Aufbau kam und welche Quellen dahinterstehen, steht in [`docs/RECHERCHE.md`](docs/RECHERCHE.md).

## Bausteine

| Teil | Standard | Wofür |
| --- | --- | --- |
| Skill `dirigent:orchestrieren` | – | Regeln für den Dirigenten: wann sich Delegation lohnt, Zerlegung, Modell-/Effort-Matrix, Auftragsvorlage, Prüfung, Eskalation |
| Agent `dirigent:scout` | Haiku · low | Suchen, lesen, Doku recherchieren, nur Fakten zurückmelden |
| Agent `dirigent:handlanger` | Haiku · low | Mechanische Änderungen nach genauer Vorgabe |
| Agent `dirigent:umsetzer` | Sonnet · medium | Normale Feature-Umsetzung inkl. Tests |
| Agent `dirigent:pruefer` | Sonnet · medium | Review gegen Abnahmekriterien, ändert nichts |
| Agent `dirigent:experte` | Opus · high | Abgegrenzte, schwere Teilprobleme |
| Hook `UserPromptSubmit` | – | Schalter „dirigent an/aus“ und ein kurzer Hinweis (~90 Tokens) pro Nachricht, solange an |

Die Standardwerte sind nur Vorgaben. Der Dirigent setzt `model` und `effort` bei jedem Aufruf
selbst passend zur Aufgabe, zum Beispiel `umsetzer` mit Sonnet · high für knifflige Logik oder
`experte` mit xhigh, wenn high gescheitert ist. Die Agenten können keine weiteren Agenten starten.
Das verhindert, dass die Kosten durch verschachtelte Aufrufe explodieren.

## Benutzen

**Automatisch:** Ist der Dirigent an (Standard), entscheidet das Hauptmodell bei jeder Nachricht
selbst: kleine Aufgaben erledigt es direkt, große zerlegt und delegiert es.

**Schalten:** Einfach eine dieser Nachrichten schicken. Sie gehen nicht ans Modell und kosten
deshalb keine Tokens:

| Nachricht | Wirkung |
| --- | --- |
| `dirigent an` | einschalten |
| `dirigent aus` | ausschalten |
| `dirigent` oder `dirigent status` | Status zeigen |

Alternativ gehen die Slash-Befehle `/dirigent:an`, `/dirigent:aus` und `/dirigent:status`. Die
tauchen in der Befehlsauswahl auf, kosten aber einen kurzen Modellaufruf.

**Einmalig erzwingen** (auch wenn der Dirigent aus ist):
`/dirigent:orchestrieren Baue die Etappe 3 aus PLAN.md`

**Fest per Umgebungsvariable:** `DIRIGENT_MODUS=an` oder `aus` überschreibt den Schalter.

Der Schalter gilt pro Rechner bzw. Container. In Cloud-Sessions ist der Container nach der Session
weg, deshalb ist der Dirigent dort in jeder neuen Session wieder **an**.

**Empfohlenes Hauptmodell:** Opus (`/model opus`) mit `medium` oder `high`. Damit sind
Dirigent und `experte` gleich stark, die Kleinarbeit läuft auf Sonnet und Haiku.

## Installieren

### Claude Code im Terminal oder in der Desktop-App (dauerhaft für alle Projekte)

```
/plugin marketplace add JonasMatthies/ClaudeCodeAgent
/plugin install dirigent@claudecodeagent
```

Danach Claude Code neu starten oder `/reload-plugins` ausführen. Aktualisieren:
`/plugin marketplace update claudecodeagent`.

### Cloud-Sessions (claude.ai/code, App)

Dort geht `~/.claude` nach jeder Session verloren. Deshalb das Plugin **im jeweiligen Projekt**
eintragen, in `.claude/settings.json` (zum Beispiel in `bohnenbuch`):

```json
{
  "extraKnownMarketplaces": {
    "claudecodeagent": {
      "source": { "source": "github", "repo": "JonasMatthies/ClaudeCodeAgent" }
    }
  },
  "enabledPlugins": {
    "dirigent@claudecodeagent": true
  }
}
```

Ist das Repo privat, muss `JonasMatthies/ClaudeCodeAgent` in der Cloud-Session als Repository
verfügbar sein, damit es geladen werden kann.

### Gewöhnlicher claude.ai-Chat

Dort gibt es keine Subagenten mit Modellwahl, deshalb funktioniert das Plugin nur in Claude Code
(Terminal, Desktop, Web/Cloud, IDE).

## Bringt das etwas für mein Nutzungslimit?

**Ja, bei großen Aufgaben. Bei kleinen nicht.**

- Laut Anthropic-Hilfe zählen Claude und Claude Code gegen **dasselbe** 5-Stunden- und
  Wochenlimit, über alle Modelle hinweg. Opus kostet pro Zug „ein Mehrfaches“ von Sonnet, Sonnet
  mehr als Haiku. Subagenten verbrauchen ebenfalls Kontingent, aber zum Satz *ihres* Modells.
  Was Sonnet oder Haiku statt Opus erledigt, schont das Limit also spürbar.
- Gleichzeitig verursacht Delegation Mehraufwand: Auftrag schreiben, Einarbeitung des Agenten,
  Bericht. Multi-Agent-Systeme brauchen insgesamt *mehr* Tokens als ein einzelner Agent. Der
  Gewinn entsteht nur, wenn der Großteil der Arbeit auf billigeren Modellen läuft und der teure
  Kontext klein bleibt. Darum erledigt der Dirigent kleine Aufgaben bewusst selbst.
- Nachprüfen: `/usage` zeigt den Anteil der Subagenten am Verbrauch. Ein Testlauf hier ergab für
  eine Suchaufgabe Haiku-Kosten von etwa 0,4 % der Sonnet-Kosten des Hauptmodells.

## Stolperfallen

- Ist `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` gesetzt, wird die Modellwahl ignoriert. Ist
  `CLAUDE_CODE_EFFORT_LEVEL` gesetzt, wird die Effort-Wahl ignoriert. Beide nicht setzen.
- Die eingebauten Agenten `Explore` und `general-purpose` laufen auf teuren Modellen. Der Skill
  verbietet sie fürs Delegieren.

## Entwicklung

- Tests: `bash tests/test_dirigent.sh`
- Prüfen: `claude plugin validate plugins/dirigent` und `claude plugin validate .`
- Lokal testen: `claude plugin marketplace add "$PWD"` und `claude plugin install dirigent@claudecodeagent`
