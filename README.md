# NixOS-WSL Configuration

用于 WSL2 的个人 NixOS 与 Home Manager 配置。

[English](README.en.md)

## 概览

| 项目 | 当前值 |
|---|---|
| Flake 输出 | <code>nixosConfigurations.wsl</code> |
| 架构 | <code>x86_64-linux</code> |
| 主机名 | <code>wsl</code> |
| 用户名 | <code>ben</code> |
| Nixpkgs | <code>nixos-unstable</code> |
| state version | <code>25.11</code> |
| 图形支持 | WSLg |

该分支只配置 WSL 用户空间。系统启动、Linux 内核、虚拟磁盘、网络接口和图形桥接均由 Windows 与 WSL 管理。

主要内容：

- NixOS-WSL 与 Home Manager。
- Zsh、Starship、fzf、zoxide、eza、bat 和常用开发工具。
- WSLg 下的 Wayland、X11、GTK、Qt/KDE 与 Electron 应用支持。
- Fcitx5 + Rime Ice 中文输入。
- Catppuccin、Papirus、Inter、Noto CJK/Emoji 与 Nerd Fonts。
- Hyprland 和 niri 配置文件保留，便于手动测试或复用，但 WSL 默认不启动嵌套桌面会话。

## 应用配置

~~~bash
git clone https://github.com/luobolong/nixos-config.git
cd nixos-config
git switch wsl
sudo nixos-rebuild switch --flake .#wsl
~~~

更新后重新应用：

~~~bash
git pull
sudo nixos-rebuild switch --flake .#wsl
~~~

只做配置检查：

~~~bash
nix flake check --no-build
nix build .#nixosConfigurations.wsl.config.system.build.toplevel --no-link
~~~

Git tree dirty 警告只表示仓库存在未提交修改，不会单独导致构建失败。提交或暂存新增的 Flake 源文件后再做最终验证，可确保 Nix 能读取它们。

## 首次使用前修改

<code>flake.nix</code> 中定义了主机名和用户名：

~~~nix
let
  system = "x86_64-linux";
  hostname = "wsl";
  username = "ben";
in
~~~

修改后，重建目标也要使用新的主机名。

<code>modules/wsl.nix</code> 中当前保存的是弱密码 <code>q</code> 对应的占位哈希，并且 <code>users.mutableUsers = false</code>。正式使用前应生成并替换密码哈希：

~~~bash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
~~~

同时检查 <code>home/default.nix</code> 中的 Git 姓名、邮箱、签名密钥和其他个人设置。

## WSLg 与显示

- WSLg 提供 Wayland/X11 连接，Linux 图形应用可直接从终端启动。
- WSL 配置会禁用 Hyprland、Noctalia 及其用户服务的自动启动。
- Hyprland 的通用显示器回退缩放为 <code>1</code>。
- niri 不声明固定输出名称、分辨率、位置或缩放，由 WSLg 决定显示输出。
- niri 的 <code>noctalia.kdl</code> 可写 include 会在 Home Manager 激活时创建。

## 目录结构

~~~text
.
├── flake.nix                         # WSL Flake 输入与 nixosConfigurations.wsl
├── flake.lock
├── hosts/wsl/default.nix             # NixOS-WSL 与 Home Manager 接线
├── modules/wsl.nix                   # WSL 系统用户空间配置
├── home/
│   ├── default.nix                   # 应用、主题、环境变量和用户服务
│   ├── wsl.nix                       # WSL 专用覆盖
│   ├── zsh.nix                       # Shell 配置
│   ├── hyprland.lua                  # Hyprland 配置
│   ├── niri.kdl                      # niri 配置
│   └── niri-smart-direction.sh
└── packages/
    ├── chatgpt.nix
    └── deepseek-harness.nix
~~~

## 桌面与开发环境

桌面应用包括 Firefox、Spotify、LocalSend、OBS Studio、Mission Center、Pavucontrol、AudioMonitor、ChatGPT、Dolphin、Okular、Gwenview、Ark、mpv 和 VS Code。

开发工具包括 GCC、CMake、Make、pkg-config、Node.js、Python、OpenJDK、Lua language server、nil、nixfmt、ShellCheck、Codex、DeepSeek Harness、sops、nh、nvd 和 nix-output-monitor。

默认程序：

- Kitty：终端
- Dolphin：目录
- Firefox：网页
- VS Code：文本
- Okular：PDF
- Gwenview：图片
- mpv：音视频
- Ark：压缩包

## 日常维护

~~~bash
# 更新锁文件
nix flake update

# 检查配置
nix flake check --no-build

# 应用配置
sudo nixos-rebuild switch --flake .#wsl

# 查看失败的用户服务
systemctl --user --failed
~~~

系统配置每周清理超过 7 天的旧 Nix store 代次并优化 store。WSL 数据备份建议使用 <code>wsl --export</code>，并另外备份未提交的配置、项目文件和凭据。

## 许可证

MIT
