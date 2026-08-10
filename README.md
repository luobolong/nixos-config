# NixOS Hyprland 工作站

一套可以直接放到 GitHub 管理的 NixOS 配置。它使用 Flakes、Home Manager、Disko、Btrfs 和 Impermanence，提供 Hyprland + Noctalia v5 桌面、雾凇拼音和常用桌面/开发软件。

> [!WARNING]
> 安装命令会**清空目标磁盘的全部数据**。执行 Disko 前，务必备份数据并反复确认磁盘的 `/dev/disk/by-id/...` 路径。不要使用容易变化的 `/dev/sda` 或 `/dev/nvme0n1`。

## 包含内容

- NixOS unstable + Flakes
- Home Manager
- Disko + GPT + UEFI
- Btrfs：`/nix` 和 `/persist` 使用 Zstd 压缩
- Impermanence：`/` 是 tmpfs，每次启动自动清空；必要状态保存在 `/persist`
- Snapper：自动创建 `/persist` 快照并按小时、天、周、月清理
- systemd-boot + Lanzaboote UKI，支持 UEFI Secure Boot，最多保留 10 个系统代次
- 每周自动清理 7 天前的 Nix 代次，并优化 Nix Store
- Hyprland（UWSM 会话）+ Noctalia v5
- greetd + tuigreet 登录界面
- Kitty（Hyprland 模糊背景）+ Zsh + Starship 提示符
- NetworkManager、蓝牙、PipeWire
- Fcitx5 + Rime + rime-ice（雾凇拼音）+ Catppuccin Mocha Sapphire 皮肤
- Dolphin、Fastfetch、Mission Center、btop、Fuzzel、Hyprlock、Neovim + AstroNvim v5、VS Code、Spotify、FlClash
- GnuPG + GPG Agent、SSH Agent、direnv + nix-direnv
- jq、yq、rsync、Zip/7-Zip、常用硬件诊断、NixOS 维护与基础构建工具

## 目录结构

```text
.
├── flake.nix
├── hosts/nixos/
│   ├── default.nix
│   ├── disk-config.nix
│   └── hardware-configuration.nix
├── modules/
│   ├── core.nix
│   ├── desktop.nix
│   └── impermanence.nix
├── home/default.nix
└── packages/flclash.nix
```

## 安装前修改

### 1. 修改主机名和用户名

编辑 `flake.nix`：

```nix
hostname = "nixos";
username = "ben";
```

如果修改了主机名，也要把目录 `hosts/nixos` 改成相同名称，并同步修改 `flake.nix` 中的：

```nix
./hosts/nixos
```

### 2. CPU 与显卡

默认硬件配置适用于 AMD CPU，并启用了 AMD 微码更新、AMDGPU 早期 KMS，以及由 `hardware.graphics` 提供的 Mesa OpenGL/Vulkan 驱动：

```nix
boot.kernelModules = [ "kvm-amd" ];
hardware.cpu.amd.updateMicrocode = lib.mkDefault true;
hardware.graphics.enable = true;
hardware.graphics.enable32Bit = true;
```

如果改用 Intel CPU，需将 KVM 模块和微码选项改为 Intel 对应配置。NVIDIA 显卡通常还需要额外的专有驱动配置；本仓库默认面向 AMD 显卡。

### 3. 调整根目录和 Swap 大小

默认临时根目录最多使用 8 GiB 内存，Swap 分区与本机 64 GiB 内存等大，并作为休眠恢复设备。可分别在 `hosts/nixos/disk-config.nix` 中修改：

```nix
options = [ "defaults" "mode=755" "size=8G" ];
size = "64G";
```

若机器内存容量不同，请将 Swap 的 `size` 改为不小于实际内存的值。休眠 Swap 未启用随机加密，因为随机密钥会在重启后丢失，导致无法恢复休眠镜像。

## 全新安装

以下步骤以官方 NixOS Minimal ISO、UEFI 启动和有线网络为例。

### 1. 启动安装介质并联网

连接 Wi-Fi 时可使用：

```bash
sudo systemctl start NetworkManager
nmtui
```

确认当前是 UEFI 模式：

```bash
test -d /sys/firmware/efi && echo UEFI || echo "不是 UEFI，请重新启动安装介质"
```

### 2. 下载配置

把地址替换成你上传后的 GitHub 仓库：

```bash
git clone https://github.com/YOUR_NAME/YOUR_REPO.git
cd YOUR_REPO
```

如果还没有上传，可以在安装环境中先创建并编辑这套文件；执行 Flake 命令前，记得运行 `git add .`，因为 Nix Flake 不会读取 Git 仓库中未跟踪的文件。

### 3. 找到稳定的磁盘路径

```bash
ls -l /dev/disk/by-id/
lsblk -o NAME,SIZE,MODEL,SERIAL,FSTYPE,MOUNTPOINTS
```

选择代表**整块磁盘**且不带 `-partN` 后缀的路径，例如：

