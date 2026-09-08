# shellcheck shell=bash
app="$out/lib/node_modules/@deepseek-ai/dsh"
rm -rf \
  "$app/node_modules/node-pty/deps" \
  "$app/node_modules/node-pty/node-addon-api" \
  "$app/node_modules/node-pty/prebuilds" \
  "$app/node_modules/node-pty/scripts" \
  "$app/node_modules/node-pty/src" \
  "$app/node_modules/node-pty/third_party" \
  "$app/node_modules/katex/src"

find "$app/node_modules/node-pty/build" -type f \
  ! -path '*/Release/pty.node' -delete
find "$app/node_modules/node-pty/build" -depth -type d -empty -delete
while IFS= read -r file; do
  substituteInPlace "$file" \
    --replace-warn @buildNode@ @runtimeNode@
done < <(find "$app" -type f -exec grep -IlF @buildNode@ {} +)

rm "$out/bin/dsh"
makeBinaryWrapper @runtimeNode@ "$out/bin/dsh" \
  --add-flags "--expose-internals" \
  --add-flags "$app/lib/bin.js" \
  --prefix PATH : @pnpmPath@
