#!/bin/sh
# install-stance.sh — install governed working vocabulary from meta/stance.

set -eu

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
if [ -z "$REPO_ROOT" ]; then
    echo "Error: not inside a git repository." >&2
    exit 1
fi
cd "$REPO_ROOT"

if [ "$(git symbolic-ref --short HEAD 2>/dev/null || true)" != "now" ]; then
    echo "Error: run install-stance from now." >&2
    exit 1
fi

META_STANCE_DIR="$REPO_ROOT/meta/stance"
VOCAB_FILE="$META_STANCE_DIR/vocabulary.toml"
STANCE_TEMPLATE="$META_STANCE_DIR/STANCE.md.template"
COMMAND_TEMPLATES_DIR="$META_STANCE_DIR/commands"
COMMAND_DIR="$REPO_ROOT/.claude/commands"
GENERATED_INDEX="$COMMAND_DIR/.stance-generated"

for required in "$VOCAB_FILE" "$STANCE_TEMPLATE" "$COMMAND_TEMPLATES_DIR"; do
    if [ ! -e "$required" ]; then
        echo "Error: missing required governed stance source: ${required#$REPO_ROOT/}" >&2
        echo "Recovery: run ./bootstrap.sh, verify meta worktree, and ensure init seeded meta/stance/." >&2
        exit 1
    fi
done

stance_title=""
stance_description=""
stance_floor=""
stance_claim=""
stance_experiment=""
stance_blocked=""
commands_show=""
commands_explore=""
commands_integrate=""
commands_finish=""
commands_change_rules=""
commands_save=""

trim() {
    printf '%s' "$1" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

set_value() {
    key=$1
    value=$2
    case "$key" in
        stance.title) stance_title=$value ;;
        stance.description) stance_description=$value ;;
        stance.floor) stance_floor=$value ;;
        stance.claim) stance_claim=$value ;;
        stance.experiment) stance_experiment=$value ;;
        stance.blocked) stance_blocked=$value ;;
        commands.show) commands_show=$value ;;
        commands.explore) commands_explore=$value ;;
        commands.integrate) commands_integrate=$value ;;
        commands.finish) commands_finish=$value ;;
        commands.change_rules) commands_change_rules=$value ;;
        commands.save) commands_save=$value ;;
    esac
}

get_value() {
    key=$1
    case "$key" in
        stance.title) printf '%s' "$stance_title" ;;
        stance.description) printf '%s' "$stance_description" ;;
        stance.floor) printf '%s' "$stance_floor" ;;
        stance.claim) printf '%s' "$stance_claim" ;;
        stance.experiment) printf '%s' "$stance_experiment" ;;
        stance.blocked) printf '%s' "$stance_blocked" ;;
        commands.show) printf '%s' "$commands_show" ;;
        commands.explore) printf '%s' "$commands_explore" ;;
        commands.integrate) printf '%s' "$commands_integrate" ;;
        commands.finish) printf '%s' "$commands_finish" ;;
        commands.change_rules) printf '%s' "$commands_change_rules" ;;
        commands.save) printf '%s' "$commands_save" ;;
        *) printf '' ;;
    esac
}

parse_toml() {
    section=""
    while IFS= read -r raw_line || [ -n "$raw_line" ]; do
        line=$(printf '%s\n' "$raw_line" | awk '
            BEGIN { in_string=0; escape=0; out="" }
            {
                for (i = 1; i <= length($0); i++) {
                    c = substr($0, i, 1)
                    if (escape) {
                        out = out c
                        escape = 0
                        continue
                    }
                    if (c == "\\") {
                        out = out c
                        if (in_string) {
                            escape = 1
                        }
                        continue
                    }
                    if (c == "\"") {
                        in_string = !in_string
                        out = out c
                        continue
                    }
                    if (c == "#" && !in_string) {
                        break
                    }
                    out = out c
                }
                gsub(/[[:space:]]+$/, "", out)
                print out
            }')
        line=$(trim "$line")
        [ -z "$line" ] && continue
        case "$line" in
            \[*\])
                section=$(printf '%s' "$line" | sed 's/^\[//; s/\]$//')
                continue
                ;;
        esac

        parsed=$(printf '%s\n' "$line" | awk '
            function trim(s) { sub(/^[[:space:]]+/, "", s); sub(/[[:space:]]+$/, "", s); return s }
            {
                pos = index($0, "=")
                if (pos == 0) { exit 1 }
                key = trim(substr($0, 1, pos - 1))
                val = trim(substr($0, pos + 1))
                printf "%s\t%s\n", key, val
            }') || continue
        key=$(printf '%s' "$parsed" | awk -F '\t' '{print $1}')
        rest=$(printf '%s' "$parsed" | awk -F '\t' '{print $2}')

        case "$rest" in
            \"*\")
                value=$(printf '%s' "$rest" | sed 's/^"//; s/"$//')
                value=$(printf '%s' "$value" | sed 's/\\\"/"/g; s/\\\\/\\/g')
                ;;
            *)
                continue
                ;;
        esac

        full_key=$key
        [ -n "$section" ] && full_key="$section.$key"
        set_value "$full_key" "$value"
    done < "$VOCAB_FILE"
}