```text
/dev/disk/by-id/nvme-Samsung_SSD_990_PRO_2TB_XXXXXXXX
```

编辑 `hosts/nixos/disk-config.nix`，把：

```nix
/dev/disk/by-id/CHANGE_ME
```

替换成刚确认的路径。再次用 `readlink -f` 检查它指向哪块磁盘：

```bash
readlink -f /dev/disk/by-id/你的磁盘名称
```

### 4. 生成锁文件并检查配置

```bash
nix --extra-experimental-features "nix-command flakes" flake lock
nix --extra-experimental-features "nix-command flakes" flake check --no-build
```

提交生成的 `flake.lock`，以后每次安装都会使用相同的依赖版本。Noctalia v5 当前仍在 Beta，锁文件尤其重要。

### 5. 分区、格式化和挂载

最后一次确认磁盘路径。下一条 Disko 命令会不可恢复地清空该磁盘：

```bash
grep -n "device" hosts/nixos/disk-config.nix
```

为临时根目录创建挂载点，然后执行 Disko：

```bash
sudo mkdir -p /mnt
sudo mount -t tmpfs -o size=8G,mode=755 none /mnt
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --root-mountpoint /mnt \
  ./hosts/nixos/disk-config.nix
```

确认结果中 `/mnt/nix`、`/mnt/persist` 和 `/mnt/boot` 都已挂载：

```bash
findmnt -R /mnt
```

### 6. 安装 NixOS

默认主机名为 `nixos`：

```bash
sudo nixos-install --flake .#nixos --no-root-passwd
```

如果你修改了 `hostname`，把 `#nixos` 换成新名称。

安装完成后，为用户设置密码（把 `ben` 换成你的用户名）：

```bash
sudo nixos-enter --root /mnt -c 'passwd ben'
```

然后重启：

```bash
sudo reboot
```

拔掉安装 U 盘，systemd-boot 应显示 NixOS 启动项。首次登录在 tuigreet 中选择 Hyprland。此时先保持固件 Secure Boot 关闭，首次启动的 UKI 尚未签名。

## 首次登录

### UKI 与 Secure Boot

Lanzaboote 会为每个 NixOS 系统代次生成 UKI。首次启动时，`generate-sb-keys.service` 会在持久化的 `/var/lib/sbctl` 中生成 Secure Boot 密钥：

```bash
systemctl status generate-sb-keys.service
sudo sbctl status
```

确认密钥已经生成后，再重建一次，使 Lanzaboote 使用新密钥签名 systemd-boot 和 UKI：

```bash
sudo nixos-rebuild boot --flake .#nixos
sudo sbctl verify
```

确认启动文件已经签名后，进入 UEFI 固件设置并切换到 Secure Boot Setup Mode。不要选择会同时清空 `dbx` 的“清除全部 Secure Boot 密钥”；不同主板通常可以通过删除 Platform Key（PK）进入 Setup Mode。

回到 NixOS 后手动注册密钥，并保留 Microsoft 签名证书以兼容显卡 Option ROM 和部分固件更新：

```bash
sudo sbctl enroll-keys --microsoft
sudo reboot
```

最后在固件中启用 Secure Boot，并验证状态：

```bash
bootctl status
sudo sbctl status
```

Secure Boot 只验证启动链完整性；本配置按要求不启用磁盘加密，因此不会阻止他人从其他系统直接读取磁盘数据。不要提交 `/var/lib/sbctl` 中的私钥。

### Fcitx5 + 雾凇拼音

配置已把英文键盘和 Rime 加入默认输入法组。使用 `Ctrl+Space` 切换输入法；按 `F4` 可以在 Rime 中选择雾凇拼音方案。

如果首次登录没有出现候选窗：

```bash
fcitx5 -r
```

然后打开 `fcitx5-configtool`，确认 Input Method 中存在 `Rime`。

### AstroNvim

首次运行会下载 AstroNvim 插件：

```bash
nvim
```

插件、状态和缓存中的重要部分位于持久目录，重启不会丢失。AstroNvim 模板本身由 Flake 输入管理。

### Noctalia

Noctalia 作为用户服务随 Hyprland 启动。它的图形设置保存在 `~/.config/noctalia`，该目录已持久化。检查服务：

```bash
systemctl --user status noctalia
```

### FlClash

FlClash 使用官方 x86_64 AppImage 发行包封装，版本和 SHA-256 已在 `packages/flclash.nix` 中固定。配置目录 `~/.local/share/com.follow.clash` 已持久化。

## 日常维护

应用当前配置：

```bash
sudo nixos-rebuild switch --flake .#nixos
```

更新所有 Flake 输入并应用：

```bash
nix flake update
nix flake check --no-build
sudo nixos-rebuild switch --flake .#nixos
```

检查每周自动清理计划：

```bash
systemctl list-timers | grep nix-gc
```

手动清理 7 天前的代次：

