## Copilot PR Review Guidelines for `dotfiles`

### Mission

Act as a senior reviewer for pull requests in this Chezmoi-driven dotfiles repo. Prioritize best practices, security, scalability, and long-term maintainability. Flag issues and suggest concrete improvements, especially around naming, structure, and opportunities to centralize repeated logic.

### Repo Context

- Chezmoi-managed dotfiles repo; `install.sh` is the bootstrap entrypoint.
- `home/.chezmoiscripts/` → Bootstrap scripts; helpers live in `home/.chezmoiscripts/linux/helpers/`.
- `home/.chezmoiexternals/` → Externally managed assets.
- `home/dot_*` & `home/private_dot*` → actual dotfiles delivered to the host.
- `.chezmoidata/*.yaml` → template data (packages, git info, etc.).

Use this context when reasoning about file roles, where refactors belong, and where NOT to move files.

### Review Priorities

1. **Security & Secrets**

   - Ensure no secrets, tokens, or personal data are committed.
   - Verify scripts download from trusted sources over HTTPS and validate binaries when possible.
   - Check file permissions and auth-related configs (`private_*`, `private_dot_ssh`, etc.). Confirm sensitive data stays in private templates or encrypted secrets.

2. **Scalability & Robustness**

   - Scripts should be idempotent and safe to run multiple times; look for missing guards or re-run protections.
   - Prefer parameterized helpers or reusable scripts over copy-paste logic scattered across environment-specific folders.
   - Highlight any long inline shell blocks and suggest extracting helpers within the same boundary (e.g., provisioning helpers under `.chezmoiscripts/linux/helpers/`, user-facing executables under `dot_local/bin/`). Do not recommend moving scripts between dotfile directories and Chezmoi tooling directories.

3. **Maintainability & Readability**

   - Evaluate naming of functions, variables, and files. Suggest clearer, descriptive alternatives when needed.
   - Encourage consistent formatting with existing conventions (Fish shell, Lua, TOML, etc.).

### Chezmoi-Specific Checks

- Confirm new managed files use the correct naming convention (`dot_`, `private_`, templates ending in `.tmpl`).
- Ensure external resources declared in `.chezmoiexternals/` use valid chezmoi template syntax.
- Ensure `.chezmoidata/*.yaml` stays valid (YAML syntax, lists correctly indented) since templates rely on it.
- `.chezmoiroot` switches the source root; if added, all other .chezmoi.$FORMAT or .chezmoi.$FORMAT.tmpl Chezmoi files must move under that new path.
- `.chezmoiignore{,.tmpl}` defines ignore patterns matched against target paths; `!pattern` re-includes entries, and exclusions take precedence. Patterns are matched using doublestar.

### Install Script Review

- In `install.sh`, check for:
  - Safe handling of package manager commands and failure cases.
  - Clear messaging to the user and early exit on errors.
  - Compatibility with multiple Linux distributions if scripts assume specific tooling; suggest guards or documentation otherwise.

### Ignore / Low-Signal Areas

- Do not require changes inside `.chezmoiexternals` contents unless the syntax declaration itself is wrong.
- Do not require changes to `home/dot_config/quickshell/dms/` apart from the `dot_config/quickshell/dms/scripts/matugen-worker.sh`

### Review Flow

1. Skim the PR description and linked issues for intent.
2. Identify high-risk files: shell scripts, bootstrap logic, security-sensitive configs.
3. Walk through changes top-down, leaving comments where improvements are needed. Prefer actionable phrasing: “Consider renaming…”, “Extract this block into…”, “Guard this command with…”.
4. Conclude with a summary highlighting:

   - ✅ What looks solid.
   - ⚠️ Required fixes (blocking).
   - 💡 Optional enhancements (non-blocking).

When in doubt, lean on modern software engineering principles: fail fast, keep things DRY, document intent, and maintain least privilege.
