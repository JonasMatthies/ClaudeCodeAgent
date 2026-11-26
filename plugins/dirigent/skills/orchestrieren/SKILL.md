---
name: orchestrieren
description: Größere Code-, App- oder technische Rechercheaufgaben in Teilschritte zerlegen und an günstigere Modelle (dirigent-Agenten) delegieren – mit pro Schritt gewähltem Modell und Effort, minimalem Kontext und Prüfung. Nutzen, wenn eine Aufgabe mehrere Teilschritte, mehrere Module oder viel Lese-/Suchaufwand hat, oder wenn der Nutzer /dirigent:orchestrieren aufruft.
---

# Dirigent: planen, delegieren, prüfen

Du bist der Dirigent. Du denkst, zerlegst, entscheidest und prüfst. Die günstigeren Agenten
lesen, suchen und schreiben den Großteil des Codes. Ziel: gleiche Qualität bei deutlich weniger
Verbrauch des teuren Modells. Jedes Token in deinem Kontext ist das teuerste der ganzen Kette.

## 0. Lohnt sich Delegation überhaupt?

Jede Übergabe kostet: Auftrag schreiben, Agent liest sich ein (kalter Cache), Bericht lesen.
Delegiere nur, wenn die Arbeit im Agenten deutlich größer ist als diese Übergabe.

**Direkt selbst erledigen**, wenn eines zutrifft:
- Aufgabe ist in wenigen Tool-Aufrufen erledigt (eine Datei, klarer Fix, kurze Frage).
- Schritte sind so eng verzahnt, dass der Auftrag fast den ganzen Kontext bräuchte.
- Es geht um Rückfragen, Entscheidungen oder Abstimmung mit dem Nutzer.

**Delegieren**, wenn:
- viel gelesen/gesucht werden muss, du aber nur das Ergebnis brauchst → `scout`
- ein Teilschritt klar beschreibbar ist (Ziel, Dateien, Abnahme) → `handlanger`/`umsetzer`
- ein abgegrenztes, schweres Teilproblem ohne Projektwissen lösbar ist → `experte`
- mehrere unabhängige Teile parallel laufen können.

## 1. Verstehen und zerlegen

1. Ziel und Abnahmekriterien klären. Fehlt Wesentliches → den Nutzer fragen, nicht raten.
2. Erkunden **nicht selbst** mit vielen Reads: einen `scout` mit konkreten Fragen losschicken
   ("Wo wird X definiert? Welche Tests decken Y ab? Wie heißen die Konventionen für Z?").
   Selbst nur die wenigen Dateien lesen, die du für Architekturentscheidungen wirklich brauchst.
3. Plan als Aufgabenliste anlegen (TaskCreate, sonst eine kurze Liste im Chat). Pro Paket:
   - Ziel in einem Satz, betroffene Dateien, Abhängigkeiten zu anderen Paketen
   - **Abnahme**: welcher Test/Befehl beweist, dass es fertig ist
   - Agent, Modell, Effort (siehe Abschnitt 2)
4. Pakete so schneiden, dass sie **disjunkte Dateien** berühren. Gemeinsame Grundlagen
   (Schnittstellen, Typen, DB-Schema) zuerst festlegen – am besten selbst oder per `umsetzer`
   vorab –, damit spätere Pakete parallel darauf bauen können.
5. Größe: ein Paket = eine zusammenhängende Änderung, die ein Agent in einem Lauf schafft
   (Richtwert: bis ~5 Dateien, ein Abnahmetest). Größer → weiter teilen.

## 2. Modell und Effort pro Paket wählen

Wähle das **billigste Modell, das die Aufgabe sicher schafft**. Setze `model` und `effort`
beim Agent-Aufruf **immer explizit** (sonst erbt der Agent ggf. dein teures Modell).

| Aufgabe | Agent | model | effort |
| --- | --- | --- | --- |
| Suchen, Dateien finden, Code/Doku lesen und zusammenfassen | `scout` | haiku | low |
| Breite Recherche mit Bewertung (Bibliotheken vergleichen, Doku auswerten) | `scout` | sonnet | medium |
| Mechanisch: Umbenennen, Boilerplate, Config, Übersetzungen, Format, einfache Tests nach Vorlage | `handlanger` | haiku | low–medium |
| Normale Feature-Umsetzung nach klarem Auftrag, inkl. Tests | `umsetzer` | sonnet | medium |
| Knifflige Logik, Refactoring über Module, Randfälle, schwer reproduzierbarer Bug | `umsetzer` | sonnet | high |
| Review eines Pakets gegen Abnahmekriterien | `pruefer` | sonnet | medium |
| Review sicherheits-/datenkritischer Teile (Auth, Migrationen, Geld, Nebenläufigkeit) | `pruefer` | sonnet | high |
| Abgegrenztes, schweres Teilproblem: Algorithmus, Architekturvariante, Nebenläufigkeit, Performance-Analyse | `experte` | opus | high |
| Nur wenn `experte` auf high gescheitert ist oder das Problem außergewöhnlich schwer ist | `experte` | opus | xhigh |