```bash
sudo nix-collect-garbage --delete-older-than 7d
nix-collect-garbage --delete-older-than 7d
```

查看保留的数据：

```bash
sudo findmnt | grep /persist
sudo du -sh /persist/*
```

查看 `/persist` 的 Snapper 快照和定时任务：

```bash
snapper -c persist list
systemctl list-timers 'snapper-*'
```

## 添加持久目录

临时根目录意味着：没有列入持久化清单的数据会在重启后消失。

标准的 Desktop、Documents、Downloads、Music、Pictures、Public、Templates、Videos 已持久化；`XDG_PROJECTS_DIR` 指向新增的 `~/Workspace`。用户的 `.config`、`.local/share` 和 `.local/state` 也会保留，因此应用设置、数据和 Zsh 历史不会在重启后丢失。`.cache` 有意保持临时，避免缓存长期占用 `/persist` 和 Snapper 快照空间。

- 系统目录：编辑 `modules/impermanence.nix` 中的 `directories` 或 `files`
- 用户目录：编辑同一文件的 `users.${username}.directories`

例如要保留 Podman 数据，可加入：

```nix
"/var/lib/containers"
```

修改后先重建系统，再开始把重要数据放进新目录。

## 常用 Hyprland 快捷键

| 快捷键 | 动作 |
|---|---|
| `Super + Q` | 退出 Hyprland |
| `Alt + F4` | 关闭当前窗口 |
| `Super + W` | 切换当前窗口浮动状态 |
| `Super + L` | 使用 Hyprlock 锁定屏幕 |
| `Shift + F11` / `Super + D` | 切换全屏 |
| `Super + Shift + F` | 切换窗口置顶；平铺窗口会先转为浮动 |
| `Super + 方向键` | 向对应方向切换焦点 |
| `Super + Shift + 方向键` | 按 50 像素调整当前窗口大小 |
| `Super + Ctrl + Shift + 方向键` | 向对应方向移动当前窗口 |
| `Super + 鼠标左键` | 拖动窗口 |
| `Super + 鼠标右键` | 调整窗口大小 |

### 启动应用

| 快捷键 | 动作 |
|---|---|
| `Super + T` | 打开 Kitty |
| `Super + Alt + T` | 切换下拉 Kitty 终端 |
| `Super + E` | 打开文件管理器 |
| `Super + C` | 打开 VS Code |
| `Super + B` | 打开 Firefox |
| `Ctrl + Shift + Escape` | 打开 Mission Center；终端中也可运行 `btop` |
| `Super + A` | 打开 Fuzzel 应用查找器 |

### 工作区与暂存区

| 快捷键 | 动作 |
|---|---|
| `Super + 1..9` / `Super + 0` | 切换到工作区 1..9 / 10 |
| `Super + Shift + 1..9` / `Super + Shift + 0` | 移动窗口到工作区 1..9 / 10 |
| `Super + Shift + S` / `Super + Shift + M` | 移动窗口到暂存区 S / M 并跟随 |
| `Super + Alt + S` / `Super + Alt + M` | 静默移动窗口到暂存区 S / M |
| `Super + S` / `Super + M` | 显示或隐藏暂存区 S / M |

### 屏幕捕获

| 快捷键 | 动作 |
|---|---|
| `Super + Shift + P` | 选取颜色并复制到剪贴板 |
| `Super + P` | 截取屏幕区域 |
| `Super + Ctrl + P` | 冻结画面后截取屏幕区域 |
| `Super + Alt + P` | 截取当前显示器 |
| `Print` | 截取所有显示器 |

截图会同时复制到剪贴板，并保存到 XDG 图片目录下的 `Screenshots` 子目录。

## 注意事项

- 配置面向 `x86_64-linux` 和 UEFI 设备。
- `users.mutableUsers = true` 方便首次安装后用 `passwd` 设置密码；密码哈希保存在 `/persist/etc/shadow` 对应的持久系统状态中。
- 不要把代理订阅、密码、SSH 私钥或其他密钥提交到 GitHub。
- `flake.lock` 应当提交；`result` 等本地构建结果已由 `.gitignore` 排除。
- Flake 更新可能包含破坏性变化。先执行 `nix flake check --no-build`，再切换系统，并保留可启动的旧代次。

## 许可证

本仓库配置使用 MIT License。各软件仍遵循各自许可证。

## 上游项目

- [NixOS / nixpkgs](https://github.com/NixOS/nixpkgs)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Disko](https://github.com/nix-community/disko)
- [Impermanence](https://github.com/nix-community/impermanence)
- [Lanzaboote](https://github.com/nix-community/lanzaboote)
- [Noctalia v5](https://github.com/noctalia-dev/noctalia)
- [rime-ice](https://github.com/iDvel/rime-ice)
- [AstroNvim Template](https://github.com/AstroNvim/template)
- [FlClash](https://github.com/chen08209/FlClash)
