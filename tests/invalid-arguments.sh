#!/bin/bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
program=${1:-$repo_root/ossperf.sh}
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir -p "$test_dir/bin" "$test_dir/home" "$test_dir/config" "$test_dir/work"
calls="$test_dir/storage-calls"
: > "$calls"

# Only these real local utilities are reachable in the child process.
for tool in bash head md5sum mkdir rm dd date sed find awk mv rmdir; do
  ln -s "$(command -v "$tool")" "$test_dir/bin/$tool"
done

# Storage clients never access configuration or a service. Version queries
# succeed; every other invocation is recorded and also succeeds, so missing
# dependencies or authentication cannot make the negative test pass.
cat > "$test_dir/bin/storage-double" <<'DOUBLE'
#!/bin/bash
if [[ ${1:-} == --version ]]; then
  printf 'test client 1.0\n'
else
  printf '%s' "${0##*/}" >> "$STORAGE_CALLS"
  printf ' %q' "$@" >> "$STORAGE_CALLS"
  printf '\n' >> "$STORAGE_CALLS"
fi
DOUBLE
chmod +x "$test_dir/bin/storage-double"
for tool in s3cmd s4cmd mc aws swift az gsutil; do
  ln -s storage-double "$test_dir/bin/$tool"
done

# Avoid any network probe or delay, even when testing the unfixed program.
cat > "$test_dir/bin/local-double" <<'DOUBLE'
#!/bin/bash
printf '0\n'
DOUBLE
chmod +x "$test_dir/bin/local-double"
for tool in bc ping sleep tput parallel; do
  ln -s local-double "$test_dir/bin/$tool"
done

# Verify the recorder independently before using it to assert no operations.
env -i STORAGE_CALLS="$calls" "$test_dir/bin/s3cmd" --version >/dev/null
[[ ! -s "$calls" ]]
env -i STORAGE_CALLS="$calls" "$test_dir/bin/s3cmd" ls >/dev/null
grep -qx 's3cmd ls' "$calls"
: > "$calls"

status=0
(
  cd -- "$test_dir/work"
  timeout 10s env -i PATH="$test_dir/bin" HOME="$test_dir/home" \
    XDG_CONFIG_HOME="$test_dir/config" LC_ALL=C TERM=dumb \
    STORAGE_CALLS="$calls" \
    "$test_dir/bin/bash" --noprofile --norc "$program" -n not-a-number -s 4096
) > "$test_dir/output" 2>&1 || status=$?

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  cat "$test_dir/output" >&2
  cat "$calls" >&2
  exit 1
}

[[ $status -ne 0 && $status -ne 124 && $status -ne 137 ]] ||
  fail "invalid -n must fail without a timeout (status $status)"
grep -Eq '\[ERROR\].*number of files.*(-n).*positive integer' "$test_dir/output" ||
  fail 'missing understandable argument error'
[[ ! -s "$calls" ]] || fail 'storage operations were started'
[[ ! -e "$test_dir/work/testfiles" ]] || fail 'benchmark preparation was started'
printf 'PASS: invalid -n is rejected before storage operations\n'
