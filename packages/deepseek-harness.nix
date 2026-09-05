{
  buildNpmPackage,
  fetchzip,
  jq,
  lib,
  makeBinaryWrapper,
  nodejs_24,
  nodejs-slim_24,
  pnpm_11,
  stdenv,
  versionCheckHook,
}:
let
  runtimeNode = nodejs-slim_24;
  runtimePnpm = pnpm_11.override { nodejs-slim = runtimeNode; };
  landlockPackage =
    if stdenv.hostPlatform.isAarch64 then
      "node-addon-landlock-run-linux-arm64"
    else
      "node-addon-landlock-run-linux-x64";
in
buildNpmPackage (finalAttrs: {
  pname = "deepseek-harness";
  version = "0.1.0-rc.6";
  nodejs = nodejs_24;

  __structuredAttrs = true;
  src = fetchzip {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${finalAttrs.version}.tgz";
    hash = "sha256-caYhF/Q3wBGCs6nW80RCEzWPF5eS3vs5kw7dyGjlLdo=";
  };

  npmDepsHash = "sha256-5Bmk60aKr+x7MKXqbjXRdeo27J3i4iMz9w2jB5nyoYg=";

  nativeBuildInputs = [ makeBinaryWrapper ];
  postPatch = ''
    ${lib.getExe jq} 'del(.devDependencies)' package.json > package.json.new
    mv package.json.new package.json
    # The rc.6 npm tarball does not ship a lockfile.
    cp ${./deepseek-harness/package-lock.json} package-lock.json
  '';

  dontNpmBuild = true;
  dontPatchShebangs = true;

  postInstall = (
    lib.replaceStrings
      [
        "@buildNode@"
        "@runtimeNode@"
        "@pnpmPath@"
      ]
      [
        (lib.getExe nodejs_24)
        (lib.getExe runtimeNode)
        (lib.makeBinPath [ runtimePnpm ])
      ]
      (builtins.readFile ./scripts/deepseek-harness/post-install.sh)
  );

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  versionCheckProgramArg = "--version";

  postInstallCheck = (
    lib.replaceStrings
      [
        "@pnpmVersion@"
        "@runtimeNode@"
        "@shell@"
        "@landlockPackage@"
        "@nativeCheck@"
      ]
      [
        (lib.escapeShellArg runtimePnpm.version)
        (lib.getExe runtimeNode)
        stdenv.shell
        landlockPackage
        "${./scripts/deepseek-harness/check-native.cjs}"
      ]
      (builtins.readFile ./scripts/deepseek-harness/post-install-check.sh)
  );

  meta = {
    description = "Open-source agent harness developed by DeepSeek AI";
    homepage = "https://github.com/deepseek-ai/deepseek-harness";
    downloadPage = "https://www.npmjs.com/package/@deepseek-ai/dsh";
    license = lib.licenses.mit;
    mainProgram = "dsh";
    platforms = [
      "aarch64-linux"
      "x86_64-linux"
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryNativeCode
    ];
  };
})
