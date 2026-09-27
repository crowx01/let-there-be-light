#!/usr/bin/env bash
# let-there-be-light - interactive setup (v2 - multi-select, resume, auto-sync).
# Writes only what you approve. Backs up any existing settings first.
# Ctrl+C is safe: state is checkpointed at $XDG_STATE_HOME/lttbl/install-state
# and a re-run resumes at the first incomplete step.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="$SCRIPT_DIR/bin"

SETUP_BRAND="lttbl"
# shellcheck source=bin/setup-lib.sh
. "$BIN_DIR/setup-lib.sh"

command -v jq >/dev/null || { err "jq is required (apt install jq)"; exit 1; }

# ---------- banner (function; only printed for interactive install) ----------
INDIGO=$'\033[38;5;61m'; SKY=$'\033[38;5;117m'; GLD=$'\033[38;5;220m'; SUN=$'\033[38;5;226m'; WHT=$'\033[38;5;231m'
print_banner() {
  printf '\n'
  printf '%s                              \\   |   /%s\n'        "$GLD" "$RST"
  printf '%s                            .  .---.  .%s\n'         "$SUN" "$RST"
  printf '%s                         --   ( %s(*)%s )   --%s\n'  "$GLD" "$SUN" "$GLD" "$RST"
  printf '%s                            .  `---`  .%s\n'         "$SUN" "$RST"
  printf '%s                              /   |   \\%s\n'        "$GLD" "$RST"
  printf '\n'
  printf '%s      ██╗     ███████╗████████╗    ████████╗██╗  ██╗███████╗██████╗ ███████╗%s\n' "$SKY" "$RST"
  printf '%s      ██║     ██╔════╝╚══██╔══╝    ╚══██╔══╝██║  ██║██╔════╝██╔══██╗██╔════╝%s\n' "$SKY" "$RST"
  printf '%s      ██║     █████╗     ██║          ██║   ███████║█████╗  ██████╔╝█████╗  %s\n' "$GLD" "$RST"
  printf '%s      ██║     ██╔══╝     ██║          ██║   ██╔══██║██╔══╝  ██╔══██╗██╔══╝  %s\n' "$GLD" "$RST"
  printf '%s      ███████╗███████╗   ██║          ██║   ██║  ██║███████╗██║  ██║███████╗%s\n' "$SUN" "$RST"
  printf '%s      ╚══════╝╚══════╝   ╚═╝          ╚═╝   ╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝%s\n' "$SUN" "$RST"
  printf '\n'
  printf '%s              ██████╗ ███████╗    ██╗     ██╗ ██████╗ ██╗  ██╗████████╗%s\n' "$WHT" "$RST"
  printf '%s              ██╔══██╗██╔════╝    ██║     ██║██╔════╝ ██║  ██║╚══██╔══╝%s\n' "$WHT" "$RST"
  printf '%s              ██████╔╝█████╗      ██║     ██║██║  ███╗███████║   ██║   %s\n' "$WHT" "$RST"
  printf '%s              ██╔══██╗██╔══╝      ██║     ██║██║   ██║██╔══██║   ██║   %s\n' "$WHT" "$RST"
  printf '%s              ██████╔╝███████╗    ███████╗██║╚██████╔╝██║  ██║   ██║   %s\n' "$WHT" "$RST"
  printf '%s              ╚═════╝ ╚══════╝    ╚══════╝╚═╝ ╚═════╝ ╚═╝  ╚═╝   ╚═╝   %s\n' "$WHT" "$RST"
  printf '\n'
  printf '%s          %sinteractive setup%s   %s.%s   from design to production%s\n\n' \
         "$DIM" "$BOLD" "$RST$DIM" "$GLD" "$RST$DIM" "$RST"
}

