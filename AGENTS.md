# Repository Guidelines

- Use English for codes, comments, and docs, even if I talk with you in Chinese

## Project Structure & Module Organization
- `src/bin/sandbox.sh` is the main entrypoint and contains all runtime logic.
- `src/share/sandbox-sh/` holds template config files used at runtime (for example, `template.sandbox.rc`).

## Build, Test, and Development Commands
- `./src/bin/sandbox.sh -h`: show CLI usage and supported flags.
- `./src/bin/sandbox.sh -V`: print the current version.
- `shellcheck src/bin/sandbox.sh`: static check

## Documentation Updates
- Keep `docs/sandbox.sh.1.adoc` in sync with CLI and configuration changes.
- When updating options or defaults, refresh man-pages, example templates, and config docs.

## Coding Style & Naming Conventions
- Shell only: this repository is Bash-based. Prefer POSIX-friendly constructs when practical.
- Indentation: 4 spaces for blocks, aligned case statements.
- Naming: uppercase for constants (e.g., `XDG_CONFIG_HOME`), lowercase for locals.
- Quote variables unless word-splitting is intended; use arrays for argument lists.
- Linting: run `shellcheck src/bin/sandbox.sh` before submitting changes.

## Testing Guidelines
- No automated test suite is currently provided.
- Before submitting changes, run a manual smoke check, for example:
  - `./src/bin/sandbox.sh -V`
  - `./src/bin/sandbox.sh -h`
  - `shellcheck src/bin/sandbox.sh`

## Commit
- Use Conventional Commits, e.g.:
  - `sandbox-sh: add new sandbox option ...`
  - `Makefile: fix bug ...`
  - `docs: update man-pages`