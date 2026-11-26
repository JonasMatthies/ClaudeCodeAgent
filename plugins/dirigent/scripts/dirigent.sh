#!/usr/bin/env bash
# Dirigent – Schalter und UserPromptSubmit-Hook.
#
#   dirigent.sh hook     liest das Hook-JSON von stdin (UserPromptSubmit)
#   dirigent.sh an|aus   schaltet den Modus
#   dirigent.sh status   zeigt den Modus
#
# Zustand: $DIRIGENT_DATA/modus (Inhalt "an" oder "aus"), Standard "an".
# Umgebungsvariable DIRIGENT_MODUS=an|aus überschreibt den gespeicherten Zustand.

set -u

DATA_DIR="${DIRIGENT_DATA:-${CLAUDE_PLUGIN_DATA:-$HOME/.claude/dirigent}}"
STATE_FILE="$DATA_DIR/modus"

modus_lesen() {
  if [ -n "${DIRIGENT_MODUS:-}" ]; then
    case "$DIRIGENT_MODUS" in
      aus|off|0|false) echo aus ;;
      *) echo an ;;
    esac
    return
  fi
  if [ -f "$STATE_FILE" ] && [ "$(tr -d '[:space:]' < "$STATE_FILE")" = "aus" ]; then
    echo aus
  else
    echo an
  fi
}

modus_setzen() {
  mkdir -p "$DATA_DIR" && printf '%s\n' "$1" > "$STATE_FILE"
}

status_text() {
  local m; m="$(modus_lesen)"
  local t="Dirigent ist $(printf '%s' "$m" | tr '[:lower:]' '[:upper:]')."
  if [ -n "${DIRIGENT_MODUS:-}" ]; then
    t="$t (festgelegt durch Umgebungsvariable DIRIGENT_MODUS)"
  fi
  printf '%s' "$t"
}

# JSON-String sicher ausgeben (für reason/additionalContext)
json_str() {
  local s="$1"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"; s="${s//$'\n'/\\n}"; s="${s//$'\t'/\\t}"
  printf '"%s"' "$s"
}

prompt_aus_json() {
  local input="$1"
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$input" | jq -r '.prompt // ""' 2>/dev/null
  elif command -v python3 >/dev/null 2>&1; then
    printf '%s' "$input" | python3 -c 'import json,sys
try: print(json.load(sys.stdin).get("prompt",""))
except Exception: print("")' 2>/dev/null
  else
    # Notlösung: nur für kurze Schaltbefehle gedacht
    printf '%s' "$input" | sed -n 's/.*"prompt"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p'
  fi
}

KONTEXT='[Dirigent aktiv] Bei größeren Code-, App- oder Rechercheaufgaben (mehrere Teilschritte, viel Lese-/Suchaufwand, mehrere Module) zuerst den Skill dirigent:orchestrieren laden und befolgen: zerlegen, pro Teilschritt Modell und Effort wählen, mit minimalem Kontext an die dirigent-Agenten delegieren, Ergebnis prüfen. Kleine, schnelle oder eng verzahnte Aufgaben direkt selbst erledigen. Der Nutzer schaltet mit der Nachricht "dirigent aus" ab.'

hook() {
  local input prompt norm cmd
  input="$(cat)"
  prompt="$(prompt_aus_json "$input")"
  # normalisieren: klein, Ränder trimmen, Mehrfach-Leerzeichen zusammenfassen
  norm="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//')"

  cmd=""
  case "$norm" in
    "dirigent an"|"dirigent ein"|"dirigent on") cmd=an ;;
    "dirigent aus"|"dirigent off") cmd=aus ;;
    "dirigent"|"dirigent status"|"dirigent?") cmd=status ;;
  esac

  if [ -n "$cmd" ]; then
    local msg
    if [ "$cmd" = status ]; then
      msg="$(status_text) Schalten mit \"dirigent an\" / \"dirigent aus\"."
    else
      modus_setzen "$cmd"
      msg="$(status_text)"
      [ "$cmd" = an ] && msg="$msg Größere Aufgaben werden jetzt zerlegt und an passende Modelle verteilt."
      [ "$cmd" = aus ] && msg="$msg Ich arbeite wieder normal ohne Delegation (expliziter Aufruf mit /dirigent:orchestrieren bleibt möglich)."
    fi
    # Prompt blockieren: kein Modellaufruf, keine Tokens – nur Rückmeldung an den Nutzer.
    printf '{"decision":"block","reason":%s}\n' "$(json_str "$msg")"
    exit 0
  fi

  if [ "$(modus_lesen)" = an ]; then
    printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","additionalContext":%s}}\n' "$(json_str "$KONTEXT")"
  fi
  exit 0
}

case "${1:-status}" in
  hook) hook ;;
  an|ein|on) modus_setzen an; status_text; echo ;;
  aus|off) modus_setzen aus; status_text; echo ;;
  status) status_text; echo ;;
  *) echo "Verwendung: dirigent.sh hook|an|aus|status" >&2; exit 2 ;;
esac
