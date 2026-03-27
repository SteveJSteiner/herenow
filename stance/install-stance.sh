#!/bin/sh
# install-stance.sh — stamp the agent-facing vocabulary layer
#
# Usage: sh stance/install-stance.sh [vocabulary.toml]
#
# Reads a filled vocabulary.toml, validates constraints, stamps
# AGENT.md from the template, creates act-layer commands with
# vocabulary names, moves mechanism commands to substrate/, and
# prepares commits on meta and now.
#
# Run from repository root, on the now branch, after bootstrap.

set -e

VOCAB="${1:-stance/vocabulary.toml}"
TEMPLATE="stance/AGENT.md.template"
CMD_TEMPLATE_DIR="stance/commands"
CMD_DIR=".claude/commands"
SUBSTRATE_DIR="$CMD_DIR/substrate"

# --- preconditions ---

die() { echo "install-stance: $1" >&2; exit 1; }

test -f "$VOCAB" || die "vocabulary file not found: $VOCAB"
test -f "$TEMPLATE" || die "template not found: $TEMPLATE"
test -d "$CMD_TEMPLATE_DIR" || die "command templates not found: $CMD_TEMPLATE_DIR"

# --- read TOML values ---
# Simple flat-key reader. Handles [section] headers and key = "value" lines.

read_toml_value() {
  _section="$1"
  _key="$2"
  _file="$3"
  _in_section=0
  _value=""
  while IFS= read -r _line; do
    case "$_line" in
      "[$_section]") _in_section=1 ;;
      "["*"]") _in_section=0 ;;
      *)
        if [ "$_in_section" -eq 1 ]; then
          _k=$(echo "$_line" | sed -n 's/^'"$_key"'[[:space:]]*=[[:space:]]*"\(.*\)".*/\1/p')
          if [ -n "$_k" ]; then
            _value="$_k"
          fi
          # Also try unquoted value
          if [ -z "$_value" ]; then
            _k=$(echo "$_line" | sed -n 's/^'"$_key"'[[:space:]]*=[[:space:]]*\([^"#][^#]*\)/\1/p' | sed 's/[[:space:]]*$//')
            if [ -n "$_k" ]; then
              _value="$_k"
            fi
          fi
        fi
        ;;
    esac
  done < "$_file"
  echo "$_value"
}

echo "Reading vocabulary from $VOCAB..."

# Project
PROJECT_NAME=$(read_toml_value project name "$VOCAB")
PROJECT_DOMAIN=$(read_toml_value project domain "$VOCAB")

# Acts
ACT_SHOW=$(read_toml_value acts show "$VOCAB")
ACT_EXPLORE=$(read_toml_value acts explore "$VOCAB")
ACT_INTEGRATE=$(read_toml_value acts integrate "$VOCAB")
ACT_FINISH=$(read_toml_value acts finish "$VOCAB")
ACT_CHANGE_RULES=$(read_toml_value acts change_rules "$VOCAB")
ACT_SAVE=$(read_toml_value acts save "$VOCAB")

# Nouns
NOUN_FLOOR=$(read_toml_value nouns floor "$VOCAB")
NOUN_CLAIM=$(read_toml_value nouns claim "$VOCAB")
NOUN_EXPERIMENT=$(read_toml_value nouns experiment "$VOCAB")
NOUN_BLOCKED=$(read_toml_value nouns blocked "$VOCAB")

# Examples (optional)
EX_SHOW=$(read_toml_value examples show_example "$VOCAB")
EX_EXPLORE=$(read_toml_value examples explore_example "$VOCAB")
EX_INTEGRATE=$(read_toml_value examples integrate_example "$VOCAB")
EX_FINISH=$(read_toml_value examples finish_example "$VOCAB")
EX_CHANGE_RULES=$(read_toml_value examples change_rules_example "$VOCAB")
EX_SAVE=$(read_toml_value examples save_example "$VOCAB")

# --- validate ---

echo "Validating vocabulary..."

errors=""

check_nonempty() {
  _label="$1"; _val="$2"
  if [ -z "$_val" ]; then
    errors="${errors}  - $_label is empty\n"
  fi
}

