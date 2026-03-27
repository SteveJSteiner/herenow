# install-stance

Install the agent-facing vocabulary for a herenow repository.

## When it runs

After `init.sh` and `bootstrap.sh` have completed. The enforcement
substrate is already in place. This pass adds the agent's native
language on top of it.

Can also be re-run to update vocabulary. Since the vocabulary manifest
lives on meta, updating it is a rule change and goes through the
change-rules flow once the stance is installed.

## What it does

1. **Present the vocabulary manifest.**
   Show `vocabulary.toml` with structural descriptions visible.
   The operator fills in project-native words for each slot.
2. **Validate the manifest.**

   Required:
   - Every act and noun field must be non-empty.
   - Act names must be single words or hyphenated pairs
     (they become command names).
   - Noun names must be single words
     (they appear in status output columns).

   Distinctness:
   - All six act names must be distinct from each other.
   - All four noun names must be distinct from each other.
   - No noun may be reused as an act name.
   - No act may be reused as a noun name.

   Structural:
   - `finish` and `save` must not be the same word.
     (They route to different layers: `finish` touches the
     floor line, `save` commits on the working surface.
     Collapsing them collapses intent routing.)

   If validation fails, report which constraint was violated
   and ask the operator to revise.
3. **Stamp AGENT.md.**
   Substitute `{{slot.path}}` references in `AGENT.md.template`
   with values from the filled manifest. Conditional sections
   (`{{#path}}...{{/path}}`) are included only if the value is
   non-empty. Write the result to `AGENT.md` at the repository root.
4. **Stamp act-layer commands.**
   For each act, substitute template variables in the corresponding
   `stance/commands/<structural-name>.md.template` and write the
   result to `.claude/commands/<vocabulary-name>.md`. The filename
   is the slotted vocabulary word, not the structural name.
5. **Namespace mechanism commands.**
   Move existing mechanism commands from `.claude/commands/` into
   `.claude/commands/substrate/`. Update `.claude/commands/README.md`
   to reflect the two-tier layout.
6. **Commit the manifest to meta.**
   The filled `vocabulary.toml` is committed on the meta branch.
   This makes vocabulary a governed artifact — changing it later
   requires the enforcement-consistency flow.
7. **Commit AGENT.md and commands to now.**
   The stamped file and restructured commands are committed on now
   as a governed commit.

## What it does not do

- It does not create the enforcement hooks (init.sh did that).
- It does not modify any checker or helper script.
- It does not generate the act-to-command implementation layer.
  The act names become the front-end. The existing slash commands
  or shell helpers become the back-end. The mapping between them
  is documented in the stamped AGENT.md but executed by whatever
  command layer the operator builds.

## Implementation options

The stamping can be:

- **A shell script** (`install-stance.sh`) that reads TOML, does
  string substitution, and commits. Minimal dependency: sed or awk
  against the known slot syntax.
- **An agent-assisted pass** where the operator tells the agent
  "install the stance for this project" and the agent walks through
  the manifest interactively, then stamps and commits. This is the
  more natural path for a Claude Code workflow.
- **A manual pass** where the operator fills vocabulary.toml by hand,
  copies the template, does find-replace, and commits.

The template repository should ship all three paths.

## Vocabulary design guidance

Good act names:

- Sound like things you would say out loud: "I'm going to spike
  this" not "I'm going to create-future-branch this."
- Are short: one word or a hyphenated pair.
- Are domain-native: a game project says "ship", a research project
  says "confirm", an infrastructure project says "promote."
- Do not repeat the substrate: don't name the finish act "make-past."
  The position is the mechanism, not the vocabulary.

Good noun names:

- Are the answer to "what kind of thing is this?"
- Should feel natural in a sentence: "the {{floor}} is stable"
  or "I have three {{experiments}} open."

The only hard constraint: the vocabulary must be unambiguous within
the project. Two acts cannot route to the same operation, and the
nouns must partition cleanly into four categories.

## File placement

In the scaffold (before install):

```
stance/
  vocabulary.toml          # manifest (ships empty)
  AGENT.md.template        # constitution (ships with slots)
  install-stance.sh        # shell stamper (optional)
  INSTALL-STANCE.md        # this file
  commands/                # act-layer command templates
    show.md.template
    explore.md.template
    integrate.md.template
    finish.md.template
    change-rules.md.template
    save.md.template
```

After install, the target repo has:

```
AGENT.md                            # stamped, on now — the agent reads this
meta: vocabulary.toml               # filled, on meta — governs future changes
.claude/commands/
  <show-word>.md                    # act-layer (vocabulary names)
  <explore-word>.md
  <integrate-word>.md
  <finish-word>.md
  <change-rules-word>.md
  <save-word>.md
  substrate/                        # mechanism layer (fixed names)
    membrane-status.md
    init-bootstrap-first-commit.md
    now-commit.md
    modify-enforcement-source.md
    create-past.md
    create-future.md
    advance-past.md
    graduate-future.md
```

The `stance/` directory is template machinery on the scaffold.
It does not appear on `now` after init.