# ---------- CLI subcommands (add / list / sync / --help) ----------
usage() {
  cat <<HLP
${BOLD}let-there-be-light setup${RST}

  ./setup.sh              interactive install (resumes if interrupted)
  ./setup.sh add SKILL    install a single shipped skill into ~/.claude/skills
  ./setup.sh list         list shipped skills
  ./setup.sh sync         re-run rules + skills sync (no prompts)
  ./setup.sh reset        clear installation checkpoint
  ./setup.sh --help       this help

Environment:
  STATE_DIR   default \$XDG_STATE_HOME/lttbl (checkpoint location)
  LTTBL_DEST  override skills-destination for 'add'
HLP
}

SKILLS_SRC="$SCRIPT_DIR/skills"

cmd_list() {
  step "shipped skills"
  local d name desc
  for d in "$SKILLS_SRC"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    desc=""
    if [ -f "$d/SKILL.md" ]; then
      desc=$(awk -F': ' '/^description:/ {sub(/^description: */,""); print; exit}' "$d/SKILL.md" | head -c 120)
    fi
    printf '  %s%s%s  %s%s%s\n' "$BOLD" "$name" "$RST" "$DIM" "$desc" "$RST"
  done
}

cmd_add() {
  local skill="${1:-}"
  [ -z "$skill" ] && { err "usage: ./setup.sh add <skill>"; cmd_list; exit 2; }
  local src="$SKILLS_SRC/$skill"
  [ -d "$src" ] || { err "unknown skill: $skill"; cmd_list; exit 2; }
  local dst="${LTTBL_DEST:-$HOME/.claude/skills}"
  ensure_dir "$dst"
  if [ -e "$dst/$skill" ] && [ ! -L "$dst/$skill" ]; then
    warn "$dst/$skill exists (not a symlink); leaving it in place"
  else
    ln -sfn "$src" "$dst/$skill"
    ok "linked $skill → $dst/$skill"
  fi
}