check_word() {
  _label="$1"; _val="$2"
  if [ -n "$_val" ]; then
    if ! echo "$_val" | grep -qE '^[a-z][a-z0-9]*(-[a-z][a-z0-9]*)?$'; then
      errors="${errors}  - $_label: \"$_val\" must be a single lowercase word or hyphenated pair\n"
    fi
  fi
}

check_single_word() {
  _label="$1"; _val="$2"
  if [ -n "$_val" ]; then
    if ! echo "$_val" | grep -qE '^[a-z][a-z0-9]*$'; then
      errors="${errors}  - $_label: \"$_val\" must be a single lowercase word\n"
    fi
  fi
}

# Non-empty checks
check_nonempty "project.name" "$PROJECT_NAME"
check_nonempty "acts.show" "$ACT_SHOW"
check_nonempty "acts.explore" "$ACT_EXPLORE"
check_nonempty "acts.integrate" "$ACT_INTEGRATE"
check_nonempty "acts.finish" "$ACT_FINISH"
check_nonempty "acts.change_rules" "$ACT_CHANGE_RULES"
check_nonempty "acts.save" "$ACT_SAVE"
check_nonempty "nouns.floor" "$NOUN_FLOOR"
check_nonempty "nouns.claim" "$NOUN_CLAIM"
check_nonempty "nouns.experiment" "$NOUN_EXPERIMENT"
check_nonempty "nouns.blocked" "$NOUN_BLOCKED"

# Format checks: acts allow hyphenated pairs, nouns single word only
check_word "acts.show" "$ACT_SHOW"
check_word "acts.explore" "$ACT_EXPLORE"
check_word "acts.integrate" "$ACT_INTEGRATE"
check_word "acts.finish" "$ACT_FINISH"
check_word "acts.change_rules" "$ACT_CHANGE_RULES"
check_word "acts.save" "$ACT_SAVE"
check_single_word "nouns.floor" "$NOUN_FLOOR"
check_single_word "nouns.claim" "$NOUN_CLAIM"
check_single_word "nouns.experiment" "$NOUN_EXPERIMENT"
check_single_word "nouns.blocked" "$NOUN_BLOCKED"

# finish != save
if [ -n "$ACT_FINISH" ] && [ "$ACT_FINISH" = "$ACT_SAVE" ]; then
  errors="${errors}  - finish and save must not be the same word (both are \"$ACT_FINISH\")\n"
fi

# Collect all names for distinctness check
ALL_ACTS="$ACT_SHOW $ACT_EXPLORE $ACT_INTEGRATE $ACT_FINISH $ACT_CHANGE_RULES $ACT_SAVE"
ALL_NOUNS="$NOUN_FLOOR $NOUN_CLAIM $NOUN_EXPERIMENT $NOUN_BLOCKED"

# Act distinctness
check_distinct_acts() {
  _seen=""
  for _a in $ALL_ACTS; do
    for _s in $_seen; do
      if [ "$_a" = "$_s" ]; then
        errors="${errors}  - duplicate act name: \"$_a\"\n"
      fi
    done
    _seen="$_seen $_a"
  done
}

# Noun distinctness
check_distinct_nouns() {
  _seen=""
  for _n in $ALL_NOUNS; do
    for _s in $_seen; do
      if [ "$_n" = "$_s" ]; then
        errors="${errors}  - duplicate noun name: \"$_n\"\n"
      fi
    done
    _seen="$_seen $_n"
  done
}

# Cross-check: no noun reused as act, no act reused as noun
check_cross() {
  for _a in $ALL_ACTS; do
    for _n in $ALL_NOUNS; do
      if [ "$_a" = "$_n" ]; then
        errors="${errors}  - \"$_a\" used as both act and noun\n"
      fi
    done
  done
}

check_distinct_acts
check_distinct_nouns
check_cross

if [ -n "$errors" ]; then
  printf "Validation failed:\n%b" "$errors"
  exit 1
fi

echo "Vocabulary valid."

# --- stamp function ---

