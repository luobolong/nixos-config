{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule (finalAttrs: {
  pname = "bili-danmaku-tui";
  version = "0.1.5";

  src = fetchFromGitHub {
    owner = "Youthdreamer";
    repo = "bili-danmaku-tui";
    tag = "v${finalAttrs.version}";
    hash = "sha256-0USxiwiuHm/6I5TVqnWzYsnXUAAvFFukRn2/BTRi5PE=";
  };
  vendorHash = "sha256-Oj1QqfJHZsIriym+Xq6GYAe3RahM8LtPhhFOMYQNlNw=";

  subPackages = [ "." ];
  ldflags = [
    "-s"
    "-w"
    "-X github.com/Youthdreamer/bili-danmaku-tui/cmd.Version=v${finalAttrs.version}"
    "-X github.com/Youthdreamer/bili-danmaku-tui/cmd.GitCommit=${finalAttrs.src.tag}"
  ];
  meta = {
    description = "Bilibili danmaku TUI client";
    homepage = "https://github.com/Youthdreamer/bili-danmaku-tui";
    license = lib.licenses.mit;
    mainProgram = "bili-danmaku-tui";
    platforms = lib.platforms.unix;
  };
})
