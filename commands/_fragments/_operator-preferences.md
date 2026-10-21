# Operator Preferences Fragment

**DO NOT INVOKE THIS FRAGMENT DIRECTLY.** Guidelines reference it where they would otherwise stop to ask the operator a question whose answer rarely changes.

## Purpose

Some questions get the same answer on every run: whether to sign commits, which full reactor build to run. Asking stops the run until the operator answers, and an answer that comes hours later makes the agent re-read, and after an hour re-cache, the whole conversation. An argument or the preferences file answers these questions in advance.

## Precedence

For each decision below, use the first that applies:

1. An argument of the current invocation (`sign=`, `build=`).
2. A project rule: if `project-guidelines.md` requires signed or signed-off commits, follow it whatever the preference says.
3. The operator's preferences file.
4. Ask the user, as the guideline says. Then offer once to save the answer (see below), so the next run does not ask.

An explicit instruction in the current conversation always wins.

## The Preferences File

`$OSS_HELPER_PREFS`, else `~/.config/oss-helper/preferences.md`. It sits next to `security-case.md`, the operator preferences of the security-case workflow, and like it belongs to the operator: it is never committed to a project. Read it with one command; when it does not exist, there are no preferences:

```bash
cat "${OSS_HELPER_PREFS:-$HOME/.config/oss-helper/preferences.md}" 2>/dev/null
```

It is Markdown. The guidelines read these entries and ignore every other line:

```markdown
# OSS Helper preferences

- **Commit signing:** -S -s
- **Reactor build:** skip-tests
```

| Entry | Values | Argument | Used by |
|---|---|---|---|
| **Commit signing** | `-S -s`, `-S`, `-s`, `none`, `ask` | `sign=Ss`, `sign=S`, `sign=s`, `sign=none` | Every guideline that commits |
| **Reactor build** | `skip-tests`, `full`, `ask` | `build=skip-tests`, `build=full` | `_fragments/_build-workflow.md` step 6, and the guidelines that run the full reactor build themselves |

`-S` is the GPG/SSH signature and `-s` the `Signed-off-by` trailer. `ask`, or a missing entry, means ask as before.

## Saving an Answer

When you had to ask, offer once:

> Save this as your default in `~/.config/oss-helper/preferences.md`?

On yes, create the directory if needed (`mkdir -p ~/.config/oss-helper`), then add the entry line or replace the existing one, keeping every other line of the file as it is.

## Version

1.0.0
