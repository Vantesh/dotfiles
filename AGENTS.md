# Engineering notes

## Project structure

- Target fresh Arch-based installations. Keep the existing Arch-family detection, pacman/AUR integration, and CachyOS/Garuda support. Don't add compatibility for old dotfiles implementations or profile migrations.
- Both profiles get the common workstation setup: packages, non-secret dotfiles, Fish, shared services, WARP registration, fonts, themes, and desktop preferences.
- Keep credentials, private apps, hardware setup, Btrfs/Snapper, hibernation, boot configuration, Secure Boot, biometrics, and firewall rules personal-only. Nonpersonal setup must never access private credentials.
- Let each tool handle what it already does well. Chezmoi manages files, templates, profiles, and script execution. Mise manages packages, services, and tasks. Python coordinates provisioning.
- Keep Python entry scripts in `home/.chezmoiscripts/linux/` and reusable provisioning code in `home/.chezmoitemplates/lib/`. Entry scripts should make the execution order and privilege boundaries easy to follow. Don't put non-script files in `.chezmoiscripts`.
- Keep the initial prerequisite installer in shell since Python might not be installed yet. Install missing prerequisites in one pacman transaction. Use Bash elsewhere only when shell behavior is actually needed.

## Writing and maintaining code

- Keep solutions simple. Check the standard library, existing dependencies, and upstream documentation before writing custom code or adding packages. Avoid generic frameworks, speculative options, and unnecessary abstraction.
- Build on working behavior. When refactoring, keep the existing functionality working unless the change is intentional. Remove replaced code rather than keeping compatibility layers or parallel implementations.
- Make the main workflow readable from top to bottom. Use clear function names and extract code when it makes a real difference to readability, reuse, or correctness. Avoid wrappers that only forward calls.
- Use Python 3.14 and follow `ruff.toml` and `pyproject.toml`. Prefer straightforward control flow, `pathlib`, context managers, and useful type annotations. Avoid import-time side effects and mutable global provisioning state.
- Keep `/usr/bin/python3 -B` for provisioning. Imports must work from Chezmoi's temporary rendered scripts regardless of the current directory. Don't install the provisioning code as a package or change global `PYTHONPATH`.
- Prefer Chezmoi's built-in runtime values. Use `DOTFILES_` environment variables only for repository-specific settings, and never put secrets in shared environments. Resolve `CHEZMOI_SOURCE_DIR` at the entry point and pass required paths explicitly, including across sudo boundaries. Follow XDG defaults.
- Personal-only scripts must check `DOTFILES_PERSONAL_ENABLED` before doing any work: `"0"` skips, `"1"` proceeds, and missing or invalid values fail. Mixed scripts should still run their common work.
- Prefer plain Python scripts. Use `.tmpl` only when rendering is needed, such as tracking dependency changes. Keep rendered values on one line with `toJson`, and never mix Go template syntax into executable Python.
- Use Chezmoi's native script lifecycle. Prefer `run_onchange` for work triggered by managed changes; failed scripts must remain retryable. Remember that environment changes and pending files don't trigger `run_onchange` by themselves. Use `run_after` for work that genuinely needs to run on every apply.
- Use `subprocess.run()` with argument lists for ordinary commands. Preserve interactive authentication and useful progress output. Run operations sequentially unless concurrency solves a real problem, and use locks only where shared state requires them.

## Provisioning and safety

- Everything should be safe to reapply. Check the current state before changing it, skip work that's already complete, and leave unrelated or unmanaged configuration alone. Don't treat a failed check as proof that something is missing. inshort, IDEMPOTENCY IS NON NEGOTIABLE.
- Be careful with privileged changes. Check ownership and permissions, reject unsafe symlinks, and use atomic writes or rollback where partial changes could cause problems.
- Keep the existing safeguards around Btrfs, swapfiles, hibernation, Zswap, Limine, Secure Boot, and credentials. Verify boot artifacts and signatures before reporting success.
- Keep failure handling straightforward. A required command failure should stop provisioning with a useful error. Preserve its real exit status and diagnostics. Don't add retries, pending files, or custom recovery logic unless there's a demonstrated need.
- Catch exceptions when there's something useful to do: add context, clean up, recover, or report an error at the entry point. Avoid hiding unexpected failures.

## Logging

- Use the existing `configure_logging()` from `home/.chezmoitemplates/lib/provision_logging.py`. Keep terminal output concise and use the established format: `[YYYY-MM-DD HH:mm:ss] [LEVEL] Message`.
- Respect terminal color support and `NO_COLOR`. Keep detailed diagnostics in the private XDG log directory, including the source filename and line.
- Preserve log directory permissions (`0700`), file permissions (`0600`), rotation, retention, and unsafe-file checks. Keep `diagnose=False` and `backtrace=False`.
- Log meaningful work, warnings, and failures. Successful no-ops don't need announcements. Never log credentials, tokens, vault responses, sensitive arguments, or environments. Don't report success when logging has failed.

## Testing

- Keep tests minimal and focused on failures that would have serious consequences or are likely to regress. Prioritize boot configuration, Secure Boot, Btrfs, swap/hibernation, credential isolation, and privileged filesystem operations.
- A test should protect against a meaningful failure, not merely prove that code exists. Don't add tests automatically for every script, function, or configuration change. Simple integrations such as Atuin, themes, desktop preferences, package declarations, and routine service setup generally don't need dedicated behavioral tests.
- Add regression tests for bugs that are easy to reintroduce and difficult to catch through normal validation. Prefer a few meaningful tests over large suites of mocks, fixtures, and implementation details.
- Use pytest for behavioral tests. Keep fixtures small and avoid introducing testing frameworks or abstractions.
- Keep Ruff, Pyrefly, syntax checks, and Chezmoi/Mise configuration validation. These should catch ordinary mistakes without requiring extensive unit tests.
- Run `python3 -B .github/tests/validate.py` for relevant Python changes. Test privileged behavior in isolated environments, never against the development machine's live boot or filesystem configuration.
- Remove obsolete, redundant, and low-value tests when simplifying existing code. Don't preserve tests solely to maintain test counts or coverage.
- Report what was actually validated and any meaningful checks that couldn't run.

## Finishing a change

Briefly explain what changed, why it was necessary, and anything important about the resulting behavior. Include meaningful validation results and outstanding limitations. Don't create separate review documents unless requested.
