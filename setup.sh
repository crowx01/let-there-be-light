#!/usr/bin/env bash
# let-there-be-light - interactive setup.
# Lets you pick which PAL models to enable and whether the hooks install
# globally (~/.claude/settings.json) or per-project (./.claude/settings.json).
# Writes only what you approve. Backs up any existing settings first.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------- pretty print ----------
BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
say()  { printf '%s\n' "$*"; }
ok()   { printf '%s✓%s %s\n' "$GRN" "$RST" "$*"; }
warn() { printf '%s!%s %s\n' "$YLW" "$RST" "$*"; }
err()  { printf '%s✗%s %s\n' "$RED" "$RST" "$*"; }
hd()   { printf '\n%s%s%s\n' "$BOLD" "$*" "$RST"; }

command -v jq >/dev/null || { err "jq is required (apt install jq)"; exit 1; }

# ---------- banner ----------
# dawn palette: deep-indigo -> sky -> gold -> white
INDIGO=$'\033[38;5;61m'; SKY=$'\033[38;5;117m'; GLD=$'\033[38;5;220m'; SUN=$'\033[38;5;226m'; WHT=$'\033[38;5;231m'
printf '\n'
printf '%s                    .           +   .         .%s\n' "$INDIGO" "$RST"
printf '%s        .    +    %s.-''''''-.%s      +           .    +%s\n' "$INDIGO" "$SUN" "$INDIGO" "$RST"
printf '%s              .   %s(  o   o  )%s .        +           %s\n' "$INDIGO" "$SUN" "$INDIGO" "$RST"
printf '%s   +        .      %s`--------`%s        .         +   .%s\n' "$INDIGO" "$SUN" "$INDIGO" "$RST"
printf '\n'
printf '%s          _        _      _   _                              _%s\n' "$SKY" "$RST"
printf '%s         | |  ___ | |_   | |_| |__   ___  _ __  ___    ___ | |_ %s\n' "$SKY" "$RST"
printf '%s         | | / _ \\| __|  | __| .  \\ / _ \\| .__|/ _ \\  / _ \\| .__|%s\n' "$GLD" "$RST"
printf '%s         | ||  __/| |_   | |_| | | |  __/| |  |  __/ | (_) | |_ %s\n' "$GLD" "$RST"
printf '%s         |_| \\___| \\__|  \\__|_| |_| \\___||_|   \\___|  \\___/ \\__|%s\n' "$SUN" "$RST"
printf '\n'
printf '%s                    _ _       _     _   _%s\n' "$SUN" "$RST"
printf '%s                   | (_) __ _| |__ | |_| |%s\n' "$SUN" "$RST"
printf '%s                   | | |/ _\` | .  \\| __| |%s\n' "$WHT" "$RST"
printf '%s                   | | | (_| | | | | |_|_|%s\n' "$WHT" "$RST"
printf '%s                   |_|_|\\__, |_| |_|\\__(_)%s\n' "$WHT" "$RST"
printf '%s                        |___/            %s\n' "$WHT" "$RST"
printf '\n'
printf '%s          %sinteractive setup%s   %s.%s   from design to production%s\n' "$DIM" "$BOLD" "$RST$DIM" "$GLD" "$RST$DIM" "$RST"
printf '\n'

# ---------- 0. orchestrator ----------
hd "0. Which agent orchestrator do you use?"
cat <<EOF
  ${CYN}c${RST}) claude-code    (default)   full: hooks + Skill() invocations + delegate policy
  ${CYN}r${RST}) cursor                     writes .cursor/rules/FRAMEWORK.mdc (alwaysApply)
  ${CYN}l${RST}) cline                      writes .clinerules with the delegate policy
  ${CYN}x${RST}) codex-cli (OpenAI)         writes ~/.codex/instructions.md
  ${CYN}a${RST}) aider                      writes .aider.conf.yml + FRAMEWORK.md conventions
  ${CYN}g${RST}) generic / other            writes SYSTEM_PROMPT.md you paste into any tool
EOF
read -rp "choice [c/r/l/x/a/g] (default: c): " ORCH
ORCH="${ORCH:-c}"
case "$ORCH" in
  c|r|l|x|a|g) ok "orchestrator: $ORCH" ;;
  *) err "invalid orchestrator"; exit 1 ;;
esac

# ---------- 1. scope ----------
hd "1. Where should it install?"
cat <<EOF
  ${CYN}g${RST}) global      → ~/.claude/settings.json         (loads every session, every project)
  ${CYN}p${RST}) per-project → \$PWD/.claude/settings.json      (only loads when Claude Code runs here)
  ${CYN}s${RST}) skip        → print the settings JSON to stdout, do not write anything
EOF
read -rp "choice [g/p/s] (default: p): " SCOPE
SCOPE="${SCOPE:-p}"
case "$SCOPE" in
  g|p) TARGET="" ;;  # resolved later, after we know both ORCH and SCOPE
  s)   TARGET="" ;;  # dry-run: no write
  *)   err "invalid scope"; exit 1 ;;
esac
[ "$SCOPE" = "s" ] && ok "target: stdout (dry run)"

# ---------- 2. skill auto-load ----------
hd "2. Which skills should auto-load at session start?"
say "  These are invoked as the very first tool calls of every session."
say "  Leave blank to skip a skill; type y to include it."
prompt_yn () { local q="$1" d="$2" a; read -rp "  $q [Y/n]: " a; a="${a:-$d}"; case "$a" in y|Y) echo "1" ;; *) echo "0" ;; esac; }
S_CAVE=$(prompt_yn  "caveman (compressed prose; keeps code, commands, evidence byte-exact)" y)
S_ARCH=$(prompt_yn  "architect (design phase: system design + ADRs)" y)
S_TEST=$(prompt_yn  "test-strategist (test pyramid + coverage plan)" y)
S_CLEAN=$(prompt_yn "clean-code (keep code human-readable during implementation)" y)
S_FIX=$(prompt_yn   "fix-validator (4-step pipeline for every code fix before merge/ship)" y)
S_SHIP=$(prompt_yn  "ship-checklist (pre-deploy validation + rollback plan)" y)
S_IR=$(prompt_yn    "incident-response (alert triage + runbook lookup)" n)
S_RETRO=$(prompt_yn "retrospective (post-mortem writer)" n)

# ---------- 3. models ----------
hd "3. Which PAL models should be listed in the delegate-first policy?"
say "  Pick every model your PAL install actually has keys for."
say "  Unselected models are dropped from the routing map so Claude never tries them."
M_GROQ=$(prompt_yn "groq (openai/gpt-oss-120b) - report writing, validation" y)
M_NEMO=$(prompt_yn "nemotron (nvidia via OpenRouter) - bulk reading, 1M ctx" y)
M_GROK=$(prompt_yn "grok (x-ai via OpenRouter, 2M ctx) - permissive security reasoning" y)
M_FLSH=$(prompt_yn "flash (gemini-3.6-flash) - structured extraction" y)
M_ORFR=$(prompt_yn "or-free (openrouter meta-router) - generic fallback" y)
M_PRO=$(prompt_yn "pro (gemini-3-pro-preview) - adversarial debate" y)

# guard: warn if user selected nothing (both no skills AND no models)
if [ "$S_CAVE" = 0 ] && [ "$S_ARCH" = 0 ] && [ "$S_TEST" = 0 ] && \
   [ "$S_CLEAN" = 0 ] && [ "$S_FIX" = 0 ] && [ "$S_SHIP" = 0 ] && \
   [ "$S_IR" = 0 ] && [ "$S_RETRO" = 0 ] && \
   [ "$M_GROQ" = 0 ] && [ "$M_NEMO" = 0 ] && [ "$M_GROK" = 0 ] && \
   [ "$M_FLSH" = 0 ] && [ "$M_ORFR" = 0 ] && [ "$M_PRO" = 0 ]; then
  warn "you selected no skills and no models; the hook would be inert."
  read -rp "  proceed anyway and write an empty hook? [y/N]: " a
  case "${a:-n}" in y|Y) : ;; *) err "aborted, nothing written"; exit 1 ;; esac
fi

# build a compact routing sentence based on selections
ROUTING=""
[ "$M_GROQ" = 1 ] && ROUTING+="groq (gpt-oss-120b, ~500 rpm, 8000 tpm cap) for report writing, vuln explanations, and skeptical validation. "
[ "$M_NEMO" = 1 ] && ROUTING+="nemotron (nvidia, 1M ctx) for bulk reading of large files. "
[ "$M_GROK" = 1 ] && ROUTING+="grok (x-ai, 2M ctx) for permissive high-context security reasoning when Gemini refuses. "
[ "$M_FLSH" = 1 ] && ROUTING+="flash (gemini-3.6-flash, 1M ctx) for fast structured extraction. "
[ "$M_ORFR" = 1 ] && ROUTING+="or-free (OpenRouter meta-router, 200K ctx) as generalist fallback. "
[ "$M_PRO" = 1 ]  && ROUTING+="pro (gemini-3-pro-preview) for deep-reasoning fallback and adversarial debate via mcp__pal__challenge. "
[ -z "$ROUTING" ] && ROUTING="(no PAL models selected; delegate-first policy inactive). "

# build skills list
SKILLS_LIST=""
[ "$S_CAVE" = 1 ]  && SKILLS_LIST+="\`caveman\` (full mode), "
[ "$S_ARCH" = 1 ]  && SKILLS_LIST+="\`architect\`, "
[ "$S_TEST" = 1 ]  && SKILLS_LIST+="\`test-strategist\`, "
[ "$S_CLEAN" = 1 ] && SKILLS_LIST+="\`clean-code\`, "
[ "$S_FIX" = 1 ]   && SKILLS_LIST+="\`fix-validator\` (preload), "
[ "$S_SHIP" = 1 ]  && SKILLS_LIST+="\`ship-checklist\`, "
[ "$S_IR" = 1 ]    && SKILLS_LIST+="\`incident-response\`, "
[ "$S_RETRO" = 1 ] && SKILLS_LIST+="\`retrospective\`, "
SKILLS_LIST="${SKILLS_LIST%, }"

# ---------- 4. render SessionStart + UserPromptSubmit hook bodies ----------
if [ -n "$SKILLS_LIST" ]; then
  SS_TEXT="MANDATORY FIRST ACTIONS: on session start and for EVERY model, BEFORE responding, immediately call the Skill tool for ${SKILLS_LIST}. Full preference set: (1) delegate-first via PAL: ${ROUTING}(2) KEEP IN CLAUDE: user-facing decisions, exploitation choices, severity calls, safety-boundary checks, side-effecting actions, tool-sequence orchestration. (3) Outer flow: on every significant change run the 4-phase lifecycle: design review (architect), implementation review (debate-review), staging validation (ship-checklist), post-deploy check (incident-response ready). (3b) Inner pipeline: on every code FIX before merge/ship run the 4-step fix-validation pipeline: fix-validator stress-test (12 fields), gap tests (missing coverage the validator flagged), adversarial code review via mcp__pal__challenge (pro fallback groq), synthesize + write PR description (delegate to groq). Never merge a fix that has no test that would have caught the original bug."
else
  SS_TEXT="Preferences: delegate-first via PAL: ${ROUTING}KEEP IN CLAUDE: user-facing decisions, exploitation choices, severity calls, safety-boundary checks, side-effecting actions, tool-sequence orchestration. On every significant code change run the 4-phase lifecycle (design review -> implementation review -> staging validation -> post-deploy check). On every code FIX run the 4-step fix-validation pipeline (fix-validator stress-test -> gap tests -> adversarial review via mcp__pal__challenge -> synthesize + write). Delegate PR writeups and documentation to groq."
fi

UPS_TEXT="Reminder every message: delegate aggressively to PAL to conserve tokens (${ROUTING}). Keep in Claude ONLY: user-facing decisions, exploitation choices, severity calls, safety-boundary checks, side-effecting actions, orchestration. FAILOVER: if any model refuses or errors, immediately re-route; a refusal is a routing problem, not a stop."

# ---------- 5. build settings.json ----------
# Each hook fires: printf '%s\n' '<inline JSON with additionalContext>'
build_cmd () {
  local event="$1" text="$2"
  # produce the exact command string, with double-quotes inside additionalContext escaped for JSON
  local escaped
  escaped=$(printf '%s' "$text" | sed 's/\\/\\\\/g; s/"/\\"/g')
  printf "printf '%%s\\n' '{\"hookSpecificOutput\":{\"hookEventName\":\"%s\",\"additionalContext\":\"%s\"}}'" "$event" "$escaped"
}
SS_CMD=$(build_cmd "SessionStart" "$SS_TEXT")
UPS_CMD=$(build_cmd "UserPromptSubmit" "$UPS_TEXT")
JSON=$(jq -n --arg ss "$SS_CMD" --arg ups "$UPS_CMD" '{
  hooks: {
    SessionStart:     [ { hooks: [ { type: "command", command: $ss  } ] } ],
    UserPromptSubmit: [ { hooks: [ { type: "command", command: $ups } ] } ]
  }
}')

# ---------- 6. write or dry-run ----------
if [ "$SCOPE" = "s" ]; then
  hd "config (dry run - copy manually):"
  case "$ORCH" in
    c) echo "$JSON" ;;
    *) printf '# SessionStart-equivalent\n%s\n\n# UserPromptSubmit-equivalent\n%s\n' "$SS_TEXT" "$UPS_TEXT" ;;
  esac
  exit 0
fi

# ---------- 5. resolve TARGET based on orchestrator + scope ----------
case "$ORCH" in
  c) case "$SCOPE" in
       g) TARGET="$HOME/.claude/settings.json" ;;
       p) TARGET="$PWD/.claude/settings.json" ;;
     esac ;;
  r) case "$SCOPE" in
       g) TARGET="$HOME/.cursor/rules/let-there-be-light.mdc" ;;
       p) TARGET="$PWD/.cursor/rules/let-there-be-light.mdc" ;;
     esac ;;
  l) case "$SCOPE" in
       g) TARGET="$HOME/.clinerules" ;;
       p) TARGET="$PWD/.clinerules" ;;
     esac ;;
  x) TARGET="$HOME/.codex/instructions.md" ;;
  a) case "$SCOPE" in
       g) TARGET="$HOME/.aider.let-there-be-light.md" ;;
       p) TARGET="$PWD/.aider.let-there-be-light.md" ;;
     esac ;;
  g) case "$SCOPE" in
       g) TARGET="$HOME/SYSTEM_PROMPT.let-there-be-light.md" ;;
       p) TARGET="$PWD/SYSTEM_PROMPT.let-there-be-light.md" ;;
     esac ;;
esac

hd "Ready to write ${TARGET}"
say "  Existing file will be backed up with .bak.<timestamp> suffix."
read -rp "proceed? [y/N]: " GO
[[ "$GO" =~ ^[yY]$ ]] || { warn "aborted, nothing written"; exit 0; }

mkdir -p "$(dirname "$TARGET")"
if [ -f "$TARGET" ]; then
  BAK="${TARGET}.bak.$(date +%s)"
  cp "$TARGET" "$BAK"
  ok "backup: $BAK"
fi

# ---------- 6. write in the format for the chosen orchestrator ----------
case "$ORCH" in
  c)
    # Claude Code: merge JSON hooks (preserve existing, dedup identical)
    if [ -f "$TARGET" ]; then
      jq --argjson add "$JSON" '
        def dedupe(cur; added):
          (cur // []) as $c
          | (added // []) as $a
          | $c + ($a | map(select(. as $new | $c | map(.hooks[0].command // "") | index($new.hooks[0].command // "") | not)));
        . as $orig
        | ($orig * ($add | del(.hooks)))
        | .hooks.SessionStart     = dedupe($orig.hooks.SessionStart;     $add.hooks.SessionStart)
        | .hooks.UserPromptSubmit = dedupe($orig.hooks.UserPromptSubmit; $add.hooks.UserPromptSubmit)
      ' "$TARGET" > "${TARGET}.tmp" && mv "${TARGET}.tmp" "$TARGET"
      ok "merged into $TARGET (existing hooks preserved, let-there-be-light hooks appended)"
    else
      echo "$JSON" | jq . > "$TARGET"
      ok "wrote $TARGET"
    fi
    ;;
  r)
    # Cursor: .mdc rules file with frontmatter alwaysApply:true
    cat > "$TARGET" <<MDC
---
description: let-there-be-light framework - delegate-first + failover doctrine
alwaysApply: true
---

# let-there-be-light rules

## Session context (equivalent to Claude Code SessionStart)
$SS_TEXT

## Every-message reminder (equivalent to Claude Code UserPromptSubmit)
$UPS_TEXT
MDC
    ok "wrote Cursor rules: $TARGET"
    ;;
  l)
    # Cline: .clinerules plain markdown at project root or home
    cat > "$TARGET" <<CLR
# let-there-be-light rules for Cline

## Doctrine
$SS_TEXT

## On every message
$UPS_TEXT
CLR
    ok "wrote Cline rules: $TARGET"
    ;;
  x)
    # Codex CLI: instructions.md in ~/.codex
    cat > "$TARGET" <<CDX
# let-there-be-light instructions for Codex CLI

$SS_TEXT

---
$UPS_TEXT
CDX
    ok "wrote Codex instructions: $TARGET"
    ;;
  a)
    # Aider: convention file referenced from .aider.conf.yml
    cat > "$TARGET" <<AID
# let-there-be-light conventions for Aider

$SS_TEXT

$UPS_TEXT
AID
    ok "wrote Aider convention file: $TARGET"
    warn "  add this line to your .aider.conf.yml:  read: [$TARGET]"
    ;;
  g)
    # Generic: portable SYSTEM_PROMPT.md
    cat > "$TARGET" <<GEN
# let-there-be-light SYSTEM PROMPT (portable)

Paste the contents below into your orchestrator's system prompt or rules file.

---

$SS_TEXT

---

$UPS_TEXT

---

## How to use with any AI agent
1. Copy the two sections above into your orchestrator's system prompt.
2. If your orchestrator supports per-message rules, put the second section there.
3. Skill invocations (Skill(x)) are Claude Code-only. On other orchestrators,
   reference the skill by name in your prompt and cite the SKILL.md content.
GEN
    ok "wrote generic system prompt: $TARGET"
    ;;
esac

# ---------- 6b. optional: symlink shipped skills so Claude Code can discover them ----------
SKILLS_SRC="$SCRIPT_DIR/skills"
if [ "$ORCH" = "c" ] && [ -d "$SKILLS_SRC" ]; then
  case "$SCOPE" in
    g) SKILLS_DST="$HOME/.claude/skills" ;;
    p) SKILLS_DST="$PWD/.claude/skills" ;;
  esac
  read -rp "symlink shipped skills into $SKILLS_DST? [Y/n]: " a
  case "${a:-y}" in
    y|Y)
      mkdir -p "$SKILLS_DST"
      for d in "$SKILLS_SRC"/*/; do
        name=$(basename "$d")
        target="$SKILLS_DST/$name"
        if [ -e "$target" ] && [ ! -L "$target" ]; then
          warn "skipping $name: destination exists and is not a symlink"
          continue
        fi
        ln -sfn "$d" "$target" && ok "symlinked $name -> $target"
      done
      ;;
    *) warn "skipped skill symlinking; you must place skills under $SKILLS_DST manually" ;;
  esac
fi

# ---------- 6c. sanity-check: is PAL registered in ~/.claude.json? (Claude Code only) ----------
if [ "$ORCH" = "c" ] && [ -f "$HOME/.claude.json" ]; then
  if jq -e '.mcpServers.pal // (.projects | to_entries[]?.value.mcpServers.pal)' "$HOME/.claude.json" >/dev/null 2>&1; then
    ok "PAL MCP server is registered in ~/.claude.json"
  else
    warn "PAL is NOT registered in ~/.claude.json"
    warn "  add it under mcpServers.pal (see https://github.com/BeehiveInnovations/zen-mcp-server)"
    warn "  Claude Code will silently fail to invoke PAL tools until you do."
  fi
else
  warn "~/.claude.json not found; make sure PAL is registered before starting Claude Code"
fi

# ---------- 6d. copy skill files for non-Claude orchestrators ----------
# For non-Claude, the model can't invoke Skill() directly, but it can still read
# the SKILL.md content. Copy skills into a sibling folder so the rules file can
# reference them and the other model has the same knowledge.
if [ "$ORCH" != "c" ] && [ -d "$SKILLS_SRC" ]; then
  SKILLS_MIRROR="$(dirname "$TARGET")/let-there-be-light-skills"
  read -rp "copy skill files into $SKILLS_MIRROR so the model can read them? [Y/n]: " a
  case "${a:-y}" in
    y|Y)
      mkdir -p "$SKILLS_MIRROR"
      for d in "$SKILLS_SRC"/*/; do
        name=$(basename "$d")
        dst="$SKILLS_MIRROR/$name"
        if [ -e "$dst" ] && [ ! -L "$dst" ] && [ ! -d "$dst" ]; then
          warn "skipping $name: destination exists and is not a directory or symlink"
          continue
        fi
        # cp -a preserves LICENSE and any scripts/references; a symlink would be
        # portable but is less friendly for user editing on non-Claude tools.
        cp -a "$d" "$SKILLS_MIRROR/" 2>/dev/null && ok "copied $name -> $dst"
      done
      # append a short pointer to the rules file so the other model knows the skills exist
      case "$ORCH" in
        r|l|x|a|g)
          {
            echo
            echo "## Skills available (read these when their trigger phrases appear)"
            for d in "$SKILLS_MIRROR"/*/; do
              n=$(basename "$d")
              echo "- \`$n\`: see [$n/SKILL.md](let-there-be-light-skills/$n/SKILL.md)"
            done
          } >> "$TARGET"
          ok "appended skills index to $TARGET"
          ;;
      esac
      ;;
    *) warn "skipped skill copy; the model won't see skill descriptions" ;;
  esac
fi

# ---------- 7. .env handling: template + optional interactive key entry ----------
NEEDS_ENV=0
[ "$M_GROQ" = 1 ] && NEEDS_ENV=1
[ "$M_NEMO" = 1 ] && NEEDS_ENV=1
[ "$M_GROK" = 1 ] && NEEDS_ENV=1
[ "$M_FLSH" = 1 ] && NEEDS_ENV=1
[ "$M_ORFR" = 1 ] && NEEDS_ENV=1
[ "$M_PRO" = 1 ] && NEEDS_ENV=1

if [ "$NEEDS_ENV" = 1 ]; then
  ENV_EXAMPLE="$(dirname "$TARGET")/.env.lttbl.example"
  ENV_REAL="$(dirname "$TARGET")/.env.lttbl"

  # always write the placeholder example (unquoted heredoc so $( ) expands)
  cat > "$ENV_EXAMPLE" <<EOF
# let-there-be-light API keys - source this from your shell rc, or export before starting Claude Code.
# Do NOT commit the real values.
$( [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ] && echo "export GEMINI_API_KEY=your-gemini-key" )
$( [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ] && echo "export OPENROUTER_API_KEY=your-openrouter-key" )
$( [ "$M_GROQ" = 1 ] && printf '%s\n' "export CUSTOM_API_URL=https://api.groq.com/openai/v1" "export CUSTOM_API_KEY=your-groq-key" )
EOF
  ok "wrote env template: $ENV_EXAMPLE"

  # interactive key entry (per-provider instructions, silent read)
  hd "7. Enter API keys now to complete installation?"
  say "  You can skip and edit $(basename "$ENV_EXAMPLE") later, or enter them now"
  say "  to have a real .env.lttbl written with 0600 permissions."
  ASK_KEYS=$(prompt_yn "enter API keys now?" y)

  GROQ_KEY=""; OR_KEY=""; GEMINI_KEY=""

  if [ "$ASK_KEYS" = 1 ]; then
    # -- Groq (M_GROQ)
    if [ "$M_GROQ" = 1 ]; then
      hd "  ${GLD}Groq${RST} (report writing, validation)"
      say "    ${DIM}How to get one:${RST}"
      say "      1. Open ${CYN}https://console.groq.com/keys${RST}"
      say "      2. Sign in with Google or GitHub"
      say "      3. Click 'Create API Key', name it 'let-there-be-light'"
      say "      4. Copy the key (starts with 'gsk_')"
      say "    ${DIM}Free tier: gpt-oss-120b with ~500 rpm.${RST}"
      read -rsp "    paste Groq key (input hidden, ENTER to skip): " GROQ_KEY; echo
      GROQ_KEY=$(printf '%s' "$GROQ_KEY" | tr -d '[:space:]')
    fi
    # -- OpenRouter (any of M_NEMO / M_GROK / M_ORFR)
    if [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ]; then
      hd "  ${GLD}OpenRouter${RST} (nemotron / grok / or-free share this key)"
      say "    ${DIM}How to get one:${RST}"
      say "      1. Open ${CYN}https://openrouter.ai/settings/keys${RST}"
      say "      2. Sign in with Google or GitHub"
      say "      3. Click 'Create Key', name it 'let-there-be-light'"
      say "      4. Copy the key (starts with 'sk-or-v1-')"
      say "    ${DIM}Free-tier models (nemotron, grok-fast, meta-router) don't require credit.${RST}"
      read -rsp "    paste OpenRouter key (input hidden, ENTER to skip): " OR_KEY; echo
      OR_KEY=$(printf '%s' "$OR_KEY" | tr -d '[:space:]')
    fi
    # -- Google Gemini (M_FLSH or M_PRO)
    if [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ]; then
      hd "  ${GLD}Google Gemini${RST} (flash / pro share this key)"
      say "    ${DIM}How to get one:${RST}"
      say "      1. Open ${CYN}https://aistudio.google.com/apikey${RST}"
      say "      2. Sign in with Google"
      say "      3. Click 'Create API Key' in a new or existing Google Cloud project"
      say "      4. Copy the key"
      say "    ${DIM}Free tier: generous flash/pro quotas.${RST}"
      read -rsp "    paste Gemini key (input hidden, ENTER to skip): " GEMINI_KEY; echo
      GEMINI_KEY=$(printf '%s' "$GEMINI_KEY" | tr -d '[:space:]')
    fi

    # write real .env.lttbl with 0600 perms
    umask_prev=$(umask); umask 077
    {
      [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ] && printf 'export GEMINI_API_KEY=%s\n'    "${GEMINI_KEY:-your-gemini-key}"
      [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ] && printf 'export OPENROUTER_API_KEY=%s\n' "${OR_KEY:-your-openrouter-key}"
      if [ "$M_GROQ" = 1 ]; then
        printf 'export CUSTOM_API_URL=https://api.groq.com/openai/v1\n'
        printf 'export CUSTOM_API_KEY=%s\n' "${GROQ_KEY:-your-groq-key}"
      fi
    } > "$ENV_REAL"
    chmod 600 "$ENV_REAL"
    umask "$umask_prev"
    ok "wrote $ENV_REAL (0600)"

    # summary of what was captured
    hd "7b. Key entry summary"
    if [ "$M_GROQ" = 1 ]; then
      [ -n "$GROQ_KEY"   ] && ok "  Groq       entered" || warn "  Groq       placeholder (edit $ENV_REAL to add it)"
    fi
    if [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ]; then
      [ -n "$OR_KEY"     ] && ok "  OpenRouter entered" || warn "  OpenRouter placeholder (edit $ENV_REAL to add it)"
    fi
    if [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ]; then
      [ -n "$GEMINI_KEY" ] && ok "  Gemini     entered" || warn "  Gemini     placeholder (edit $ENV_REAL to add it)"
    fi
  else
    say "  skipped interactive key entry; only the example was written."
    warn "  edit $ENV_EXAMPLE and rename to .env.lttbl before starting your orchestrator."
  fi
fi

# ---------- 8. next steps ----------
hd "Next steps"
case "$ORCH" in
  c)
    cat <<EOF
  1. Register PAL as an MCP server in ~/.claude.json:
     ${DIM}"mcpServers": { "pal": { "type": "stdio", "command": "/path/to/zen-mcp-server/.pal_venv/bin/python", "args": ["/path/to/zen-mcp-server/server.py"], "env": { ...keys... } } }${RST}
  2. Source your API keys: ${CYN}source $(dirname "$TARGET")/.env.lttbl${RST}
     ${DIM}(falls back to .env.lttbl.example if you skipped interactive entry)${RST}
  3. Restart Claude Code.
  4. On the next session start you should see the auto-invoked skills fire immediately.
EOF
    ;;
  r)
    cat <<EOF
  1. Set your provider API keys via environment: source $(dirname "$TARGET")/.env.lttbl
  2. Open your project in Cursor.
  3. Rules in .cursor/rules/*.mdc are applied automatically (alwaysApply:true).
  4. The other model (not Claude) has no Skill() primitive; ask it to read
     let-there-be-light-skills/<name>/SKILL.md when a trigger phrase appears.
EOF
    ;;
  l)
    cat <<EOF
  1. Set your provider API keys via environment: source $(dirname "$TARGET")/.env.lttbl
  2. Open your project in the VS Code extension for Cline.
  3. Cline reads .clinerules automatically as system prompt.
  4. Ask Cline to read let-there-be-light-skills/<name>/SKILL.md when triggers appear.
EOF
    ;;
  x)
    cat <<EOF
  1. Set your provider API keys via environment.
  2. Codex CLI will read ~/.codex/instructions.md as its base prompt.
  3. Skill files under $(dirname "$TARGET")/let-there-be-light-skills/ are pointed to
     from the instructions; ask Codex to read them when triggers appear.
EOF
    ;;
  a)
    cat <<EOF
  1. Set your provider API keys via environment.
  2. Add this to your .aider.conf.yml:  ${CYN}read: [$TARGET]${RST}
  3. Skill files copied next to the conventions can be read via /read.
EOF
    ;;
  g)
    cat <<EOF
  1. Copy the contents of $TARGET into your orchestrator's system prompt.
  2. Skill files sit at $(dirname "$TARGET")/let-there-be-light-skills/ - reference them
     from the system prompt or paste inline for the models to see.
  3. Set your provider API keys via environment.
EOF
    ;;
esac
echo
ok "let-there-be-light setup complete."