cmd_sync() {
  info "re-syncing skills + rules from $SCRIPT_DIR"
  ensure_dir "$HOME/.claude/skills"
  local d
  for d in "$SKILLS_SRC"/*/; do
    [ -d "$d" ] || continue
    ln -sfn "$d" "$HOME/.claude/skills/$(basename "$d")"
  done
  ok "synced $(find "$SKILLS_SRC" -maxdepth 1 -mindepth 1 -type d | wc -l) skills"
}

case "${1:-}" in
  -h|--help|help) usage; exit 0 ;;
  add)   shift; cmd_add "$@"; exit $? ;;
  list)  cmd_list; exit 0 ;;
  sync)  cmd_sync; exit 0 ;;
  reset) state_clear; ok "checkpoint cleared"; exit 0 ;;
esac

print_banner

# ---------- checkpoint bootstrap ----------
state_init
STEPS=(
  "orch|Orchestrator selection"
  "scope|Install scope"
  "skills_pick|Skill preload picks"
  "models_pick|PAL model picks"
  "write_target|Rules/settings file"
  "claude_md|CLAUDE.md doctrine"
  "skills_install|Skills installed"
  "pal_register|PAL MCP registered"
  "env_keys|API keys"
)
resume_banner "${STEPS[@]}"

# ---------- 0. orchestrator ----------
if state_done orch && [ -n "$(state_get orch_val)" ]; then
  ORCH=$(state_get orch_val)
  ok "orchestrator (cached): $ORCH"
else
  step "0. Which agent orchestrator do you use?"
  ORCH_LABELS=(
    "claude-code  (default)          hooks + Skill() + delegate policy"
    "cursor                          writes .cursor/rules/*.mdc (alwaysApply)"
    "cline                           writes .clinerules"
    "codex-cli    (OpenAI)           writes ~/.codex/instructions.md"
    "aider                           writes .aider.*.md + conf entry"
    "generic / other                 writes SYSTEM_PROMPT.md (portable)"
  )
  ORCH_KEYS=(c r l x a g)
  menu_select ORCH_IDX 0 "${ORCH_LABELS[@]}"
  ORCH="${ORCH_KEYS[$ORCH_IDX]}"
  state_set orch_val "$ORCH"; state_mark orch
  ok "orchestrator: $ORCH"
fi

# ---------- 1. scope ----------
if state_done scope && [ -n "$(state_get scope_val)" ]; then
  SCOPE=$(state_get scope_val)
  ok "scope (cached): $SCOPE"
else
  step "1. Where should it install?"
  SCOPE_LABELS=(
    "global      → ~/.claude/settings.json         (every session, every project)"
    "per-project → \$PWD/.claude/settings.json      (only in this project)"
    "skip        → dry run, print JSON, write nothing"
  )
  SCOPE_KEYS=(g p s)
  menu_select SCOPE_IDX 1 "${SCOPE_LABELS[@]}"
  SCOPE="${SCOPE_KEYS[$SCOPE_IDX]}"
  state_set scope_val "$SCOPE"; state_mark scope
  ok "scope: $SCOPE"
fi

# ---------- 2. skills ----------
if state_done skills_pick && [ -n "$(state_get skills_val)" ]; then
  SKILL_FLAGS="$(state_get skills_val)"
  ok "skills (cached): $SKILL_FLAGS"
else
  step "2. Which skills should auto-load at session start?"
  say "  Space toggles · Enter confirms · a=all · n=none"
  SKILL_NAMES=(caveman architect test-strategist clean-code fix-validator ship-checklist incident-response retrospective)
  SKILL_LABELS=(
    "caveman            compressed prose; keeps evidence byte-exact"
    "architect          design phase: system design + ADRs"
    "test-strategist    test pyramid + coverage plan"
    "clean-code         keep code human-readable during implementation"
    "fix-validator      4-step pipeline for every code fix before ship"
    "ship-checklist     pre-deploy validation + rollback plan"
    "incident-response  alert triage + runbook lookup"
    "retrospective      post-mortem writer"
  )
  multiselect SKILL_FLAGS "1,1,1,1,1,1,0,0" "${SKILL_LABELS[@]}"
  state_set skills_val "$SKILL_FLAGS"; state_mark skills_pick
fi
read -r -a _SF <<< "$SKILL_FLAGS"
S_CAVE=${_SF[0]:-0}; S_ARCH=${_SF[1]:-0}; S_TEST=${_SF[2]:-0}
S_CLEAN=${_SF[3]:-0}; S_FIX=${_SF[4]:-0}; S_SHIP=${_SF[5]:-0}
S_IR=${_SF[6]:-0}; S_RETRO=${_SF[7]:-0}

# ---------- 3. models ----------
if state_done models_pick && [ -n "$(state_get models_val)" ]; then
  MODEL_FLAGS="$(state_get models_val)"
  ok "models (cached): $MODEL_FLAGS"
else
  step "3. Which PAL models do you have keys for?"
  say "  Unselected models are dropped from the routing map."
  MODEL_LABELS=(
    "groq       gpt-oss-120b     report writing, validation"
    "nemotron   nvidia (OR)      bulk reading, 1M ctx"
    "grok       x-ai (OR)        permissive security reasoning, 2M ctx"
    "flash      gemini-3.6       structured extraction"
    "or-free    OR meta-router   generalist fallback"
    "pro        gemini-3.1-pro   adversarial debate"
  )
  multiselect MODEL_FLAGS "1,1,1,1,1,1" "${MODEL_LABELS[@]}"
  state_set models_val "$MODEL_FLAGS"; state_mark models_pick
fi
read -r -a _MF <<< "$MODEL_FLAGS"
M_GROQ=${_MF[0]:-0}; M_NEMO=${_MF[1]:-0}; M_GROK=${_MF[2]:-0}
M_FLSH=${_MF[3]:-0}; M_ORFR=${_MF[4]:-0}; M_PRO=${_MF[5]:-0}

# ---------- guard ----------
if [ "$S_CAVE$S_ARCH$S_TEST$S_CLEAN$S_FIX$S_SHIP$S_IR$S_RETRO" = "00000000" ] && \
   [ "$M_GROQ$M_NEMO$M_GROK$M_FLSH$M_ORFR$M_PRO" = "000000" ]; then
  warn "you selected no skills and no models; the hook would be inert."
  read -rp "  proceed anyway? [y/N]: " a
  [[ "${a:-n}" =~ ^[yY]$ ]] || { err "aborted"; exit 1; }
fi

# ---------- routing sentence ----------
ROUTING=""
[ "$M_GROQ" = 1 ] && ROUTING+="groq (gpt-oss-120b, ~500 rpm, 8000 tpm cap) for report writing, vuln explanations, and skeptical validation. "
[ "$M_NEMO" = 1 ] && ROUTING+="nemotron (nvidia, 1M ctx) for bulk reading of large files. "
[ "$M_GROK" = 1 ] && ROUTING+="grok (x-ai, 2M ctx) for permissive high-context security reasoning when Gemini refuses. "
[ "$M_FLSH" = 1 ] && ROUTING+="flash (gemini-3.6-flash, 1M ctx) for fast structured extraction. "
[ "$M_ORFR" = 1 ] && ROUTING+="or-free (OpenRouter meta-router, 200K ctx) as generalist fallback. "
[ "$M_PRO" = 1 ]  && ROUTING+="pro (gemini-3.1-pro-preview) for deep-reasoning fallback and adversarial debate via mcp__pal__challenge. "
[ -z "$ROUTING" ] && ROUTING="(no PAL models selected; delegate-first policy inactive). "

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

if [ -n "$SKILLS_LIST" ]; then
  SS_TEXT="Doctrine + routing map are in CLAUDE.md at the project root (already loaded). Preload skills now: ${SKILLS_LIST}."
else
  SS_TEXT="Doctrine + routing map are in CLAUDE.md at the project root (already loaded)."
fi
UPS_TEXT="Every message: DEFAULT TO PAL for each task (bulk read to nemotron, write/validate to groq, structured to flash per CLAUDE.md routing); read source via $BIN_DIR/code-skeleton first, pipe build/test output through $BIN_DIR/strip-noise; keep only decisions/severity/safety/side-effects in Claude; failover on refusal, never stop."

# ---------- 4. render settings.json ----------
build_cmd () {
  local event="$1" text="$2" escaped
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

# ---------- 5. dry-run branch ----------
if [ "$SCOPE" = "s" ]; then
  step "config (dry run - copy manually):"
  case "$ORCH" in
    c) echo "$JSON" ;;
    *) printf '# SessionStart-equivalent\n%s\n\n# UserPromptSubmit-equivalent\n%s\n' "$SS_TEXT" "$UPS_TEXT" ;;
  esac
  exit 0
fi

# ---------- 6. resolve TARGET ----------
case "$ORCH" in
  c) case "$SCOPE" in g) TARGET="$HOME/.claude/settings.json" ;; p) TARGET="$PWD/.claude/settings.json" ;; esac ;;
  r) case "$SCOPE" in g) TARGET="$HOME/.cursor/rules/let-there-be-light.mdc" ;; p) TARGET="$PWD/.cursor/rules/let-there-be-light.mdc" ;; esac ;;
  l) case "$SCOPE" in g) TARGET="$HOME/.clinerules" ;; p) TARGET="$PWD/.clinerules" ;; esac ;;
  x) TARGET="$HOME/.codex/instructions.md" ;;
  a) case "$SCOPE" in g) TARGET="$HOME/.aider.let-there-be-light.md" ;; p) TARGET="$PWD/.aider.let-there-be-light.md" ;; esac ;;
  g) case "$SCOPE" in g) TARGET="$HOME/SYSTEM_PROMPT.let-there-be-light.md" ;; p) TARGET="$PWD/SYSTEM_PROMPT.let-there-be-light.md" ;; esac ;;
esac

step "Ready to write $TARGET"
say "  Existing file will be backed up with .bak.<timestamp> suffix."
say "  Rules + skills will be installed automatically after this."
if [ -z "${LTTBL_YES:-}" ]; then
  read -rp "  proceed? [Y/n]: " GO
  [[ "${GO:-y}" =~ ^[nN]$ ]] && { warn "aborted"; exit 0; }
fi

# ---------- 7. write target ----------
write_target() {
  ensure_dir "$(dirname "$TARGET")"
  backup_once "$TARGET"
  case "$ORCH" in
    c)
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
      else
        echo "$JSON" | jq . > "$TARGET"
      fi ;;
    r) cat > "$TARGET" <<MDC
---
description: let-there-be-light framework - delegate-first + failover doctrine
alwaysApply: true
---

# let-there-be-light rules

## Session context
$SS_TEXT

## Every-message reminder
$UPS_TEXT
MDC
      ;;
    l) printf '# let-there-be-light rules for Cline\n\n## Doctrine\n%s\n\n## On every message\n%s\n' "$SS_TEXT" "$UPS_TEXT" > "$TARGET" ;;
    x) printf '# let-there-be-light instructions for Codex CLI\n\n%s\n\n---\n%s\n' "$SS_TEXT" "$UPS_TEXT" > "$TARGET" ;;
    a) printf '# let-there-be-light conventions for Aider\n\n%s\n\n%s\n' "$SS_TEXT" "$UPS_TEXT" > "$TARGET" ;;
    g) printf '# let-there-be-light SYSTEM PROMPT (portable)\n\n%s\n\n---\n%s\n' "$SS_TEXT" "$UPS_TEXT" > "$TARGET" ;;
  esac
  ok "wrote $TARGET"
}
checkpoint write_target "write $TARGET" write_target

# ---------- 8. CLAUDE.md doctrine ----------
case "$SCOPE" in g) CLAUDE_MD="$HOME/CLAUDE.md" ;; p) CLAUDE_MD="$PWD/CLAUDE.md" ;; esac
write_claude_md() {
  [ -n "$CLAUDE_MD" ] || return 0
  backup_once "$CLAUDE_MD"
  local SIBLING_PRESENT=0
  [ -f "$CLAUDE_MD" ] && grep -q '<!-- BEGIN sauron doctrine' "$CLAUDE_MD" && SIBLING_PRESENT=1
  local DOC_BLOCK
  if [ "$SIBLING_PRESENT" = 1 ]; then
    DOC_BLOCK=$(cat <<CLAUDEMD

<!-- BEGIN let-there-be-light doctrine (managed by setup.sh; sibling: sauron) -->
# let-there-be-light doctrine (lean; shared rules provided by sibling block)

Sibling framework \`sauron\` supplies: delegate-first routing, keep-in-Claude list, failover doctrine, token-efficiency rules, response terseness ladder, preempt-shell-bloat rules, failure-map, and route-plan pre-flight.

## 4-step validation pipeline (lttbl variant: per code fix before ship)
A. Stress-test via fix-validator skill.
B. Run the gap tests the validator flags.
C. Adversarial challenge via mcp__pal__challenge (pro primary, groq fallback).
D. Synthesize with confidence markers; groq drafts prose, Claude spot-checks low-confidence claims only.

## Preloaded skills
${SKILLS_LIST:-(none preloaded; all skills lazy-load on trigger phrase)}
<!-- END let-there-be-light doctrine -->
CLAUDEMD
)
  else
    DOC_BLOCK=$(cat <<CLAUDEMD

<!-- BEGIN let-there-be-light doctrine (managed by setup.sh; regenerate to update) -->
# let-there-be-light doctrine

## Delegate-first routing
${ROUTING}

## Keep in Claude ONLY
- user-facing decisions
- exploitation choices, severity calls
- safety-boundary checks (no 3rd-party data, no destructive actions)
- side-effecting actions
- tool-sequence orchestration

## Failover
Any model refusal or error routes to the next model in the map. A classifier refusal is a routing problem, not a stop.

## 4-step validation pipeline
A. Stress-test via fix-validator skill.
B. Run the gap tests the validator flags.
C. Adversarial challenge via mcp__pal__challenge (pro primary, groq fallback).
D. Synthesize with confidence markers; groq drafts prose, Claude spot-checks.

## Token efficiency rules
- Read source with $BIN_DIR/code-skeleton before whole files. Pipe noisy output through $BIN_DIR/strip-noise.
- Any tool output over 5 KB routes through nemotron (bulk) or flash (structured).
- Batch related PAL sub-tasks into one structured call.
- Never re-Read a file already Read this session.

## Preloaded skills
${SKILLS_LIST:-(none preloaded; all skills lazy-load on trigger phrase)}
<!-- END let-there-be-light doctrine -->
CLAUDEMD
)
  fi
  if [ -f "$CLAUDE_MD" ]; then
    awk 'BEGIN{skip=0}
      /^<!-- BEGIN let-there-be-light doctrine/{skip=1; next}
      /^<!-- END let-there-be-light doctrine/{skip=0; next}
      skip==0{print}' "$CLAUDE_MD" > "${CLAUDE_MD}.tmp" && mv "${CLAUDE_MD}.tmp" "$CLAUDE_MD"
  fi
  printf '%s\n' "$DOC_BLOCK" >> "$CLAUDE_MD"
  ok "wrote CLAUDE.md doctrine: $CLAUDE_MD"
}
checkpoint claude_md "install CLAUDE.md doctrine" write_claude_md

# ---------- 9. skills install (auto, no prompt) ----------
# Item 8/9/10: always install rules + skills; Cursor gets its own dirs.
install_skills() {
  [ -d "$SKILLS_SRC" ] || { warn "no skills/ dir shipped; nothing to install"; return 0; }
  local dst
  case "$ORCH" in
    c)
      case "$SCOPE" in g) dst="$HOME/.claude/skills" ;; p) dst="$PWD/.claude/skills" ;; esac
      ensure_dir "$dst"
      local d name
      for d in "$SKILLS_SRC"/*/; do
        [ -d "$d" ] || continue
        name=$(basename "$d")
        if [ -e "$dst/$name" ] && [ ! -L "$dst/$name" ]; then
          warn "skipping $name: $dst/$name exists (not a symlink)"; continue
        fi
        ln -sfn "$d" "$dst/$name"
      done
      ok "linked $(find "$SKILLS_SRC" -maxdepth 1 -mindepth 1 -type d | wc -l) skills → $dst" ;;
    r)
      # Cursor: item 10 - skills-cursor/ + rules/ at project (or ~) root
      local root
      case "$SCOPE" in g) root="$HOME" ;; p) root="$PWD" ;; esac
      ensure_dir "$root/skills-cursor" "$root/rules"
      sync_dir "$SKILLS_SRC" "$root/skills-cursor"
      # rules/ mirrors the .mdc so cursor's default rules resolver finds it too
      cp -f "$TARGET" "$root/rules/let-there-be-light.mdc" 2>/dev/null || true
      ok "installed skills → $root/skills-cursor  rules → $root/rules" ;;
    *)
      local mirror="$(dirname "$TARGET")/let-there-be-light-skills"
      sync_dir "$SKILLS_SRC" "$mirror"
      ok "installed skills → $mirror"
      # append index to rules file if not already present
      if ! grep -q '^## Skills available' "$TARGET" 2>/dev/null; then
        {
          echo
          echo "## Skills available (read these when their trigger phrases appear)"
          for d in "$mirror"/*/; do
            n=$(basename "$d")
            echo "- \`$n\`: see [$n/SKILL.md](let-there-be-light-skills/$n/SKILL.md)"
          done
        } >> "$TARGET"
      fi ;;
  esac
}
checkpoint skills_install "install skills" install_skills

# ---------- 10. PAL MCP register ----------
PAL_DIR="${PAL_DIR:-$HOME/tools/pal-mcp-server}"
PAL_REPO="https://github.com/crowx01/pal-mcp-server"
register_pal() {
  [ "$ORCH" = "c" ] || { warn "non-Claude orchestrator: install PAL manually ($PAL_REPO)"; return 0; }

  # Always ensure the agentic toolbelt config exists (fresh installs AND upgrades).
  # bash is further limited to a read-only command allowlist baked into pal itself.
  if [ ! -f "$HOME/.pal/toolbelt.json" ]; then
    mkdir -p "$HOME/.pal"
    cat > "$HOME/.pal/toolbelt.json" <<'TBJSON'
{
  "tools": [
    {"name": "bash",      "enabled": true,  "sandbox": "readonly"},
    {"name": "read_file", "enabled": true,  "sandbox": "readonly"},
    {"name": "gh",        "enabled": true,  "sandbox": "readonly"},
    {"name": "web_fetch", "enabled": true,  "sandbox": "readonly"},
    {"name": "clink",     "enabled": false, "sandbox": "readonly"}
  ]
}
TBJSON
    ok "wrote default toolbelt config → ~/.pal/toolbelt.json"
  fi

  [ -f "$HOME/.claude.json" ] || echo '{}' > "$HOME/.claude.json"
  local tmp

  # Upgrade path: pal already registered -> ensure PAL_TOOLBELT=1 without
  # clobbering other env keys (mktemp+mv; never redirect jq back onto its input).
  if jq -e '.mcpServers.pal' "$HOME/.claude.json" >/dev/null 2>&1; then
    if jq -e '.mcpServers.pal.env.PAL_TOOLBELT' "$HOME/.claude.json" >/dev/null 2>&1; then
      ok "PAL MCP already registered (toolbelt on)"
    else
      tmp="$(mktemp)"
      jq '.mcpServers.pal.env = ((.mcpServers.pal.env // {}) + {PAL_TOOLBELT:"1"})' \
        "$HOME/.claude.json" > "$tmp" && mv "$tmp" "$HOME/.claude.json"
      ok "PAL MCP upgraded: PAL_TOOLBELT=1 added to existing registration"
    fi
    return 0
  fi

  # Fresh install.
  command -v git >/dev/null 2>&1 || { err "git not found"; return 1; }
  command -v python3 >/dev/null 2>&1 || { err "python3 not found"; return 1; }
  if [ ! -d "$PAL_DIR/.git" ]; then
    info "cloning $PAL_REPO → $PAL_DIR"
    git clone --depth 1 "$PAL_REPO" "$PAL_DIR" || return 1
  fi
  [ -x "$PAL_DIR/.pal_venv/bin/python" ] || python3 -m venv "$PAL_DIR/.pal_venv"
  "$PAL_DIR/.pal_venv/bin/python" -m pip install -q -r "$PAL_DIR/requirements.txt"
  tmp="$(mktemp)"
  # PAL_TOOLBELT=1 turns on the agentic tool-loop; smart-router features
  # (self-heal, cache, classifier, refusal-memory, health-probe) default on in-code.
  jq --arg cmd "$PAL_DIR/.pal_venv/bin/python" --arg srv "$PAL_DIR/server.py" \
    '.mcpServers = (.mcpServers // {}) | .mcpServers.pal = {type:"stdio", command:$cmd, args:[$srv], env:{DEFAULT_MODEL:"auto", PAL_TOOLBELT:"1"}}' \
    "$HOME/.claude.json" > "$tmp" && mv "$tmp" "$HOME/.claude.json"
  ok "PAL registered (DEFAULT_MODEL=auto, toolbelt on)"
}
checkpoint pal_register "PAL MCP registration" register_pal

# ---------- 11. API key entry ----------
NEEDS_ENV=0
for f in "$M_GROQ" "$M_NEMO" "$M_GROK" "$M_FLSH" "$M_ORFR" "$M_PRO"; do
  [ "$f" = 1 ] && NEEDS_ENV=1
done

ENV_REAL=""; ENV_EXAMPLE=""
if [ "$NEEDS_ENV" = 1 ]; then
  ENV_EXAMPLE="$(dirname "$TARGET")/.env.lttbl.example"
  ENV_REAL="$(dirname "$TARGET")/.env.lttbl"
  cat > "$ENV_EXAMPLE" <<EOF
# let-there-be-light API keys - source before starting your orchestrator.
$( [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ] && echo "export GEMINI_API_KEY=your-gemini-key" )
$( [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ] && echo "export OPENROUTER_API_KEY=your-openrouter-key" )
$( [ "$M_GROQ" = 1 ] && printf '%s\n' "export CUSTOM_API_URL=https://api.groq.com/openai/v1" "export CUSTOM_API_KEY=your-groq-key" )
EOF
  ok "wrote env template: $ENV_EXAMPLE"
fi

collect_keys() {
  [ "$NEEDS_ENV" = 1 ] || return 0
  step "API keys"
  say "  Enter each key now (visible as asterisks) or press ENTER to skip."
  local GROQ_KEY="" OR_KEY="" GEMINI_KEY=""
  if [ "$M_GROQ" = 1 ]; then
    info "Groq  (report writing, validation) — https://console.groq.com/keys"
    masked_read GROQ_KEY "    Groq API Key: "
    GROQ_KEY=$(printf '%s' "$GROQ_KEY" | tr -d '[:space:]')
  fi
  if [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ]; then
    info "OpenRouter  (nemotron / grok / or-free) — https://openrouter.ai/settings/keys"
    masked_read OR_KEY "    OpenRouter API Key: "
    OR_KEY=$(printf '%s' "$OR_KEY" | tr -d '[:space:]')
  fi
  if [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ]; then
    info "Google Gemini  (flash / pro) — https://aistudio.google.com/apikey"
    masked_read GEMINI_KEY "    Gemini API Key: "
    GEMINI_KEY=$(printf '%s' "$GEMINI_KEY" | tr -d '[:space:]')
  fi
  local umask_prev; umask_prev=$(umask); umask 077
  {
    [ "$M_FLSH" = 1 ] || [ "$M_PRO" = 1 ] && printf 'export GEMINI_API_KEY=%s\n' "${GEMINI_KEY:-your-gemini-key}"
    [ "$M_NEMO" = 1 ] || [ "$M_GROK" = 1 ] || [ "$M_ORFR" = 1 ] && printf 'export OPENROUTER_API_KEY=%s\n' "${OR_KEY:-your-openrouter-key}"
    if [ "$M_GROQ" = 1 ]; then
      printf 'export CUSTOM_API_URL=https://api.groq.com/openai/v1\n'
      printf 'export CUSTOM_API_KEY=%s\n' "${GROQ_KEY:-your-groq-key}"
    fi
  } > "$ENV_REAL"
  chmod 600 "$ENV_REAL"
  umask "$umask_prev"
  ok "wrote $ENV_REAL (0600)"
}
checkpoint env_keys "API keys" collect_keys

# ---------- 12. next steps ----------
step "Next steps"
case "$ORCH" in
  c) cat <<EOF
  1. Source your API keys:  source $(dirname "$TARGET")/.env.lttbl
  2. Restart Claude Code.
  3. Session-start skills auto-load on the next session.
  4. Add more skills any time:  npx --yes github:crowx01/let-there-be-light add <skill>
                                (or  ./setup.sh add <skill>)
EOF
  ;;
  *) cat <<EOF
  1. Source your API keys:  source $(dirname "$TARGET")/.env.lttbl
  2. Open your project in your orchestrator.
  3. Add more skills any time:  npx --yes github:crowx01/let-there-be-light add <skill>
EOF
  ;;
esac
echo
ok "let-there-be-light setup complete."
info "checkpoint at $STATE_FILE (delete with:  ./setup.sh reset)"
