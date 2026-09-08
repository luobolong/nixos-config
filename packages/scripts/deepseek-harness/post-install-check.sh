# shellcheck shell=bash
app="$out/lib/node_modules/@deepseek-ai/dsh"

"$out/bin/dsh" --help > /dev/null
DSH_HOME="$(mktemp -d)" \
  "$out/bin/dsh" --profile headless --dump-default-config > /dev/null
DSH_HOME="$(mktemp -d)" \
  "$out/bin/dsh" plugin --profile install-check --version \
  | grep -Fx @pnpmVersion@
webLog="$(mktemp)"
DSH_HOME="$(mktemp -d)" \
  "$out/bin/dsh" web --host 127.0.0.1 --port 0 > "$webLog" 2>&1 &
webPid=$!

cleanupWeb() {
  kill "$webPid" 2> /dev/null || true
  wait "$webPid" 2> /dev/null || true
}

trap cleanupWeb EXIT
for _ in {1..100}; do
  if ! kill -0 "$webPid" 2> /dev/null; then
    cat "$webLog" >&2
    exit 1
  fi
  webUrl="$(sed -n 's/^dsh web: //p' "$webLog")"
  if [ -n "$webUrl" ]; then
    break
  fi
  sleep 0.1
done
test -n "${webUrl:-}"
WEB_URL="$webUrl" @runtimeNode@ <<'NODE'
const response = await fetch(process.env.WEB_URL);
if (!response.ok || !(await response.text()).includes("<html")) process.exit(1);
NODE
cleanupWeb
trap - EXIT

APP="$app" TEST_SHELL="@shell@" @runtimeNode@ @nativeCheck@

landlock="$app/node_modules/@deepseek-ai/@landlockPackage@/bin/landlock-run"
test -x "$landlock"
"$landlock" --probe | grep -Eq '^landlock: (fully|partially) enforced$'
if find "$app" -xtype l -print -quit | grep -q .; then
  find "$app" -xtype l -print >&2
  exit 1
fi

if grep -RIlE '/build/(source|tmp\.|\.home)' "$out"; then
  exit 1
fi
