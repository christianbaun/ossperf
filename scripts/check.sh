#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$repo_root"

# Include new shell scripts before staging them, too. Git's NUL-separated
# output keeps filenames containing whitespace intact.
mapfile -d '' -t shell_scripts < <(
  git ls-files --cached --others --exclude-standard -z -- '*.sh'
)
[[ ${#shell_scripts[@]} -gt 0 ]] || {
  printf 'ERROR: no shell scripts found\n' >&2
  exit 1
}

printf 'Checking Bash syntax (%s scripts)\n' "${#shell_scripts[@]}"
for script in "${shell_scripts[@]}"; do
  bash -n -- "$script"
done

printf 'Running ShellCheck\n'
shellcheck --norc -- "${shell_scripts[@]}"

printf 'Testing invalid arguments\n'
bash tests/invalid-arguments.sh
