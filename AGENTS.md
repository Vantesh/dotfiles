# Agent instructions

These instructions apply to the entire repository. Read [docs/architecture.md](docs/architecture.md) before changing project structure, Python, Mise configuration, tasks, or development tooling. Follow [docs/migration-plan.md](docs/migration-plan.md) for the Python/Mise migration sequence.

## Non-negotiable constraints

- Do not change the agreed architecture, scope, or migration order without asking.
- Do not invent requirements, broaden the task, or perform adjacent cleanup.
- Make the smallest change that completes the current step. State assumptions when they affect behavior; stop and ask when instructions conflict or a decision is unresolved.
- Preserve existing provisioning behavior, profile boundaries, privilege boundaries, safety checks, and idempotency unless a specific behavior change is requested.
- The current provisioning target remains Arch-family systems. Design reusable code with portability in mind, but do not add other OS support as part of this migration.
- Do not introduce hardcoded usernames, home paths, checkout paths, hardware identifiers, or machine-specific values unless they are truly invariant.
- Do not add speculative abstractions, generic frameworks, compatibility layers, duplicate implementations, or a second task runner/CLI.

## Architecture

- Chezmoi owns managed files, templates, profiles, and its apply lifecycle.
- Mise owns tool versions, packages, services, and task orchestration.
- uv owns the Python project environment and dependencies.
- Python implementation belongs in the installable \`src/dotfiles/\` package.
- Use \`mise/config.toml\`, \`mise/conf.d/\`, and native \`mise/tasks/\` discovery. Do not add a competing root \`mise.toml\` or redundant task includes.
- Use \`uv run\` for project Python commands. Do not hardcode virtual-environment executable paths, activate the environment manually, modify \`sys.path\`, or set a global \`PYTHONPATH\`.
- Mise manages Python, uv, Ruff, and BasedPyright versions. uv manages project dependencies. Keep one version owner per tool.
- Keep task and Chezmoi hook entrypoints thin. Put nontrivial reusable behavior in the Python package.
- Use Bash only for short shell-native operations and bootstrap steps that must run before Python is available.

## Engineering and validation

- Prefer standard-library functionality and existing tool capabilities before adding dependencies or custom code.
- Keep modules cohesive; avoid catch-all \`utils.py\`, \`helpers.py\`, and \`common.py\` modules.
- Keep provisioning idempotent and leave unrelated or unmanaged state alone.
- Use subprocess argument lists; avoid shell construction unless shell semantics are required.
- Avoid import-time side effects and mutable global provisioning state.
- Tests should protect plausible regressions and consequential behavior, not freeze incidental file inventories or implementation details. Do not add tests mechanically for every function.
- Validate each migration step before proceeding. Use isolated environments for privileged/destructive tests.
- Report the checks actually run and any limitations. Never claim an unrun check passed.

## Scope exclusions

Do not change packages, services, desktop behavior, networking, storage, boot, Secure Boot, credentials, firewall policy, or personal/nonpersonal profile behavior as part of the architecture migration. Do not add Windows, Fedora, macOS, or other OS provisioning support. Obtain explicit approval before crossing these boundaries.