stamp_file() {
  _src="$1"
  _dst="$2"

  cp "$_src" "$_dst"

  # Simple slot substitution
  sed -i \
    -e "s|{{project.name}}|$PROJECT_NAME|g" \
    -e "s|{{project.domain}}|$PROJECT_DOMAIN|g" \
    -e "s|{{acts.show}}|$ACT_SHOW|g" \
    -e "s|{{acts.explore}}|$ACT_EXPLORE|g" \
    -e "s|{{acts.integrate}}|$ACT_INTEGRATE|g" \
    -e "s|{{acts.finish}}|$ACT_FINISH|g" \
    -e "s|{{acts.change_rules}}|$ACT_CHANGE_RULES|g" \
    -e "s|{{acts.save}}|$ACT_SAVE|g" \
    -e "s|{{nouns.floor}}|$NOUN_FLOOR|g" \
    -e "s|{{nouns.claim}}|$NOUN_CLAIM|g" \
    -e "s|{{nouns.experiment}}|$NOUN_EXPERIMENT|g" \
    -e "s|{{nouns.blocked}}|$NOUN_BLOCKED|g" \
    "$_dst"

  # Handle conditional sections: {{#key}}...{{/key}}
  # Include section only if value is non-empty; remove otherwise.
  _handle_conditional() {
    _ckey="$1"; _cval="$2"; _cfile="$3"
    if [ -z "$_cval" ]; then
      # Remove the conditional block (lines from {{#key}} to {{/key}} inclusive)
      sed -i "/{{#${_ckey}}}/,/{{\\/${_ckey}}}/d" "$_cfile"
    else
      # Keep content, remove markers, substitute value
      sed -i \
        -e "/{{#${_ckey}}}/d" \
        -e "/{{\\/${_ckey}}}/d" \
        -e "s|{{${_ckey}}}|${_cval}|g" \
        "$_cfile"
    fi
  }

  _handle_conditional "examples.show_example" "$EX_SHOW" "$_dst"
  _handle_conditional "examples.explore_example" "$EX_EXPLORE" "$_dst"
  _handle_conditional "examples.integrate_example" "$EX_INTEGRATE" "$_dst"
  _handle_conditional "examples.finish_example" "$EX_FINISH" "$_dst"
  _handle_conditional "examples.change_rules_example" "$EX_CHANGE_RULES" "$_dst"
  _handle_conditional "examples.save_example" "$EX_SAVE" "$_dst"
}

# --- stamp AGENT.md ---

echo "Stamping AGENT.md..."
stamp_file "$TEMPLATE" "AGENT.md"
echo "  wrote AGENT.md"

# --- namespace mechanism commands ---

echo "Namespacing mechanism commands to substrate/..."
mkdir -p "$SUBSTRATE_DIR"

MECHANISM_COMMANDS="membrane-status init-bootstrap-first-commit now-commit modify-enforcement-source create-past create-future advance-past graduate-future"

for cmd in $MECHANISM_COMMANDS; do
  if [ -f "$CMD_DIR/$cmd.md" ]; then
    mv "$CMD_DIR/$cmd.md" "$SUBSTRATE_DIR/$cmd.md"
    echo "  moved $cmd.md -> substrate/$cmd.md"
  fi
done

# --- stamp act-layer commands ---

echo "Stamping act-layer commands..."

stamp_act_command() {
  _structural="$1"
  _vocab="$2"
  _tmpl="$CMD_TEMPLATE_DIR/$_structural.md.template"
  _out="$CMD_DIR/$_vocab.md"

  if [ ! -f "$_tmpl" ]; then
    echo "  warning: template not found: $_tmpl" >&2
    return
  fi

  stamp_file "$_tmpl" "$_out"
  echo "  stamped $CMD_DIR/$_vocab.md (from $_structural)"
}

stamp_act_command "show" "$ACT_SHOW"
stamp_act_command "explore" "$ACT_EXPLORE"
stamp_act_command "integrate" "$ACT_INTEGRATE"
stamp_act_command "finish" "$ACT_FINISH"
stamp_act_command "change-rules" "$ACT_CHANGE_RULES"
stamp_act_command "save" "$ACT_SAVE"