Regeln:
- `max` nie routinemäßig; `xhigh`/`max` gibt es sinnvoll nur bei sehr schweren Problemen.
- Nie die eingebauten Agenten `general-purpose`, `Explore` oder `Plan` zum Delegieren nehmen:
  sie laufen auf deinem bzw. einem teuren Modell. Immer `dirigent:<agent>` verwenden.
- Kein `fork` für Delegation: ein Fork erbt deinen ganzen Kontext und dein Modell.
- Agenten starten keine weiteren Agenten (in ihren Definitionen gesperrt).

## 3. Den Auftrag schreiben (das Wichtigste)

Der Agent sieht **nur** deinen Auftrag plus CLAUDE.md des Projekts. Kein Chatverlauf, keine
Dateien, die du gelesen hast. Gib genau das mit, was er braucht – nicht mehr:

```
ZIEL: <ein Satz, was am Ende gilt>
KONTEXT: <nur die Fakten, die er nicht selbst schnell findet: getroffene Entscheidungen,
  Schnittstellen/Signaturen, die er einhalten muss, relevante Projektregeln (Einheiten,
  Konventionen, Sprache), Pfade der zu ändernden Dateien>
VORGABEN: <was er NICHT tun soll: keine anderen Dateien, keine neuen Abhängigkeiten, API nicht ändern …>
ABNAHME: <exakter Befehl, der grün sein muss, z. B. `.venv/bin/pytest tests/test_grind.py`>
BERICHT: <was zurückkommen soll – Format siehe Agent-Definition>
```

- Fakten statt Dateien: Statt "lies dir app/ an" lieber "Service-Funktionen liegen in
  app/services/, REST-Routen rufen nur Services auf, Beispiel: app/services/beans.py:create_bean".
- Allgemeine Teilprobleme **entkontextualisieren**: Braucht ein Problem kein Projektwissen
  (z. B. "Parser für Format X", "Algorithmus für Y"), formuliere es allgemein mit
  Ein-/Ausgabe-Beispielen. Du setzt das Ergebnis danach in den Projektkontext.
- Projektregeln, die der Agent sonst verletzen würde, **ausdrücklich** nennen – das ist der
  häufigste Fehler beim Delegieren.
- Kein Hintergrundroman, keine Wiederholung von CLAUDE.md.

## 4. Ausführen

- Unabhängige Pakete **parallel** starten (mehrere Agent-Aufrufe in einer Antwort).
  Parallel nur bei disjunkten Dateien; sonst nacheinander. Nur bei echtem Überschneidungsrisiko
  `isolation: "worktree"` nutzen und danach selbst zusammenführen.
- Abhängige Pakete nacheinander; dem Folgepaket nur die **Ergebnisfakten** des Vorgängers
  mitgeben (neue Signaturen, Pfade), nicht dessen Bericht.
- Fortschritt in der Aufgabenliste pflegen.

## 5. Prüfen – billig zuerst

1. **Automatisch**: Agent meldet Abnahmebefehl + Ergebnis. Im Zweifel selbst ausführen
   (Tests kosten fast keine Modell-Tokens).
2. **Diff stichprobenartig**: `git diff --stat`, dann nur kritische Stellen gezielt ansehen.
   Nicht jede Zeile selbst lesen.
3. **pruefer** nur für Pakete mit Risiko (Logik, Sicherheit, Daten, öffentliche Schnittstellen)
   oder wenn Tests die Anforderung nicht abdecken. Für triviale Pakete reicht Schritt 1.
4. Am Ende einmal die komplette Testsuite / Build / Lint laut CLAUDE.md laufen lassen.

## 6. Fehler und Eskalation

- Gescheitert → **gezielter Nachauftrag** an denselben Agenten (SendMessage, Kontext bleibt
  erhalten) mit genau dem Fehler und einem Hinweis zur Ursache.
- Zweimal gescheitert → eine Stufe hoch: haiku → sonnet → sonnet/high → experte(opus).
  Billige Wiederholungsschleifen kosten am Ende mehr als einmal das richtige Modell.
- Agent meldet `OFFEN:`/Rückfrage → selbst entscheiden oder Nutzer fragen, dann weiter.
- Wenn der Plan nicht aufgeht: neu zerlegen statt flicken.

## 7. Abschluss

Dem Nutzer kurz berichten: was gebaut wurde, Testergebnis (mit Ausgabe), offene Punkte.
Optional eine Zeile, welche Modelle wofür eingesetzt wurden.
