#!/usr/bin/env bash
# Tests für plugins/dirigent/scripts/dirigent.sh – ausführen: bash tests/test_dirigent.sh
set -u
cd "$(dirname "$0")/.."
SCRIPT="plugins/dirigent/scripts/dirigent.sh"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export DIRIGENT_DATA="$TMP/data"
unset DIRIGENT_MODUS CLAUDE_PLUGIN_DATA

fails=0; n=0
check() { # name, erwartet (Teilstring), tatsächlich
  n=$((n+1))
  if [[ "$3" == *"$2"* ]]; then echo "ok   $1"; else echo "FAIL $1"; echo "     erwartet: $2"; echo "     erhalten: $3"; fails=$((fails+1)); fi
}
check_not() {
  n=$((n+1))
  if [[ "$3" != *"$2"* ]]; then echo "ok   $1"; else echo "FAIL $1 (enthält unerwartet: $2)"; fails=$((fails+1)); fi
}
hook() { printf '%s' "$1" | bash "$SCRIPT" hook; }

check "Standard ist AN" "Dirigent ist AN" "$(bash "$SCRIPT" status)"
check "Normaler Prompt bekommt Kontext, wenn AN" '"additionalContext"' "$(hook '{"prompt":"Baue mir eine App"}')"
out="$(hook '{"prompt":"Baue mir eine App"}')"
echo "$out" | jq -e . >/dev/null 2>&1; check "Kontext-Ausgabe ist gültiges JSON" "0" "$?"

out="$(hook '{"prompt":"  Dirigent   AUS "}')"
check "dirigent aus blockiert den Prompt" '"decision":"block"' "$out"
check "dirigent aus meldet AUS" "Dirigent ist AUS" "$out"
echo "$out" | jq -e . >/dev/null 2>&1; check "Block-Ausgabe ist gültiges JSON" "0" "$?"
check "Zustand ist danach AUS" "Dirigent ist AUS" "$(bash "$SCRIPT" status)"
check "Kein Kontext, wenn AUS" "" "$(hook '{"prompt":"Baue mir eine App"}')"
check_not "Kein Kontext, wenn AUS (leer)" "additionalContext" "$(hook '{"prompt":"Baue mir eine App"}')"

check "dirigent an schaltet ein" "Dirigent ist AN" "$(hook '{"prompt":"dirigent an"}')"
check "dirigent status meldet Status" "Dirigent ist AN" "$(hook '{"prompt":"dirigent status"}')"
check "Nur 'dirigent' meldet Status" '"decision":"block"' "$(hook '{"prompt":"Dirigent"}')"
check_not "Satz mit 'dirigent aus' darin schaltet NICHT" '"decision":"block"' "$(hook '{"prompt":"Erkläre mir, wie dirigent aus funktioniert"}')"
check "Sonderzeichen im Prompt brechen nichts" '"additionalContext"' "$(hook '{"prompt":"Pfad \"C:\\\\x\" und\nZeilen"}')"

check "CLI: aus" "Dirigent ist AUS" "$(bash "$SCRIPT" aus)"
check "Env DIRIGENT_MODUS=an überschreibt Datei" "Umgebungsvariable" "$(DIRIGENT_MODUS=an bash "$SCRIPT" status)"
check "Env-Override wirkt im Hook" '"additionalContext"' "$(printf '%s' '{"prompt":"x"}' | DIRIGENT_MODUS=an bash "$SCRIPT" hook)"
bash "$SCRIPT" an >/dev/null

# Fallback ohne jq (python3)
if command -v python3 >/dev/null; then
  mkdir -p "$TMP/bin"; for t in bash tr sed cat mkdir printf python3 dirname; do p="$(command -v $t)"; [ -n "$p" ] && ln -sf "$p" "$TMP/bin/$t"; done
  out="$(printf '%s' '{"prompt":"dirigent aus"}' | PATH="$TMP/bin" bash "$SCRIPT" hook)"
  check "Ohne jq (python3-Fallback) funktioniert Schalten" "Dirigent ist AUS" "$out"
  bash "$SCRIPT" an >/dev/null
fi

echo; echo "$((n-fails))/$n Tests bestanden"
[ "$fails" -eq 0 ]