# --- update README ---

echo "Updating .claude/commands/README.md..."

cat > "$CMD_DIR/README.md" << READMEEOF
# Claude Code Commands — \`$PROJECT_NAME\`

This directory is the durable command layer for operators using Claude Code in this repo.

## Register (mandatory)

- Write to an intelligent operator who is new to this repo.
- Be exact about mechanism, not abstract about intent.
- Keep the author present when useful.
- Mark real difficulty plainly, without apology.
- Use examples to illuminate mechanism, not decorate it.
- If two phrasings are equally precise, choose the one that teaches mechanism rather than the one that sounds like compliance boilerplate.
- If membrane vocabulary appears, bind it to files/scripts/checkers immediately.
- Commands must teach mechanism while remaining executable as checklists.

## Act-layer commands

These are the agent's working language. Use these during normal operation.

- [\`/$ACT_SHOW\`](./$ACT_SHOW.md) — inspect where things stand
- [\`/$ACT_EXPLORE\`](./$ACT_EXPLORE.md) — open or continue speculative work
- [\`/$ACT_INTEGRATE\`](./$ACT_INTEGRATE.md) — pull exploration onto the working surface
- [\`/$ACT_FINISH\`](./$ACT_FINISH.md) — make finished work load-bearing
- [\`/$ACT_CHANGE_RULES\`](./$ACT_CHANGE_RULES.md) — modify enforcement apparatus
- [\`/$ACT_SAVE\`](./$ACT_SAVE.md) — governed commit on now

## Substrate commands

These are the enforcement mechanism's own commands. They surface on failure
or when diagnosis requires reaching through the act layer.

- [\`/substrate/membrane-status\`](./substrate/membrane-status.md)
- [\`/substrate/init-bootstrap-first-commit\`](./substrate/init-bootstrap-first-commit.md)
- [\`/substrate/now-commit\`](./substrate/now-commit.md)
- [\`/substrate/modify-enforcement-source\`](./substrate/modify-enforcement-source.md)
- [\`/substrate/create-past\`](./substrate/create-past.md)
- [\`/substrate/create-future\`](./substrate/create-future.md)
- [\`/substrate/advance-past\`](./substrate/advance-past.md)
- [\`/substrate/graduate-future\`](./substrate/graduate-future.md)

## Shared command skeleton (mandatory)

Every write command must include these sections, by name:

1. **When this command applies**
2. **Truth sources**
3. **Preconditions**
4. **Steps**
5. **Verification**
6. **Failure protocol**
7. **Evidence to report**

If a claim cannot be tied to source, checker output, or runnable command sequence, remove or verify it.
READMEEOF

echo "  wrote $CMD_DIR/README.md"

# --- summary ---

echo ""
echo "=== install-stance complete ==="
echo ""
echo "Stamped artifacts:"
echo "  AGENT.md (repository root)"
echo "  .claude/commands/$ACT_SHOW.md"
echo "  .claude/commands/$ACT_EXPLORE.md"
echo "  .claude/commands/$ACT_INTEGRATE.md"
echo "  .claude/commands/$ACT_FINISH.md"
echo "  .claude/commands/$ACT_CHANGE_RULES.md"
echo "  .claude/commands/$ACT_SAVE.md"
echo "  .claude/commands/README.md"
echo ""
echo "Mechanism commands moved to .claude/commands/substrate/"
echo ""
echo "Remaining steps:"
echo "  1. Commit vocabulary.toml to meta branch"
echo "  2. Commit AGENT.md + command changes to now"
echo ""
echo "To commit vocabulary to meta:"
echo "  git stash  # if needed"
echo "  git checkout meta"
echo "  cp <path-to-filled-vocabulary.toml> vocabulary.toml"
echo "  git add vocabulary.toml && git commit -m 'Add vocabulary manifest'"
echo "  git checkout now"
echo "  git stash pop  # if needed"
echo "  # then stage meta gitlink update and commit on now"
