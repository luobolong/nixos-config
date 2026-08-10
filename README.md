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
- rEFInd，最多显示 10 个系统代次
- 每周自动清理 7 天前的 Nix 代次，并优化 Nix Store
- Hyprland（UWSM 会话）+ Noctalia v5
- greetd + tuigreet 登录界面
- NetworkManager、蓝牙、PipeWire
- Fcitx5 + Rime + rime-ice（雾凇拼音）
- Neovim + AstroNvim v5、VS Code、Spotify、FlClash

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

### 2. 选择 CPU

默认硬件配置适用于 Intel CPU。AMD 用户在 `hosts/nixos/hardware-configuration.nix` 中把：

```nix
boot.kernelModules = [ "kvm-intel" ];
hardware.cpu.intel.updateMicrocode = ...;
```

改为：

```nix
boot.kernelModules = [ "kvm-amd" ];
hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
```

NVIDIA 显卡通常还需要额外的驱动配置；本仓库默认面向 Intel/AMD 核显或 AMD 显卡。

### 3. 调整根目录和 Swap 大小

默认临时根目录最多使用 8 GiB 内存，Swap 分区为 16 GiB。可分别在 `hosts/nixos/disk-config.nix` 中修改：

```nix
options = [ "defaults" "mode=755" "size=8G" ];
size = "16G";
```

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

拔掉安装 U 盘，rEFInd 应显示 NixOS 启动项。首次登录在 tuigreet 中选择 Hyprland。

## 首次登录

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

## 添加持久目录

临时根目录意味着：没有列入持久化清单的数据会在重启后消失。

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
| `Super + Enter` | 打开 Kitty |
| `Super + E` | 打开文件管理器 |
| `Super + B` | 打开 Firefox |
| `Super + Q` | 关闭当前窗口 |
| `Super + F` | 全屏 |
| `Super + V` | 切换浮动窗口 |
| `Super + 1..5` | 切换工作区 |
| `Super + Shift + 1..5` | 移动窗口到工作区 |
| `Super + Shift + M` | 退出 Hyprland |

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
- [Noctalia v5](https://github.com/noctalia-dev/noctalia)
- [rime-ice](https://github.com/iDvel/rime-ice)
- [AstroNvim Template](https://github.com/AstroNvim/template)
- [FlClash](https://github.com/chen08209/FlClash)
