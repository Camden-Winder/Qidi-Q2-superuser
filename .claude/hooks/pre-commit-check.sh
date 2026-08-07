#!/usr/bin/env bash
# Pre-commit lint hook for Qidi Q2 Superuser AIO.
# Wired as a Claude Code hook in .claude/settings.json — runs on every commit.
# Also safe to run by hand: bash .claude/hooks/pre-commit-check.sh
# Exit non-zero to block the commit and print the reason.

set -uo pipefail

ERRORS=0
WARNINGS=()

# ------------------------------------------------------------------
# 1. Syntax-check all shell scripts that are staged
# ------------------------------------------------------------------
while IFS= read -r -d '' f; do
    if ! bash -n "$f" 2>/tmp/bash_n_err; then
        echo "ERROR: bash -n failed on $f:"
        cat /tmp/bash_n_err
        ERRORS=$((ERRORS + 1))
    fi
done < <(git diff --cached --name-only -z --diff-filter=ACMR | grep -z '\.sh$')

# ------------------------------------------------------------------
# 2. Validate all JSON files that are staged
# ------------------------------------------------------------------
while IFS= read -r -d '' f; do
    if ! python3 -m json.tool "$f" >/dev/null 2>/tmp/json_err; then
        echo "ERROR: invalid JSON in $f:"
        cat /tmp/json_err
        ERRORS=$((ERRORS + 1))
    fi
done < <(git diff --cached --name-only -z --diff-filter=ACMR | grep -z '\.json$')

# ------------------------------------------------------------------
# 3. Warn if aio_menu.sh changed but AIO_VERSION didn't bump
# ------------------------------------------------------------------
if git diff --cached --name-only | grep -q 'aio_menu\.sh'; then
    if ! git diff --cached Q2/aio_menu.sh | grep -q '^+AIO_VERSION='; then
        WARNINGS+=("aio_menu.sh changed but AIO_VERSION line not updated — consider bumping it")
    fi
fi

# ------------------------------------------------------------------
# 4. Warn if a new install_* function was added without uninstall_*
# ------------------------------------------------------------------
NEW_INSTALLS=()
while IFS= read -r line; do
    fn="${line#*install_}"
    fn="${fn%%(*}"
    NEW_INSTALLS+=("$fn")
done < <(git diff --cached --unified=0 -- '*.sh' | grep -E '^\+install_[a-z0-9_]*\(\)')

for fn in ${NEW_INSTALLS[@]+"${NEW_INSTALLS[@]}"}; do
    if ! git diff --cached --unified=0 -- '*.sh' | grep -q "^+uninstall_${fn}()"; then
        # Check if uninstall already exists in tree
        if ! grep -rq "^uninstall_${fn}()" --include='*.sh' . 2>/dev/null; then
            WARNINGS+=("New install_${fn}() added — make sure uninstall_${fn}() exists")
        fi
    fi
done

# ------------------------------------------------------------------
# Output
# ------------------------------------------------------------------
for w in ${WARNINGS[@]+"${WARNINGS[@]}"}; do
    echo "WARN: $w"
done

if [ "$ERRORS" -gt 0 ]; then
    echo ""
    echo "Pre-commit check failed with $ERRORS error(s). Fix them before committing."
    exit 1
fi

exit 0