render_template() {
    input=$1
    output=$2

    esc() {
        printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
    }

    e_stance_title=$(esc "$stance_title")
    e_stance_description=$(esc "$stance_description")
    e_stance_floor=$(esc "$stance_floor")
    e_stance_claim=$(esc "$stance_claim")
    e_stance_experiment=$(esc "$stance_experiment")
    e_stance_blocked=$(esc "$stance_blocked")
    e_commands_show=$(esc "$commands_show")
    e_commands_explore=$(esc "$commands_explore")
    e_commands_integrate=$(esc "$commands_integrate")
    e_commands_finish=$(esc "$commands_finish")
    e_commands_change_rules=$(esc "$commands_change_rules")
    e_commands_save=$(esc "$commands_save")

    sed \
        -e "s|{{stance.title}}|$e_stance_title|g" \
        -e "s|{{stance.description}}|$e_stance_description|g" \
        -e "s|{{stance.floor}}|$e_stance_floor|g" \
        -e "s|{{stance.claim}}|$e_stance_claim|g" \
        -e "s|{{stance.experiment}}|$e_stance_experiment|g" \
        -e "s|{{stance.blocked}}|$e_stance_blocked|g" \
        -e "s|{{commands.show}}|$e_commands_show|g" \
        -e "s|{{commands.explore}}|$e_commands_explore|g" \
        -e "s|{{commands.integrate}}|$e_commands_integrate|g" \
        -e "s|{{commands.finish}}|$e_commands_finish|g" \
        -e "s|{{commands.change_rules}}|$e_commands_change_rules|g" \
        -e "s|{{commands.save}}|$e_commands_save|g" \
        "$input" > "$output"
}

parse_toml

errors=""

# Required non-empty keys.
for key in \
    stance.title stance.description stance.floor stance.claim stance.experiment stance.blocked \
    commands.show commands.explore commands.integrate commands.finish commands.change_rules commands.save

do
    value=$(get_value "$key")
    if [ -z "$value" ]; then
        errors="${errors}${key}: must be non-empty\n"
    fi
done

# Noun rules.
for key in stance.floor stance.claim stance.experiment stance.blocked; do
    value=$(get_value "$key")
    if [ -n "$value" ] && ! printf '%s' "$value" | grep -Eq '^[A-Za-z0-9_-]+$'; then
        errors="${errors}${key}: must be a single word\n"
    fi
done

noun_values="$stance_floor $stance_claim $stance_experiment $stance_blocked"
for a in $noun_values; do
    [ -z "$a" ] && continue
    count=0
    for b in $noun_values; do
        [ "$a" = "$b" ] && count=$((count + 1))
    done
    if [ "$count" -gt 1 ]; then
        case "$a" in
            "$stance_floor") errors="${errors}stance.floor: must be distinct\n" ;;
            "$stance_claim") errors="${errors}stance.claim: must be distinct\n" ;;
            "$stance_experiment") errors="${errors}stance.experiment: must be distinct\n" ;;
            "$stance_blocked") errors="${errors}stance.blocked: must be distinct\n" ;;
        esac
    fi
done

# Command rules.
command_values="$commands_show $commands_explore $commands_integrate $commands_finish $commands_change_rules $commands_save"
for key in commands.show commands.explore commands.integrate commands.finish commands.change_rules commands.save; do
    value=$(get_value "$key")
    if [ -n "$value" ] && ! printf '%s' "$value" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
        errors="${errors}${key}: must match ^[a-z0-9][a-z0-9-]*$\n"
    fi
