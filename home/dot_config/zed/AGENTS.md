# AGENTS.md

## Commit messages

Use the Conventional Commits format:

```
<type>(<scope>): <description>
```

### Types

`feat`, `fix`, `refactor`, `perf`, `style`, `docs`, `test`, `build`, `ci`, `chore`, `revert`

### Scope

- Optional but preferred.
- Use the area changed, e.g. `hypr`, `fish`, `zsh`, `nvim`, `kitty`, `chezmoi`, `scripts`, `packages`.
- Ignore chezmoi naming prefixes and suffixes (`dot_`, `private_`, `executable_`, `run_`, `onchange_`, `once_`, `before_`, `after_`, numeric ordering like `01_`, and `.tmpl`). Use only the short, meaningful name.
  - `run_onchange_before_01_snapper.sh.tmpl` → scope `snapper`
  - `dot_config/hypr/hyprland.conf` → scope `hypr`
  - `dot_zshrc.tmpl` → scope `zsh`

### Subject line

- Imperative mood ("add", not "added" or "adds").
- Lowercase, no trailing period.
- Maximum 72 characters.
- Describe what changed and why, not how. Avoid vague messages like "update files" or "fix stuff".
- Never include chezmoi prefixes or long script names in the subject.

### Body

- Only for non-trivial changes.
- Separate from the subject with a blank line and wrap at 72 characters.
- Explain motivation or side effects, not the diff itself.

### Rules

- One type per commit. If the diff mixes unrelated changes, pick the dominant type and don't list everything.
- Mark breaking changes with `!` after the type/scope (e.g. `feat(chezmoi)!: ...`) and add a `BREAKING CHANGE:` footer.
- Don't mention file names unless needed for clarity, and when you do, use the short name without chezmoi prefixes.
- Never include secrets, tokens, or personal data in a commit message.
- When asked to write a commit message, output only the message: no explanation, quotes, or code fences.

### Examples

```
feat(chezmoi): gate rbw secrets behind personal flag

Skip secret fetching on machines where personal is false so public
clones apply cleanly without Bitwarden credentials.
```

```
fix(snapper): skip setup when hibernation is disabled
```
