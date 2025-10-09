# Agent Guidelines

**Instructions for AI Agent**: When reviewing, refactoring, or writing bash scripts in this repository, strictly adhere to these guidelines. Prioritize idempotency, error handling, logging, security, modern bash best practices and maintainability.

---

## AI Agent Operational Guidelines

**Core Principles:**

- Reflect on tool results and plan optimal next steps before proceeding
- Invoke multiple independent operations simultaneously for efficiency
- Verify solutions before completion
- Do exactly what's requested—nothing more, nothing less

**File Management:**

- NEVER create files unless absolutely necessary
- ALWAYS prefer editing existing files over creating new ones
- NEVER proactively create documentation files (\*.md, README) unless explicitly requested

**Communication Style:**

- Skip flattery; respond directly without praising questions/ideas as "good" or "excellent"
- Critically evaluate theories and claims; point out flaws respectfully rather than agreeing by default
- Prioritize truthfulness and accuracy over agreeability
- No emojis unless requested or person uses them first
- No asterisk actions/emotes unless specifically requested
- Provide honest, constructive feedback rather than just agreeing
- Avoid unnecessary repetition; be concise and to the point

---

## Project Context

- **Repository Type**: Dotfiles managed by [chezmoi](https://www.chezmoi.io/)
- **Primary Language**: Bash and Python
- **Operating Systems**: Linux (Arch-based distros, Fedora)
- **Target**: Personal workstation setup
- **Purpose**: System configuration, dotfile management scripts, and automation tools

### Repository Structure

```text
chezmoi/
├── LICENSE
├── .github/
├── install.sh
├── .chezmoiroot
└── home/
    ├── .chezmoi.yaml.tmpl
    ├── .chezmoiignore.tmpl
    ├── .chezmoitemplates/
    ├── .chezmoiscripts/
    │   └── linux/
    │       ├── lib/                      # Shared libraries
    │       │   ├── .lib-common.sh
    │       │   ├── .lib-aur_helper.sh
    │       │   ├── .lib-chaotic_aur.sh
    │       │   ├── .lib-fedora_repos.sh
    │       │   ├── .lib-package_manager.sh
    │       │   └── .lib-*.sh
    │       ├── arch/                     # Arch-specific scripts
    │       │   ├── run_onchange_before_01_*.sh
    │       │   └── run_onchange_after_01_*.sh
    │       ├── fedora/                   # Fedora-specific scripts
    │       │   ├── run_onchange_before_01_*.sh
    │       │   └── run_onchange_after_01_*.sh
    │       ├── run_onchange_before_*.sh  # Cross-distro pre-setup
    │       └── run_onchange_after_*.sh   # Cross-distro post-setup
    ├── dot_config/
    ├── dot_local/
    ├── dot_ssh/
    └── dot_bashrc
```

**Execution Order:**

1. `run_onchange_before_*` - System setup before dotfiles (runs when script changes)
2. Dotfiles applied
3. `run_onchange_after_*` - Post-setup (runs when script changes)

**Script Execution Behavior:**

This repository uses `run_onchange_*` exclusively for setup scripts. Here's why:

- **`run_onchange_*`** (PREFERRED): Scripts execute whenever their content changes. Chezmoi maintains a hash of each script and re-runs it when the hash differs.

  - Enables iterative development - script improvements are automatically applied
  - Natural fit for idempotent scripts (all scripts in this repo are idempotent)
  - Maintains declarative approach - system state follows script content
  - Perfect for configuration management where changes should be applied

- **`run_once_*`** (AVAILABLE BUT NOT USED): Scripts execute only on first `chezmoi apply`.
  - Useful for one-time initialization tasks that should never repeat
  - Can be used for destructive operations that aren't idempotent
  - Requires manual state deletion to re-run
  - We don't use this because our scripts are designed to be idempotent

**Force re-execution of specific script:**

```bash
# Method 1: Modify script content (add/change comment)
# Method 2: Remove chezmoi state for that script
chezmoi state delete-bucket --bucket=scriptState # for run_once_ scripts
chezmoi state delete-bucket --bucket=entryState  # for run_onchange_ scripts
chezmoi apply

```

---

## Chezmoi Naming Convention Guidelines

### Handling Chezmoi Prefixes and Attributes

#### File Naming Recognition

When working with files in a chezmoi repository, the AI agent must:

**Strip chezmoi prefixes and attributes when referring to files in:**

- Comments and documentation
- Function names and descriptions
- Log messages and error reporting
- Script headers and inline references

#### Chezmoi Prefix Mapping

| Chezmoi Prefix/Attribute | Purpose                      | Example                               | Should Reference As     |
| ------------------------ | ---------------------------- | ------------------------------------- | ----------------------- |
| `dot_`                   | Creates dotfile (`.` prefix) | `dot_bashrc`                          | `.bashrc`               |
| `private_`               | Sets 0600 permissions        | `private_dot_ssh`                     | `.ssh`                  |
| `readonly_`              | Sets 0400 permissions        | `readonly_dot_netrc`                  | `.netrc`                |
| `empty_`                 | Creates empty file           | `empty_dot_gitkeep`                   | `.gitkeep`              |
| `executable_`            | Makes file executable        | `executable_install.sh`               | `install.sh`            |
| `run_once_`              | Run script once (not used)   | `run_once_setup.sh`                   | `setup.sh`              |
| `run_onchange_`          | Run on content change        | `run_onchange_config.sh`              | `config.sh`             |
| `run_onchange_before_`   | Run before applying          | `run_onchange_before_01_deps.sh`      | `01_deps.sh`            |
| `run_onchange_after_`    | Run after applying           | `run_onchange_after_08_wallpapers.sh` | `08_wallpapers.sh`      |
| `modify_`                | Modify existing file         | `modify_bashrc`                       | `bashrc` (modification) |
| `create_`                | Create file if missing       | `create_config.toml`                  | `config.toml`           |
| `symlink_`               | Create symlink               | `symlink_dot_config`                  | `.config` (symlink)     |

**Note:** When referring to files, always strip all prefixes and attributes to get the final intended path.

#### Practical Examples

**When writing script headers:**

```bash
#!/usr/bin/env bash
# 08_wallpapers.sh - Configure desktop wallpapers
# NOT: run_onchange_after_08_wallpapers.sh - Configure desktop wallpapers
```

**When creating function documentation:**

```bash
# setup_wallpapers configures the desktop wallpaper settings
# NOT: run_onchange_after_08_wallpapers configures the desktop wallpaper settings
```

#### Complex Prefix Combinations

For files with multiple prefixes, strip all chezmoi attributes:

| Full Chezmoi Name                            | Reference As              |
| -------------------------------------------- | ------------------------- |
| `private_readonly_dot_ssh/private_id_rsa`    | `.ssh/id_rsa`             |
| `executable_run_onchange_install.sh`         | `install.sh`              |
| `run_onchange_before_01_dot_config.sh.tmpl`  | `01_config.sh`            |
| `private_dot_config/private_app/secret.conf` | `.config/app/secret.conf` |

#### Template Files

- Strip `.tmpl` extension when referring to the final file
- Example: `dot_bashrc.tmpl` → `.bashrc`
- Only mention template nature when specifically discussing templating logic

#### Important Notes

1. **Preserve prefixes in actual file operations:** When creating, editing, or moving files, use the full chezmoi-prefixed name
2. **Strip prefixes in human-readable content:** Comments, documentation, logs, and descriptions should use clean names
3. **Maintain number prefixes:** Keep ordering numbers like `01_`, `02_` as they indicate execution order
4. **Be context-aware:** When explaining chezmoi functionality itself, it's appropriate to mention the prefixes

#### Code Review Example

**Incorrect:**

```bash
#!/usr/bin/env bash
# run_onchange_after_08_wallpapers.sh - Configure wallpapers after dotfiles are applied
#
# This script (run_onchange_after_08_wallpapers.sh) sets up desktop wallpapers
```

**Correct:**

```bash
#!/usr/bin/env bash
# 08_wallpapers.sh - Configure wallpapers after dotfiles are applied
#
# This script configures desktop wallpapers
```

---

## Distro Support

### Arch Linux (Primary Target)

- Package manager: `pacman` + AUR helper (paru/yay)
- Scripts: `home/.chezmoiscripts/linux/arch/`
- Key configs: Pacman parallel downloads, Color, VerbosePkgLists
- AUR helper auto-installed via `.lib-aur_helper.sh`
- Chaotic-AUR available via `.lib-chaotic_aur.sh`

### Fedora (Secondary Target)

- Package manager: `dnf`
- Scripts: `home/.chezmoiscripts/linux/fedora/`
- Use `.lib-fedora_repos.sh` for RPM Fusion and COPR repos

### Detecting Distribution

Chezmoi sets environment variables via `scriptEnv` in `.chezmoi.yaml.tmpl` for scripts to use:

```bash
# in bash scripts - use DISTRO_FAMILY environment variable
case "${DISTRO_FAMILY,,}" in
*arch*)
  # Arch-specific logic
  ;;
*fedora*)
  # Fedora-specific logic
  ;;
esac

# in chezmoi templates
{{- if contains .distroFamily "arch" -}}
# Arch-specific template logic
{{- else if contains .distroFamily "fedora" -}}
# Fedora-specific template logic
{{- end -}}
```

**Available scriptEnv variables:**

- `DISTRO_FAMILY` - Distribution family (arch, fedora)
- `PERSONAL` - Whether this is a personal installation ("1" or "0")
- `DEFAULT_SHELL` - Preferred shell (fish, zsh)
- `COMPOSITOR` - Preferred compositor (hyprland, niri)

**Note:** The `get_package_manager()` function in `.lib-package_manager.sh` requires `DISTRO_FAMILY` to be set via scriptEnv.

---

## Library Architecture

### Library Sourcing Rules

Libraries provide reusable functions but **do NOT source each other** to avoid circular dependencies.

**Sourcing Pattern:**

```bash
#!/usr/bin/env bash
# Script description

set -euo pipefail

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-package_manager.sh"
```

- Use `CHEZMOI_SOURCE_DIR` environment variable (set by chezmoi)
- Fallback to `$(chezmoi source-path)` if environment variable not set
- Source `.lib-common.sh` first (provides base utilities)
- Use `# shellcheck source=/dev/null` to disable path checking

**Dependency Rules:**

- `.lib-common.sh` sources nothing and enforces strict mode (base library)
- All other libraries source nothing and do NOT use `set -euo pipefail`
- Libraries are passive function definitions that rely on caller's environment
- Main scripts source whatever libraries they need and set their own strict mode

### Library Structure

**Libraries do NOT use `set -euo pipefail` or source other libraries.**

- `.lib-common.sh` is the only library that sets strict mode (enforces it for all sourcing scripts)
- All other libraries are passive function definitions only
- Main scripts are responsible for setting their own shell options

**Commenting Guidelines:**

- Comments describe what function does, arguments, and return codes
- NO inline comments within function bodies - code should be self-explanatory

```bash
#!/usr/bin/env bash
# .example.sh - Brief description
# Exit codes: 0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

readonly EXAMPLE_CONSTANT="value"

# public_function does something useful
# Arguments: $1 - argument description
# Returns: 0 on success, 1 on failure, 2 on invalid args
public_function() {
  local arg="${1:-}"

  LAST_ERROR=""

  if [[ -z "$arg" ]]; then
    LAST_ERROR="public_function() requires an argument"
    return 2
  fi

  if _already_done; then
    return 0
  fi

  if ! _do_something "$arg" >/dev/null 2>&1; then
    LAST_ERROR="Failed to do something: $arg"
    return 1
  fi

  return 0
}

_private_helper() {
  local value="$1"

  printf '%s\n' "$value"
}
```

**Exception: `.lib-common.sh` enforces strict mode**

```bash
#!/usr/bin/env bash
# .lib-common.sh - Common utilities and logging
# NOTE: Enforces strict mode (set -euo pipefail) for all sourcing scripts

set -euo pipefail

export LAST_ERROR="${LAST_ERROR:-}"

# log outputs formatted log messages to stderr
# Arguments: $1 - level (INFO|WARN|ERROR|SKIP|STEP), $@ - message
# Returns: 0 on success, 1 on invalid arguments
log() {
  # ... implementation
}
```

### Error State Management with `LAST_ERROR`

**CRITICAL: All library functions use `LAST_ERROR` for error reporting instead of logging.**

1. **Export `LAST_ERROR`**: Set on every error for caller to check
2. **Clear error state**: Each function starts with `LAST_ERROR=""`
3. **Silent operation**: Suppress output with `>/dev/null 2>&1` where appropriate
4. **Return codes**: See Exit Codes Reference below

**Exception:** `install_package()` in `.lib-package_manager.sh` logs `SKIP` messages for already-installed packages. This improves user experience during long installation scripts by providing real-time feedback.

**CRITICAL: `LAST_ERROR` Inspection Timing**

`LAST_ERROR` is ephemeral and will be overwritten by the next function that sets it. You MUST check it immediately after a function returns non-zero:

```bash
# CORRECT - Check LAST_ERROR immediately
if ! install_package "neovim"; then
  log ERROR "Failed to install neovim: $LAST_ERROR"
  exit 1
fi

# WRONG - LAST_ERROR may be overwritten by command_exists
if ! install_package "neovim"; then
  command_exists "vim"  # This may change LAST_ERROR!
  log ERROR "Failed to install neovim: $LAST_ERROR"  # Wrong error message
  exit 1
fi

# CORRECT - Capture LAST_ERROR before other operations
if ! install_package "neovim"; then
  local error_msg="$LAST_ERROR"
  # Now safe to call other functions
  command_exists "vim"
  log ERROR "Failed to install neovim: $error_msg"
  exit 1
fi
```

### Function Naming Conventions

All functions use action-oriented `verb_noun` naming to make behavior obvious at call sites:

```bash
# Good - Clear verb_noun pattern
command_exists "git"
install_package "neovim"
setup_rpmfusion
get_package_manager
enable_chaotic_aur
create_backup "/etc/file"

# Bad - Unclear or inconsistent
exists_command "git"      # Noun-verb order
neovim_install            # Noun-verb order
rpmfusion_setup           # Noun-verb order
package_manager           # Missing verb
```

**Verb Selection Guide:**

- `install_*` - Installs packages, dependencies, tools
- `setup_*` - Configures systems, repositories, environments
- `enable_*` - Activates features, services, options
- `create_*` - Creates files, directories, resources
- `get_*` - Retrieves values, detects state
- `check_*` / `*_exists` - Tests conditions, validates state
- `remove_*` / `delete_*` - Removes files, packages, config

#### Public Functions (no underscore)

These form the library and are intended for scripts that source the library.

```bash
# lib/.lib-package_manager.sh
install_package() {
  local package="$1"
  # Called by main scripts
}
```

Use public functions when:

- Function is part of the library's public interface
- Main scripts (or other libraries) should call it directly
- Signature and semantics should remain stable across refactors

#### Private / Helper Functions (underscore prefix)

Internal implementation details live alongside their public callers and stay private unless promoted.

```bash
# lib/.lib-aur_helper.sh
_validate_dependencies() {
  # Only called by install_aur_helper()
}

install_aur_helper() {
  _validate_dependencies || return 1
  _build_aur_package "$repo" "$pkg" "$dir"
}
```

Use private functions when:

- Only called by other functions in the same file
- Implementation details may change freely without breaking callers
- Omitted from the library header documentation
- Decomposing complex logic for readability

---

## Code Standards

### Strict Mode (Required)

```bash
#!/usr/bin/env bash
set -euo pipefail
```

**What each option does:**

- `set -e` (errexit): Exit immediately on error
- `set -u` (nounset): Exit on undefined variable usage (unsafe in Bash <4.4)
- `set -o pipefail`: Return failure if any command in pipe fails

### Safer Globbing

```bash
#!/usr/bin/env bash

# Enable safer globbing behavior
shopt -s nullglob globstar
```

**What these do:**

- `nullglob`: Makes `*.txt` expand to nothing (not the literal pattern) when no files match. Eliminates special-case bugs with zero matches.
- `globstar`: Enables `**` for recursive directory matching (safer than `find` in many cases)

**Why this matters:**

```bash
# Without nullglob - DANGEROUS
for file in *.txt; do
  # If no .txt files exist, this runs once with file="*.txt" (literal string)
  rm "$file"  # Tries to delete a file literally named "*.txt"
done

# With nullglob - SAFE
for file in *.txt; do
  # If no .txt files exist, loop body never executes
  rm "$file"
done
```

### The "Quote Everything" Principle

**Core rule: Quote all variable expansions. No exceptions in normal code.**

This is the single most important safety rule from shellharden. Being shellcheck/shellharden compliant means quoting everything.

```bash
# ALWAYS quote variables
var="value"
echo "$var"              # Not: echo $var
result="$var"            # Not: result=$var
cmd="$var1" "$var2"      # Not: cmd $var1 $var2

# ALWAYS quote command substitutions
output="$(command)"      # Not: output=$(command)
echo "$(date)"           # Not: echo $(date)

# Quote in all contexts
[[ "$x" = "$y" ]]        # Not: [[ $x = $y ]] (even though [[ ]] is safer)
for item in "$@"; do     # Not: for item in $@; do
  echo "$item"
done

# Quote array expansions
for item in "${array[@]}"; do    # Not: ${array[*]} or ${array[@]}
  echo "$item"
done
```

**Why quoting matters:**

Unquoted variables undergo word splitting (split on whitespace) and pathname expansion (glob wildcards). This means:

```bash
var="file with spaces.txt"
rm $var     # Tries to remove 3 files: "file", "with", "spaces.txt"
rm "$var"   # Correctly removes one file: "file with spaces.txt"

var="*.txt"
echo $var   # Lists all .txt files in current directory
echo "$var" # Prints literal "*.txt"
```

**Limited exceptions** (style only - quoting never hurts):

- Numeric special variables: `$?`, `$$`, `$!`, `$#`, `${#array[@]}`
- Assignments: `a=$b` (but `a="$b"` is also correct and more consistent)
- Inside `[[ ]]` (but quote anyway for consistency)

### Command Substitution Safety

**CRITICAL: Command substitutions in assignments lose their exit status.**

```bash
# WRONG - nproc failure is silently ignored
jobs="$(nproc)"
make -j"$jobs"

# CORRECT - separate declaration from assignment
local jobs
jobs="$(nproc)"          # Failure will exit script with set -e
make -j"$jobs"

# ALSO WRONG - local/export are commands, same problem
local jobs="$(nproc)"    # nproc failure is ignored!
export jobs="$(nproc)"   # nproc failure is ignored!

# CORRECT - separate declaration from assignment
local jobs
jobs="$(nproc)"
make -j"$jobs"
```

**Why this happens:**

The assignment itself succeeds (returns 0) even if the command substitution fails. With `set -e`, the script continues despite the failure.

**ShellCheck warns about this with `local`/`export`, but not plain assignments.**

### Safe Command Execution

**Use command arrays, not strings:**

```bash
# Good - real arrays
files=("file 1.txt" "file 2.txt")
rm -- "${files[@]}"

# Bad - space-delimited string (breaks on whitespace in filenames)
files="file1.txt file2.txt"
rm $files
```

**Use `--` to end option parsing:**

```bash
# Prevents files starting with '-' from being treated as options
rm -- "$file"
grep -- "$pattern" "$file"
```

**Check directory changes:**

```bash
# WRONG - if cd fails, subsequent commands run in wrong directory
cd /some/dir
rm important_file

# CORRECT - exit if cd fails
cd /some/dir || exit 1
rm important_file

# BETTER - use subshell to auto-restore directory
(
  cd /some/dir || exit 1
  rm important_file
)
# Automatically back to original directory
```

### Performance & Efficiency

- Prefer bash builtins over external commands (minimize subprocess spawning)
- Avoid unnecessary pipe chains and command substitutions
- Use efficient text processing: `awk`/`sed` over multiple `grep` calls
- Implement parallel processing for I/O-bound operations (`xargs -P`, GNU parallel)
- Cache expensive operations; reuse computed results

### Code Quality

- **Style Guide**: Follow Google Shell Style Guide, ShellCheck, and Shellharden recommendations
- **Naming**: Use `snake_case` for variables, `verb_noun` for functions
- **Quoting**: Always quote variables: `"$var"` (prevents word splitting and pathname expansion)
- **Conditionals**: Use `[[ ]]` instead of `[ ]` or `test` (but quote anyway for consistency)
- **Functions**: Single-purpose, well-named functions with `local` variables
- **Comments**: Only for non-obvious logic, complex regex
- **Wrapper hell**: Avoid unnecessary wrapper functions around single commands (e.g., don't create `run_git()` that just calls `git "$@"`)
- **Test command existence**: Use `command_exists()` from `.lib-common.sh`
- **Constants**: Declare in `ALL_CAPS` and mark `readonly`

### Idempotency

```bash
# Bad
rm /tmp/myfile

# Good
rm -f /tmp/myfile
mkdir -p "$output_dir"
```

- Check preconditions before destructive operations
- Use atomic operations: `mv` instead of `cp && rm`
- Make filesystem operations idempotent: `mkdir -p`, `rm -f`
- Safe to run multiple times without side effects

### Modularity & Configuration

- Extract reusable logic into `lib/*.sh` files
- Minimize global variables; use `readonly` for constants
- Keep main execution logic minimal (orchestration only)
- Externalize all configuration (environment variables, config files)
- Document required variables in script header
- Fail fast if required configuration is missing

---

## Error Handling

### Cleanup & Traps

```bash
trap cleanup EXIT ERR

cleanup() {
  rm -f "$temp_file"
  # Release locks, remove temp resources
}
```

- Always implement cleanup handlers
- Handle both normal exit and errors (`EXIT ERR`)
- Remove temporary files, release locks, restore state

### Errexit Gotchas

### Gotcha 1: Errexit ignored in command arguments

```bash
# WRONG - if nproc fails, make still runs with empty -j
set -e
make -j"$(nproc)"

# CORRECT - separate the command substitution
set -e
jobs="$(nproc)"
make -j"$jobs"
```

### Gotcha 2: Errexit ignored in tested contexts

If a function/subshell/group command is used as a condition, errexit is disabled inside it:

```bash
# All these print "Unreachable" despite set -e
(
  set -e
  false
  echo "Unreachable"
) && echo "Great success"

{
  set -e
  false
  echo "Unreachable"
} && echo "Great success"

f() {
  set -e
  false
  echo "Unreachable"
}
f && echo "Great success"
```

**Solution:** Split into standalone scripts or use explicit error handling.

### Error Reporting Patterns

**Main Scripts** - Use `log` function for user-facing output:

```bash
if ! some_function; then
  log ERROR "Operation failed: $LAST_ERROR"
  exit 1
fi
```

**Library Functions** - Set `LAST_ERROR`, suppress output, return codes:

```bash
function_name() {
  LAST_ERROR=""

  if ! some_operation; then
    LAST_ERROR="Descriptive error message"
    return 1
  fi

  return 0
}
```

---

## Logging

### Standard Format

The `log()` and `die()` functions are defined in `.lib-common.sh` with color support that respects `NO_COLOR` and terminal detection.

```bash
log() {
  local level="${1:-}"
  shift || true
  local message="$*"

  if [[ -z "$level" ]] || [[ -z "$message" ]]; then
    printf '[ERROR] log() requires a level and a message\n' >&2
    return 1
  fi

  local color="$COLOR_RESET"
  case "${level^^}" in
  INFO) color="$COLOR_GREEN" ;;
  WARN) color="$COLOR_YELLOW" ;;
  ERROR) color="$COLOR_RED" ;;
  SKIP) color="$COLOR_MAGENTA" ;;
  STEP)
    printf '\n%b::%b %s\n\n' "$COLOR_BLUE" "$COLOR_RESET" "$message" >&2
    return 0
    ;;
  *)
    printf '[ERROR] Invalid log level: %s\n' "$level" >&2
    return 1
    ;;
  esac

  printf '%b%s:%b %b\n' "$color" "${level^^}" "$COLOR_RESET" "$message" >&2
}

die() {
  local exit_code=1

  # Allow optional exit code as first argument
  if [[ "${1:-}" =~ ^[0-9]+$ ]]; then
    exit_code="$1"
    shift
  fi

  log ERROR "$@"
  exit "$exit_code"
}
```

### Usage Examples

```bash
# Basic logging (requires both level and message)
log INFO "Enabled Color"
log WARN "Option not found"
log ERROR "Configuration failed"

# STEP level for major workflow phases (adds visual spacing)
log STEP "Configuring Pacman"
log STEP "Installing packages"

# SKIP level for skipped operations
log SKIP "$package already installed"

# Error with exit
die "Configuration file not found"

# Custom exit code
die 2 "Invalid arguments"
die 127 "Command not found"

# With library functions - capture LAST_ERROR immediately
if ! install_package "neovim"; then
  local error_msg="$LAST_ERROR"
  log ERROR "Failed to install neovim: $error_msg"
  exit 1
fi

# Disable colors
NO_COLOR=1 ./script.sh
```

### Verbosity Guidelines

- **Use past tense, result first**: "Configured Pacman", "Enabled Color", "Created backup"
- **Log results, not intentions**: Show what was done, not what will be done
- **Be concise**: Avoid unnecessary details or explanations
- **Skip redundant intro messages**: Let the result speak for itself
- **Exception - Long-running operations**: Use present continuous (progressive) tense for operations that take significant time
  - "Cloning repository", "Regenerating initramfs", "Building package", "Installing Tela icons (this may take a moment)"
  - Follow with past tense result: "Cloned repository", "Regenerated initramfs"

```bash
# Bad (verbose, too much detail)
log INFO "About to create a backup of /etc/pacman.conf to /etc/pacman.conf.bak"
log INFO "Creating backup of /etc/pacman.conf"
log INFO "Backup created successfully: /etc/pacman.conf.bak"

# Good (concise, past tense, result first)
log INFO "Created backup: /etc/pacman.conf.bak"

# Good (long-running operation - present continuous then past tense)
log INFO "Cloning DankMaterialShell"
# ... git clone operation ...
log INFO "Cloned DankMaterialShell"

log INFO "Regenerating initramfs"
# ... mkinitcpio/dracut operation ...
log INFO "Regenerated initramfs"

# More examples of correct format
log INFO "Configured Pacman"
log INFO "Enabled Color"
log INFO "Installed neovim"
log STEP "Installing Packages"  # STEP level can be progressive (noun phrase)
```

### Output Guidelines

- **Stdout**: Program output only (parseable data, results)
- **Stderr**: All logs (INFO, WARN, ERROR, STEP, SKIP)
- **Use `printf`, not `echo`**: `echo` behavior varies across systems and has no way to end option parsing
- **No Timestamps**: Logs are consumed by systemd/supervisors that add timestamps
- **No DEBUG Level**: Keep logs clean; use verbose flags if needed
- **STEP Level**: Use for major workflow phases; adds visual spacing (blank lines)
- **SKIP Level**: Use for operations skipped because already done (e.g., package already installed)
- **Destructive Operations**: Log before execution
- **Sensitive Data**: Never log passwords, tokens, or API keys
- **Colors**: Respect `NO_COLOR` environment variable (accessibility standard)
- **Required Arguments**: Both level and message are mandatory; function returns 1 on error
- **Invalid Levels**: Return error instead of falling back to default
- **Signal Safety**: Colors reset on EXIT, ERR, INT, TERM signals

### Printf vs Echo

**Always use `printf` for output, never `echo`.**

```bash
# Bad - echo has portability issues and can't handle options correctly
echo "$var"
echo -n "$var"
echo -e "$var\n"

# Good - printf is always safe and portable
printf '%s\n' "$var"
printf '%s' "$var"
printf '%s\n' "$var"

# Multiple arguments
printf '%s %s\n' "$a" "$b"
printf '%s\n' "${array[@]}"
```

**Why `echo` is unsafe:**

- GNU `echo` interprets options (`-n`, `-e`) but has no `--` to end option parsing
- If `$var` starts with `-`, it will be treated as an option
- Behavior varies between systems (BSD vs GNU)
- `printf` has consistent behavior and format string protection

**Exception:** The `log()` function internally uses `printf`, so that's fine.

---

## Security

### Input Validation

```bash
# Always validate and sanitize
if [[ ! "$input" =~ ^[a-zA-Z0-9_-]+$ ]]; then
  LAST_ERROR="Invalid input format: $input"
  return 1
fi
```

### Safe Patterns

- **Variables**: Always quote: `"$var"`, `"${array[@]}"`
- **Temporary Files**: Use `mktemp`, never hardcode paths
- **Permissions**: Set explicit permissions with `chmod`, use `umask`
- **End option parsing**: Use `--` before filenames: `rm -- "$file"`
- **Avoid**: `eval`, unquoted expansions, predictable temp file names, `echo` for output
- **Process Substitution**: Prefer over temp files: `<(command)`

---

## Testing & Maintainability

### Testability

```bash
# Good: Testable function with return code
process_data() {
  local input="$1"
  LAST_ERROR=""

  if ! validate "$input"; then
    LAST_ERROR="Invalid data"
    return 1
  fi

  return 0
}

# Bad: Side effects, direct I/O
process_data() {
  cat /some/file | grep foo
}
```

- Separate logic from I/O operations
- Return exit codes, not echo values
- Minimize side effects and global state mutation

### Linting with ShellCheck and Shellharden

```bash
# Check with ShellCheck (static analysis)
shellcheck script.sh
shellcheck .chezmoiscripts/linux/**/*.sh

# Auto-fix quoting with Shellharden
shellharden --replace script.sh

# Check without modifying
shellharden --check script.sh

# Ignore specific ShellCheck warnings (use sparingly)
# shellcheck disable=SC2086
command "$unquoted_var"

# Check scripts with templates (after rendering)
chezmoi execute-template < script.sh.tmpl | shellcheck -
```

**Recommended workflow:**

1. Write script following these guidelines
2. Run `shellcheck` to catch errors
3. Run `shellharden --check` to verify quoting
4. Use `shellharden --replace` if needed (review changes!)

### Unit Testing with bats-core

```bash
# Install bats-core
# Arch: sudo pacman -S bats
# Fedora: sudo dnf install bats

# Example test file: test/common.bats
#!/usr/bin/env bats

setup() {
  load '../lib/.lib-common.sh'
}

@test "command_exists returns 0 for existing command" {
  run command_exists "bash"
  [ "$status" -eq 0 ]
}

@test "command_exists returns 1 for missing command" {
  run command_exists "nonexistent_command_xyz"
  [ "$status" -eq 1 ]
}

# Run tests
bats test/
```

### Script Documentation

```bash
#!/usr/bin/env bash
# script_name.sh - Brief description
#
# Detailed description of what the script does, its purpose, and any
# important notes about usage or dependencies.
#
# Globals:
#   VARIABLE_NAME - Description of global variable usage
#   LAST_ERROR - Error message from last failed operation (if used)
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
```

**Required Elements:**

- Shebang: `#!/usr/bin/env bash`
- Brief description in header comment (use simple name without chezmoi prefixes)
- Detailed description explaining purpose and usage
- Globals section documenting any global variables used
- Exit codes documented
- Strict mode: `set -euo pipefail`
- Safer globbing options: `shopt -s nullglob globstar`
- Source helpers with standard pattern

### Function Documentation

**All function header comments should describe the intended behaviour using:**

- **Description** - Brief summary of what the function does
- **Globals** (if applicable) - Global variables read or modified
- **Arguments** (if applicable) - Each argument with description
- **Outputs** (if applicable) - What is printed to stdout/stderr
- **Returns** - Exit codes and their meanings

**Example:**

```bash
# Merges kernel command line parameters.
#
# Combines current and new parameters, with new params overriding duplicates.
# Maintains parameter order. Intentionally uses word splitting on parameters.
#
# Arguments:
#   $1 - Current kernel command line (space-separated)
#   $2 - New parameters to add/override (space-separated)
# Globals:
#   LAST_ERROR - Set on invalid args
# Outputs:
#   Merged command line to stdout
# Returns:
#   0 on success, 2 on missing arguments
build_cmdline() {
  local current="${1:-}"
  local new_params="${2:-}"

  LAST_ERROR=""

  # Implementation...
}
```

**Guidelines:**

- Start with action verb in present tense (e.g., "Merges", "Checks", "Updates")
- Add detailed description paragraph if behavior is complex
- Document all globals that are read or modified
- List each argument with clear description
- Specify outputs (stdout/stderr) if function prints anything
- Always document return codes (0 for success, specific codes for errors)
- Mention important implementation details (e.g., "Prefers dracut-rebuild if available")
- Note dependencies on other functions/libraries if critical (e.g., "Requires .lib-common.sh sourced")
- No inline comments within function body - code should be self-explanatory

### Library Structure

**Libraries do NOT use `set -euo pipefail` or source other libraries.**

- Libraries are passive function definitions only
- Main scripts are responsible for setting their own shell options (`set -euo pipefail`, `shopt -s nullglob globstar`, etc.)
- Libraries source nothing and rely on the caller's environment

**Library File Header Format:**

```bash
#!/usr/bin/env bash
# .lib-example.sh - Brief description
#
# Detailed description of library purpose, what functionality it provides,
# and any important notes about usage patterns or dependencies.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   OTHER_GLOBAL - Description if library uses other globals
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"

readonly EXAMPLE_CONSTANT="value"
```

**Library files do NOT enforce strict mode:**

```bash
#!/usr/bin/env bash
# .lib-common.sh - Common utilities and logging
#
# Core utility library providing logging, confirmation prompts, and system utilities.
#
# Globals:
#   LAST_ERROR - Error message from last failed operation
#   COLOR_* - ANSI color codes (respect NO_COLOR environment variable)
# Exit codes:
#   0 (success), 1 (failure), 2 (invalid args), 127 (missing dependency)

export LAST_ERROR="${LAST_ERROR:-}"
```

---

## Common Patterns

### Main Script Structure

```bash
#!/usr/bin/env bash
# 01_pacman.sh - Configure pacman

set -euo pipefail

shopt -s nullglob globstar

readonly LIB_DIR="${CHEZMOI_SOURCE_DIR:-$(chezmoi source-path)}/.chezmoiscripts/linux/lib"

# shellcheck source=/dev/null
source "$LIB_DIR/.lib-common.sh"
# shellcheck source=/dev/null
source "$LIB_DIR/.lib-package_manager.sh"

main() {
  log STEP "Configuring Pacman"

  if ! setup_pacman; then
    die "Pacman setup failed: $LAST_ERROR"
  fi

  log INFO "Configured Pacman"
}

main "$@"
```

### Error Handling with LAST_ERROR

```bash
# Check command exists
if ! command_exists "git"; then
  if ! install_package "git"; then
    die "Failed to install git: $LAST_ERROR"
  fi
fi

# Multiple operations - capture LAST_ERROR immediately
if ! step_one; then
  local error_msg="$LAST_ERROR"
  log ERROR "Step one failed: $error_msg"
  exit 1
fi

if ! step_two; then
  local error_msg="$LAST_ERROR"
  log ERROR "Step two failed: $error_msg"
  exit 1
fi
```

### Iterating Over Command Output

**Use while loops with process substitution, not for loops:**

```bash
# Bad - word splitting and pathname expansion issues
for i in $(seq 1 10); do
  printf '%s\n' "$i"
done

# Good - process substitution avoids subshell for loop body
while read -r i; do
  printf '%s\n' "$i"
done < <(seq 1 10)

# Also acceptable - but loop body is a subshell (can't modify outer variables)
seq 1 10 | while read -r i; do
  printf '%s\n' "$i"
done
```

### Splitting Strings Safely

**When you must split a string on a separator:**

```bash
# Split $string on $sep into array
array=()
while read -rd "$sep" i; do
  array+=("$i")
done < <(printf '%s%s' "$string" "$sep")

# For NUL separator, hardcode it:
array=()
while read -rd '' i; do
  array+=("$i")
done < <(printf '%s\0' "$string")

# Bash 4+ alternative with readarray
readarray -td "$sep" array < <(printf '%s%s' "$string" "$sep")

# With NUL separator and find
readarray -td '' array < <(find . -print0)
```

**Note:** Appending the separator ensures proper handling of empty trailing fields.

### Conditions and Tests

**Prefer clear, standard test syntax:**

```bash
# String comparisons - use = not ==
if [[ "$s" = "yes" ]]; then
  echo "Yes"
fi

# Empty string checks - use -z/-n for readability and convention
if [[ -z "$s" ]]; then
  echo "Empty"
fi

if [[ -n "$s" ]]; then
  echo "Not empty"
fi

# File existence
if [[ -f "$file" ]]; then
  echo "File exists"
fi

# Combining conditions - use shell syntax, not test operators
if ! [[ -e "$f" ]] && { [[ "$s" = "yes" ]] || [[ "$s" = "y" ]]; }; then
  echo "Condition met"
fi

# Don't use -a/-o inside test (ambiguous with >4 arguments)
# Bad: test ! -e "$f" -a \( "$s" = yes -o "$s" = y \)
```

### Variable Existence Checks

**Only when absolutely necessary (prefer always setting variables):**

```bash
# Bash 4.2+ / Zsh 5.6.2+
if [[ -v var ]]; then
  echo "Variable exists"
fi

# POSIX alternative - use default values
echo "${var:-default}"      # Use default if unset
echo "${var-default}"       # Use default if unset (not if empty)

# If using -v, add feature check to fail early on old Bash:
[[ -v PWD ]] || {
  echo "Your bash is too old (need 4.2+)" >&2
  exit 1
}
```

---

## Development Workflows

### Testing Scripts Locally

```bash
# Source library for interactive testing
LIB_DIR="$HOME/.local/share/chezmoi/.chezmoiscripts/linux/lib"
source "$LIB_DIR/.lib-common.sh"

# Test individual functions
command_exists "git" && echo "Git found"
```

### Running Chezmoi Scripts

```bash
# Apply dotfiles without prompts (CI/testing)
NOCONFIRM=1 chezmoi apply --verbose

# Update existing installation
chezmoi update

# Test single script
chezmoi execute-template < script.sh.tmpl | bash
```

### Adding New Dependencies

Update `install.sh` packages array:

```bash
ensure_dependencies_installed() {
  local packages=(git chezmoi figlet NEW_PACKAGE)
  # ...
}
```

Or add to distro-specific package lists in `.chezmoiscripts/linux/{arch,fedora}/`

---

## Quick Reference

**When writing scripts:**

1. Use strict mode: `set -euo pipefail`
2. Enable safer globbing: `shopt -s nullglob globstar`
3. Source libraries using standard pattern with `CHEZMOI_SOURCE_DIR`
4. Use `verb_noun` naming for all functions
5. **Quote everything**: `"$var"`, `"$(cmd)"`, `"${array[@]}"`
6. Separate `local` declarations from command substitution assignments
7. Library functions: set `LAST_ERROR`, return codes, suppress output
8. Main scripts: use `log()` and `die()` for output
9. Capture `LAST_ERROR` immediately after failures
10. Use `printf`, never `echo`
11. Use arrays for lists, not space-delimited strings
12. Use `--` to end option parsing: `rm -- "$file"`
13. Make all operations idempotent
14. Document exit codes in header
15. Test with ShellCheck and Shellharden before committing

**Script locations:**

- Cross-distro: `home/.chezmoiscripts/linux/`
- Arch-specific: `home/.chezmoiscripts/linux/arch/`
- Fedora-specific: `home/.chezmoiscripts/linux/fedora/`
- Libraries: `home/.chezmoiscripts/linux/lib/`

**Common mistakes to avoid:**

- `echo "$var"` → Use `printf '%s\n' "$var"`
- `local var=$(cmd)` → Separate: `local var; var=$(cmd)`
- `for i in $(cmd)` → Use: `while read -r i; do ... done < <(cmd)`
- `cd dir; command` → Use: `cd dir || exit 1; command`
- `$var` → Always quote: `"$var"`

---

## Reference Resources

- [ShellCheck](https://www.shellcheck.net/) - Static analysis tool
- [Shellharden Safety Guide](https://github.com/anordal/shellharden/blob/master/how_to_do_things_safely_in_bash.md) - Comprehensive bash safety guide
- [Google Shell Style Guide](https://google.github.io/styleguide/shellguide.html)
- [BashPitfalls](http://mywiki.wooledge.org/BashPitfalls) - Common bash mistakes
- [Bash Hackers Wiki](https://wiki.bash-hackers.org/)
- [chezmoi Documentation](https://www.chezmoi.io/) - Dotfile manager
- [bats-core](https://github.com/bats-core/bats-core) - Bash unit testing framework