done
for a in $command_values; do
    [ -z "$a" ] && continue
    count=0
    for b in $command_values; do
        [ "$a" = "$b" ] && count=$((count + 1))
    done
    if [ "$count" -gt 1 ]; then
        case "$a" in
            "$commands_show") errors="${errors}commands.show: must be distinct\n" ;;
            "$commands_explore") errors="${errors}commands.explore: must be distinct\n" ;;
            "$commands_integrate") errors="${errors}commands.integrate: must be distinct\n" ;;
            "$commands_finish") errors="${errors}commands.finish: must be distinct\n" ;;
            "$commands_change_rules") errors="${errors}commands.change_rules: must be distinct\n" ;;
            "$commands_save") errors="${errors}commands.save: must be distinct\n" ;;
        esac
    fi
done

if [ -n "$commands_finish" ] && [ -n "$commands_save" ] && [ "$commands_finish" = "$commands_save" ]; then
    errors="${errors}commands.finish: must not equal commands.save\n"
    errors="${errors}commands.save: must not equal commands.finish\n"
fi

for noun_key in stance.floor stance.claim stance.experiment stance.blocked; do
    noun_value=$(get_value "$noun_key")
    [ -z "$noun_value" ] && continue
    for cmd_key in commands.show commands.explore commands.integrate commands.finish commands.change_rules commands.save; do
        cmd_value=$(get_value "$cmd_key")
        [ -z "$cmd_value" ] && continue
        if [ "$noun_value" = "$cmd_value" ]; then
            errors="${errors}${noun_key}: collides with ${cmd_key}\n"
            errors="${errors}${cmd_key}: collides with ${noun_key}\n"
        fi
    done
done

if [ -n "$errors" ]; then
    echo "Error: invalid meta/stance/vocabulary.toml. Fix these keys and rerun /install-stance:" >&2
    printf '%b' "$errors" | awk '!seen[$0]++' >&2
    exit 1
fi

meta_sha=$(sh .now/src/commit-to-meta.sh "Install stance vocabulary" "stance/vocabulary.toml")
echo "meta commit SHA: $meta_sha"
echo "meta gitlink target for now: $meta_sha"
echo "Recovery if now-side commit fails: resume from this point (do not rerun from scratch)."

render_template "$STANCE_TEMPLATE" "$REPO_ROOT/STANCE.md"

mkdir -p "$COMMAND_DIR"
if [ -f "$GENERATED_INDEX" ]; then
    invalid_generated_paths=""
    while IFS= read -r old_path; do
        [ -z "$old_path" ] && continue
        case "$old_path" in
            .claude/commands/*.md) ;;
            *) invalid_generated_paths="${invalid_generated_paths}${old_path}\n" ; continue ;;
        esac
        case "$old_path" in
            /*|*'..'*)
                invalid_generated_paths="${invalid_generated_paths}${old_path}\n"
                continue
                ;;
        esac
        rm -f "$REPO_ROOT/$old_path"
    done < "$GENERATED_INDEX"
    if [ -n "$invalid_generated_paths" ]; then
        echo "Error: .claude/commands/.stance-generated contains invalid path entries:" >&2
        printf '%b' "$invalid_generated_paths" >&2
        exit 1
    fi
    git add -u -- "$COMMAND_DIR"
fi

render_template "$COMMAND_TEMPLATES_DIR/show.md.template" "$COMMAND_DIR/$commands_show.md"
render_template "$COMMAND_TEMPLATES_DIR/explore.md.template" "$COMMAND_DIR/$commands_explore.md"
render_template "$COMMAND_TEMPLATES_DIR/integrate.md.template" "$COMMAND_DIR/$commands_integrate.md"
render_template "$COMMAND_TEMPLATES_DIR/finish.md.template" "$COMMAND_DIR/$commands_finish.md"
render_template "$COMMAND_TEMPLATES_DIR/change-rules.md.template" "$COMMAND_DIR/$commands_change_rules.md"
render_template "$COMMAND_TEMPLATES_DIR/save.md.template" "$COMMAND_DIR/$commands_save.md"

{
    echo ".claude/commands/$commands_show.md"
    echo ".claude/commands/$commands_explore.md"
    echo ".claude/commands/$commands_integrate.md"
    echo ".claude/commands/$commands_finish.md"
    echo ".claude/commands/$commands_change_rules.md"
    echo ".claude/commands/$commands_save.md"
} > "$GENERATED_INDEX"

MANAGED_BEGIN='<!-- stance:managed:begin -->'
MANAGED_BLOCK='<!-- stance:managed:begin -->
STANCE.md defines the working vocabulary and act-layer interpretation.
CLAUDE.md describes the enforcement substrate and truth precedence.
@STANCE.md
<!-- stance:managed:end -->'

CLAUDE_FILE="$REPO_ROOT/CLAUDE.md"
if [ ! -f "$CLAUDE_FILE" ]; then
    echo "Error: CLAUDE.md is required for stance installation." >&2
    exit 1
fi

TMP_CLAUDE=$(mktemp)
trap 'rm -f "$TMP_CLAUDE"' EXIT

if grep -q "$MANAGED_BEGIN" "$CLAUDE_FILE"; then
    awk -v block="$MANAGED_BLOCK" '
        BEGIN { inside=0; printed=0 }
        index($0, "<!-- stance:managed:begin -->") {
            if (!printed) {
                print block
                printed=1
            }
            inside=1
            next
        }
        index($0, "<!-- stance:managed:end -->") { inside=0; next }
        !inside { print }
    ' "$CLAUDE_FILE" > "$TMP_CLAUDE"
else
    if grep -q '^## Working vocabulary$' "$CLAUDE_FILE"; then
        awk -v block="$MANAGED_BLOCK" '
            { print }
            /^## Working vocabulary$/ {
                print ""
                print block
            }
        ' "$CLAUDE_FILE" > "$TMP_CLAUDE"
    else
        {
            cat "$CLAUDE_FILE"
            printf '\n## Working vocabulary\n\n%s\n' "$MANAGED_BLOCK"
        } > "$TMP_CLAUDE"
    fi
fi
mv "$TMP_CLAUDE" "$CLAUDE_FILE"

expected_tmp=$(mktemp)
trap 'rm -f "$TMP_CLAUDE" "$expected_tmp"' EXIT
{
    echo "install-stance.md"
    echo ".stance-generated"
    while IFS= read -r generated; do
        [ -z "$generated" ] && continue
        basename "$generated"
    done < "$GENERATED_INDEX"
} | sort -u > "$expected_tmp"

unexpected_md=""
unexpected_non_md=""
for file in "$COMMAND_DIR"/* "$COMMAND_DIR"/.*; do
    base=$(basename "$file")
    case "$base" in .|..) continue ;; esac
    [ -e "$file" ] || continue
    if ! grep -qx "$base" "$expected_tmp"; then
        case "$base" in
            *.md) unexpected_md="${unexpected_md}${base}\n" ;;
            *) unexpected_non_md="${unexpected_non_md}${base}\n" ;;
        esac
    fi
done

if [ -n "$unexpected_non_md" ]; then
    echo "Warning: unexpected non-markdown files in .claude/commands/:" >&2
    printf '%b' "$unexpected_non_md" >&2
fi

if [ -n "$unexpected_md" ]; then
    echo "Error: unexpected markdown files in .claude/commands/:" >&2
    printf '%b' "$unexpected_md" >&2
    echo "Remove or relocate unexpected markdown files, then rerun /install-stance." >&2
    exit 1
fi

git add -- STANCE.md CLAUDE.md "$GENERATED_INDEX"
while IFS= read -r generated; do
    [ -z "$generated" ] && continue
    git add -- "$generated"
done < "$GENERATED_INDEX"

if git diff --cached --quiet; then
    echo "No now-side changes to commit after restamping."
    exit 0
fi

before_now_head=$(git rev-parse HEAD)
if ! git commit --no-gpg-sign -m "Install stance layer"; then
    echo "Now commit failed before completion." >&2
    echo "meta SHA: $meta_sha" >&2
    echo "meta gitlink target: $meta_sha" >&2
    echo "Recovery: fix violation, stage generated files and meta gitlink on now, and recommit." >&2
    exit 1
fi

after_now_head=$(git rev-parse HEAD)
if [ "$after_now_head" = "$before_now_head" ]; then
    echo "Now commit was auto-reverted by immune response." >&2
    echo "meta SHA: $meta_sha" >&2
    echo "meta gitlink target: $meta_sha" >&2
    echo "Recovery: inspect immune-response output, restage generated files and meta gitlink on now, and recommit." >&2
    exit 1
fi

echo "Stance install complete."
echo "now commit: $after_now_head"
