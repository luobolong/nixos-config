# NixOS Hyprland / niri 工作站

一套可以直接放到 GitHub 管理的 NixOS 配置。它使用 Flakes、Home Manager 和 Btrfs，提供 Hyprland + Caelestia Shell 与 niri + Noctalia v5 两套桌面（在登录界面自由选择）、雾凇拼音和常用桌面/开发软件。

> [!WARNING]
> 本配置面向一块硬盘上的 Windows + NixOS。分区前务必备份 Windows、暂停 BitLocker 并确认设备路径；只在 Windows 释放的未分配空间中新建 NixOS 分区，绝不能格式化已有的 Windows ESP、MSR、系统或恢复分区。

## 包含内容

- NixOS unstable + Flakes
- Home Manager
- 单硬盘 Windows + NixOS 双系统，保留 Windows 分区并使用独立的 2 GiB NixOS ESP
- Btrfs：`@root`、`@nix`、`@home` 分别挂载到 `/`、`/nix`、`/home`，并使用 Zstd 压缩
- Snapper：分别为 `/` 和 `/home` 自动创建快照，并按小时、天、周、月清理
- rEFInd（10 秒）→ systemd-boot（2 秒）→ Lanzaboote UKI；支持 UEFI Secure Boot，最多保留 10 个系统代次
- 每周自动清理 7 天前的 Nix 代次，并优化 Nix Store
- Hyprland（UWSM 会话，Lua 配置）+ Caelestia Shell，以及 niri（滚动平铺，KDL 配置）+ Noctalia v5
- greetd + tuigreet 登录界面
- Kitty（Wayland 模糊背景）+ Zsh + Starship 提示符
- NetworkManager、蓝牙、PipeWire
- Fcitx5 + Rime + rime-ice（雾凇拼音）+ Catppuccin Mocha Sapphire 皮肤
- Inter、Source Serif 4、Noto CJK/Emoji、Sarasa Gothic 字体 + Papirus Dark 图标主题 + Adwaita 32px 鼠标主题
- Dolphin、Fastfetch、Mission Center、btop、Fuzzel（Catppuccin Mocha）、Satty、Hyprlock、Neovim + AstroNvim v5、VS Code、IntelliJ IDEA Ultimate、DataGrip、GoLand、Claude Code、Codex、CC Switch、Spotify、QQ
- GnuPG + GPG Agent、SSH Agent、direnv + nix-direnv
- sops-nix：使用 GPG 与本机 SSH host key 对敏感配置加密
- jq、yq、rsync、Zip/7-Zip、常用硬件诊断、NixOS 维护与基础构建工具

## 目录结构

```text
.
├── .sops.yaml
├── flake.nix
├── hosts/nixos/
│   ├── default.nix
│   ├── disk-config.nix
│   ├── hardware-configuration.nix
│   └── lenovo-14aph8-edid.hex
├── modules/
│   ├── core.nix
│   ├── desktop.nix
│   ├── fonts.conf
│   ├── refind.nix
│   ├── secrets.nix
│   └── snapper.nix
├── home/
│   ├── default.nix
│   ├── hyprland.lua
│   ├── niri.kdl
│   └── zsh.nix
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

### 3. Lenovo 14APH8 120 Hz 屏幕修复

`hosts/nixos/hardware-configuration.nix` 已包含 Lenovo IdeaPad Pro 5 14APH8（面板 `MNE007ZA1-5`）的修正 EDID。构建时会把 `lenovo-14aph8-edid.hex` 转为固件、打入 initrd，并加入：

```nix
boot.kernelParams = [ "drm.edid_firmware=eDP-1:edid/lenovo-14aph8.bin" ];
boot.initrd.extraFirmwarePaths = [ "edid/lenovo-14aph8.bin" ];
```

该 EDID 只适用于上述 2880×1800 面板。原始问题可通过内核日志中的 `[drm] DisplayID checksum invalid, remainder is 248` 确认；若电脑使用其他面板，应移除这两个选项和 `hardware.firmware` 中的 `lenovo120HzEdid`。

### 4. 单硬盘分区规划

Windows 应先安装，并保留其 ESP、MSR、系统和恢复分区。在 Windows 磁盘管理中压缩系统卷后，未分配空间按以下顺序用于 NixOS：

| 分区 | 建议大小 | 格式/标签 | 用途 |
|---|---:|---|---|
| NixOS ESP | 2 GiB | FAT32 / `NIXBOOT` | rEFInd、systemd-boot、Lanzaboote UKI |
| Swap | 32 GiB | swap / `nixos-swap` | swap；内存不超过 32 GiB 时可用于休眠恢复 |
| NixOS 系统 | 剩余空间 | Btrfs / `nixos` | `/`、`/nix`、`/home` |

Windows 默认 ESP 往往只有 100–260 MiB，难以容纳多个 UKI 代次，所以本方案在同一块硬盘上使用两个 ESP。`disk-config.nix` 只按标签挂载 NixOS 的三个分区，不声明整盘分区表，因此重建系统不会改动 Windows 分区。

### 5. 确认 Windows ESP

rEFInd 的 Windows 条目使用 Windows ESP 的 GPT 分区 UUID，当前配置位于 `hosts/nixos/hardware-configuration.nix`：

```nix
windowsEfiPartuuid = "991a77db-c316-4f75-b9df-bc05e179a798";
```

安装时使用 `lsblk -o PATH,SIZE,FSTYPE,LABEL,PARTUUID,PARTLABEL` 找到包含 `EFI/Microsoft/Boot/bootmgfw.efi` 的原 Windows FAT 分区，并把此值改为它的 `PARTUUID`。不要填文件系统 UUID，也不要填新建的 `NIXBOOT` 分区。

## 单硬盘双系统安装

以下步骤假定 Windows 已经以 UEFI/GPT 模式安装。先在 Windows 中关闭“快速启动”、暂停 BitLocker，然后使用磁盘管理压缩 Windows 卷并保留未分配空间。以下命令中的尖括号是占位符，必须替换为实际设备路径。

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

### 2. 下载并检查配置

把地址替换成你上传后的 GitHub 仓库：

```bash
git clone https://github.com/YOUR_NAME/YOUR_REPO.git
cd YOUR_REPO
```

如果还没有上传，可以在安装环境中先创建并编辑这套文件；执行 Flake 命令前，记得运行 `git add .`，因为 Nix Flake 不会读取 Git 仓库中未跟踪的文件。

提交锁文件后检查配置：

```bash
nix --extra-experimental-features "nix-command flakes" flake check --no-build
```

### 3. 只在未分配空间创建 NixOS 分区

```bash
ls -l /dev/disk/by-id/
lsblk -o PATH,SIZE,MODEL,FSTYPE,LABEL,PARTUUID,PARTLABEL,MOUNTPOINTS
```

找到 Windows 所在的整块硬盘，并确认未分配空间来自刚才压缩的 Windows 卷。打开分区工具：

```bash
sudo cfdisk /dev/disk/by-id/<同一块硬盘>
```

只在 `Free space` 中依次新建 2 GiB EFI System、32 GiB Linux swap，以及占满剩余空闲空间的 Linux filesystem，然后选择 `Write`。不要删除或改变任何已有分区。

再次运行 `lsblk`，确定三个新分区的路径和原 Windows ESP。检查无误后只格式化三个新分区：

```bash
sudo mkfs.fat -F 32 -n NIXBOOT <新建的-2GiB-ESP>
sudo mkswap -L nixos-swap <新建的-swap>
sudo mkfs.btrfs -f -L nixos <新建的-btrfs>
```

确认 Windows ESP 的 PARTUUID，并检查其中确实有 Windows Boot Manager：

```bash
sudo mkdir -p /mnt/windows-esp
sudo mount <原-Windows-ESP> /mnt/windows-esp
test -f /mnt/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi && echo "Windows ESP 正确"
lsblk -no PARTUUID <原-Windows-ESP>
sudo umount /mnt/windows-esp
```

把输出的 PARTUUID 写入 `hardware-configuration.nix` 的 `windowsEfiPartuuid`。

### 4. 创建并挂载 Btrfs 子卷

```bash
sudo mount -o subvolid=5 /dev/disk/by-label/nixos /mnt
sudo btrfs subvolume create /mnt/@root
sudo btrfs subvolume create /mnt/@root/.snapshots
sudo btrfs subvolume create /mnt/@nix
sudo btrfs subvolume create /mnt/@home
sudo btrfs subvolume create /mnt/@home/.snapshots
sudo umount /mnt
```

```bash
sudo mount -o subvol=@root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/nix /mnt/home /mnt/boot
sudo mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
sudo mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
sudo mount -o umask=0077 /dev/disk/by-label/NIXBOOT /mnt/boot
sudo swapon /dev/disk/by-label/nixos-swap
```

确认挂载来源都属于刚创建的 NixOS 分区：

```bash
findmnt -R /mnt
```

### 5. 安装 NixOS

默认主机名为 `nixos`：

```bash
sudo nixos-install --flake .#nixos --no-root-passwd
```

如果你修改了 `hostname`，把 `#nixos` 换成新名称。

配置已经声明 `ben` 和 `root` 的初始登录密码均为单字母 `q`，不需要再进入安装目标执行 `passwd`。然后重启：

```bash
sudo reboot
```

拔掉安装 U 盘后，应先看到只包含 `systemd-boot` 和 `Windows` 的 rEFInd 菜单；两者分别来自同一块硬盘上的 NixOS ESP 和 Windows ESP。选择带 NixOS 图标的 `systemd-boot` 后，再选择 NixOS 系统代次。首次登录在 tuigreet 中输入用户名 `ben`、密码 `q`，并选择 Hyprland 或 niri 会话（tuigreet 会记住上次选择）。此时先保持固件 Secure Boot 关闭，首次启动的 rEFInd 和 UKI 尚未签名。

## 首次登录

### 验证 120 Hz

重启进入图形会话后确认 EDID 覆盖已加载，并检查当前输出模式：

```bash
journalctl -b -k | grep -E "edid|DisplayID"
hyprctl monitors
```

`hyprctl monitors` 应显示内部屏幕为 `2880x1800@120` 左右；使用 niri 时也可以运行 `niri msg outputs`。如果日志提示找不到 `edid/lenovo-14aph8.bin`，不要仅在桌面会话中添加自定义 modeline，应先检查该文件是否进入 initrd。

### Claude Code

Claude Code 的 API 供应商、令牌与代理设置完全由 **CC Switch** 管理（桌面应用，用于切换 Claude Code / Codex / Gemini CLI 等 AI 编码工具的供应商）。首次使用先启动 CC Switch 添加并启用供应商，之后直接运行 `claude` 即可，无需在系统中配置任何环境变量或密钥。

### UKI 与 Secure Boot

Lanzaboote 会为每个 NixOS 系统代次生成 UKI。首次启动时，`generate-sb-keys.service` 会在持久化的 `/var/lib/sbctl` 中生成 Secure Boot 密钥：

```bash
systemctl status generate-sb-keys.service
sudo sbctl status
```

确认密钥已经生成后，再重建一次，使安装器使用同一套密钥签名 rEFInd、systemd-boot 和 UKI：

```bash
sudo nixos-rebuild boot --flake .#nixos
sudo sbctl verify
```

`sbctl verify` 会把 `/boot/EFI/nixos/kernel-*.efi` 报告为未签名，这是 Lanzaboote 的正常布局：已签名的 generation EFI 文件保存并校验该外部内核的 SHA-256，不能手动签名或删除它。rEFInd、systemd-boot 和 `/boot/EFI/Linux/nixos-generation-*.efi` 应显示为已签名。

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

### Zsh

Zsh 采用 [radleylewis/zsh](https://github.com/radleylewis/zsh) 的精简方案，并由 Home Manager 声明式管理插件及依赖。配置包含 Starship、zoxide、fzf、eza、bat、fast-syntax-highlighting、autosuggestions、history substring search 和 vi mode。

常用快捷键：`Ctrl+R` 搜索历史，`Ctrl+T` 搜索包含隐藏文件的文件，`Ctrl+F` 搜索普通文件，`Ctrl+Left/Right` 按单词移动，`Up/Down` 按子串搜索历史，`Ctrl+\` 切换自动建议。

### AstroNvim

首次运行会下载 AstroNvim 插件：

```bash
nvim
```

插件、状态和缓存保存在用户主目录中。AstroNvim 模板本身由 Flake 输入管理。

### 桌面 Shell

Hyprland 会话从其 Lua 配置启动 Caelestia Shell，设置保存在 `~/.config/caelestia`。可以查看 Shell IPC 是否可用：

```bash
caelestia shell -s
```

niri 会话仍通过用户服务启动 Noctalia，图形设置保存在 `~/.config/noctalia`。检查服务：

```bash
systemctl --user status noctalia
```

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

查看 Btrfs 文件系统用量：

```bash
sudo btrfs filesystem usage /
```

查看根目录和 Home 的 Snapper 快照及定时任务：

```bash
snapper -c root list
snapper -c home list
systemctl list-timers 'snapper-*'
```

## 数据保存

根目录和 Home 使用独立的持久化 Btrfs 子卷，系统状态、用户文件、应用配置和缓存都会正常跨重启保留。`XDG_PROJECTS_DIR` 指向 `~/Workspace`；需要释放空间时可按需清理 `~/.cache`。

## Hyprland 会话快捷键

以下快捷键适用于 Hyprland 会话。niri 会话的键位见后文，两者尽量保持一致。

| 快捷键 | 动作 |
|---|---|
| `Super + Q` / `Alt + F4` | 关闭当前窗口 |
| `Super + Alt + F4` | 强制结束当前窗口进程 |
| `Super + W` | 切换当前窗口浮动状态 |
| `Super + G` | 切换窗口分组 |
| `Super + L` | 使用 Caelestia 锁定屏幕 |
| `Shift + F11` / `Super + D` | 切换全屏 |
| `Super + Shift + W` | 切换窗口置顶；平铺窗口会先转为浮动 |
| `Super + J` | 切换 Dwindle 分割方向 |
| `Super + Ctrl + H` / `Super + Ctrl + L` | 向后 / 向前切换活动分组 |
| `Super + Alt + Z` | 切换 2 倍屏幕放大；放大画面跟随鼠标移动，鼠标始终位于画面中心 |
| `Super + Alt + 滚轮上 / 下` | 以 0.25 倍为一级放大 / 缩小屏幕，范围为 1–10 倍；滚轮不会传递给当前应用 |
| `Super + 方向键` | 向对应方向切换焦点 |
| `Alt + Tab` | 切换到下一个窗口；按住可连续切换 |
| `Super + Shift + 方向键` | 按 50 像素调整当前窗口大小 |
| `Super + Ctrl + Shift + 方向键` | 向对应方向移动当前窗口 |
| `Super + 鼠标左键` | 拖动窗口 |
| `Super + 鼠标右键` | 调整窗口大小 |
| `Super + Z` / `Super + X` | 按住并移动鼠标以拖动 / 调整窗口大小 |

### 触控板手势

| 手势 | 动作 |
|---|---|
| 三指左右滑动 | 1:1 跟手切换相邻工作区 |
| 四指滑动 | 拖拽浮动窗口或重排平铺窗口 |
| 四指拖拽期间按 `Super + Shift + 数字键` | 将窗口拖到对应工作区并跟随 |
| 四指捏合 | 取消活动窗口最大化 |
| 四指张开 | 切换活动窗口最大化状态 |

### 启动应用

| 快捷键 | 动作 |
|---|---|
| `Super + T` | 打开 Kitty |
| `Super + E` | 打开文件管理器 |
| `Super + C` | 打开 VS Code |
| `Super + B` | 打开 Firefox |
| `Ctrl + Shift + Escape` | 打开 Mission Center；终端中也可运行 `btop` |
| `Super + A` | 打开 Caelestia 应用启动器 |
| `Super + V` | 打开 Caelestia 剪贴板历史 |
| `Super + /` | 显示快捷键说明 |

### 工作区与暂存区

| 快捷键 | 动作 |
|---|---|
| `Super + 1..9` / `Super + 0` | 切换到工作区 1..9 / 10 |
| `Super + Shift + 1..9` / `Super + Shift + 0` | 移动窗口到工作区 1..9 / 10 |
| `Super + Ctrl + Down` | 切换到空工作区 |
| `Super + 鼠标滚轮下` / `Super + 鼠标滚轮上` | 下一个 / 上一个已存在工作区 |
| `Super + Ctrl + Right` / `Super + Ctrl + Left` | 下一个 / 上一个相对工作区 |
| `Super + Alt + Ctrl + Right` / `Super + Alt + Ctrl + Left` | 移动窗口到下一个 / 上一个相对工作区 |
| `Super + Shift + S` / `Super + Shift + M` | 移动窗口到暂存区 S / M 并跟随 |
| `Super + Alt + S` / `Super + Alt + M` | 静默移动窗口到暂存区 S / M |
| `Super + S` / `Super + M` | 显示或隐藏暂存区 S / M |

### 屏幕捕获

| 快捷键 | 动作 |
|---|---|
| `Super + Shift + P` | 选取颜色并复制到剪贴板 |
| `Super + P` | 截取屏幕区域并用 Satty 标注 |
| `Super + Ctrl + P` | 冻结画面后截取区域并用 Satty 标注 |
| `Super + Alt + P` | 截取当前显示器并用 Satty 标注 |
| `Print` | 截取所有显示器并用 Satty 标注 |

截图完成后会打开 Satty 进行标注。在 Satty 中复制结果到剪贴板，或保存到 XDG 图片目录下的 `Screenshots` 子目录。

## niri 会话快捷键

niri 是滚动平铺合成器，键位在 `home/niri.kdl` 中定义。列（column）是横向滚动布局的基本单位，列内窗口纵向排列；工作区保持动态模型，并可通过数字索引快速切换。

### 窗口与会话

| 快捷键 | 动作 |
|---|---|
| `Super + Q` / `Alt + F4` | 关闭当前窗口 |
| `Super + W` | 切换当前窗口浮动 |
| `Super + Shift + V` | 在浮动层和平铺层之间切换焦点 |
| `Super + Shift + F` | 切换全屏 |
| `Super + F` / `Super + M` | 最大化列 / 将窗口最大化到屏幕边缘 |
| `Super + Alt + L` | 使用 Noctalia 锁定屏幕 |
| `Alt + Tab` | 打开 niri 原生最近窗口切换器；可在其中按 `A` / `W` / `O` 切换全部、当前工作区或当前显示器范围 |
| `Super + Tab` | 在当前工作区和上一个工作区之间切换 |
| `Super + \` | 切换当前列的标签视图 |
| `Super + O` | 切换概览模式 |
| `Super + Escape` | 解除或恢复应用程序的快捷键抑制 |
| `Super + Shift + E` | 退出 niri（会显示确认对话框） |
| `Super + Shift + /` | 显示快捷键速查 |

### 焦点、移动与调整

| 快捷键 | 动作 |
|---|---|
| `Super + Left/Right` 或 `Super + H/L` | 聚焦左 / 右列 |
| `Super + Up/Down` 或 `Super + K/J` | 聚焦列内上 / 下窗口 |
| `Super + Ctrl + Left/Right` 或 `Super + Ctrl + H/L` | 左 / 右移动当前列 |
| `Super + Ctrl + Up/Down` 或 `Super + Ctrl + K/J` | 在列内上 / 下移动当前窗口 |
| `Super + Shift + 方向键` 或 `Super + Shift + H/J/K/L` | 聚焦对应方向的显示器 |
| `Super + Ctrl + Shift + 方向键` 或 `Super + Ctrl + Shift + H/J/K/L` | 把当前列移到对应方向的显示器 |
| `Super + Home/End` | 聚焦工作区的第一列 / 最后一列 |
| `Super + Ctrl + Home/End` | 把当前列移到工作区最前 / 最后 |
| `Super + G` / `Super + Ctrl + G` | 居中当前列 / 居中所有完整可见列 |
| `Super + Ctrl + F` | 将当前列扩展到剩余可用宽度 |
| `Super + R` / `Super + Shift + R` | 正向 / 反向循环预设列宽 |
| `Super + Ctrl + R` | 将当前窗口高度重置为自动 |
| `Super + -/=` | 按 10% 缩小 / 放大列宽 |
| `Super + Shift + -/=` | 按 10% 缩小 / 放大窗口高度 |
| `Super + [` / `Super + ]` | 向左 / 向右并入或弹出当前窗口 |
| `Super + ,` / `Super + .` | 把右侧窗口并入当前列 / 从当前列弹出底部窗口 |

### 启动应用

| 快捷键 | 动作 |
|---|---|
| `Super + T` | 打开 Kitty |
| `Super + E` | 打开 Dolphin |
| `Super + C` | 打开 VS Code |
| `Super + B` | 打开 Firefox |
| `Ctrl + Shift + Escape` | 打开 Mission Center |
| `Super + A` | 打开 Noctalia 应用启动器 |
| `Super + V` | 打开 Noctalia 剪贴板 |

### 媒体与亮度

| 快捷键 | 动作 |
|---|---|
| 音量增加 / 降低 / 静音键 | 以 5% 调整默认输出音量或切换静音；最大音量限制为 100% |
| 麦克风静音键 | 切换默认输入设备静音 |
| 播放 / 暂停 / 停止 / 上一首 / 下一首键 | 通过 Playerctl 控制当前 MPRIS 播放器 |
| 亮度增加 / 降低键 | 以 5% 调整背光亮度 |

### 动态工作区

| 快捷键 | 动作 |
|---|---|
| `Super + 1..9` / `Super + 0` | 切换到动态索引 1..9 / 10；超出当前数量时进入末尾空工作区 |
| `Super + Shift + 1..9` / `Super + Shift + 0` | 把当前列移到动态索引 1..9 / 10 并跟随 |
| `Super + PageDown/PageUp` 或 `Super + U/I` | 切换到下 / 上一个工作区 |
| `Super + Ctrl + PageDown/PageUp` 或 `Super + Ctrl + U/I` | 把当前列移到下 / 上一个工作区并跟随 |
| `Super + Shift + PageDown/PageUp` 或 `Super + Shift + U/I` | 向下 / 向上重排当前工作区 |
| `Super + 鼠标滚轮下 / 上` | 切换到下 / 上一个工作区 |
| `Super + Ctrl + 鼠标滚轮下 / 上` | 把当前列移到下 / 上一个工作区并跟随 |

每个显示器拥有独立的动态工作区列表，末尾始终保留一个空工作区。使用 `Super + O` 打开概览，可以直接观察和拖动各工作区及窗口。

### 鼠标与触控板

| 操作 | 动作 |
|---|---|
| `Super + 鼠标左键拖动` | 移动窗口；拖动时点按右键可在浮动和平铺之间切换目标 |
| `Super + 鼠标右键拖动` | 调整窗口大小 |
| 触控板三指左右滑动 | 横向滚动当前工作区的列 |
| 触控板三指上下滑动 | 切换动态工作区 |
| 触控板四指上下滑动 | 打开或关闭概览 |

### 屏幕捕获

| 快捷键 | 动作 |
|---|---|
| `Super + Shift + P` | 选取颜色并复制到剪贴板 |
| `Super + P` | 交互式区域截图 |
| `Super + Ctrl + P` | 冻结画面后进行交互式区域截图 |
| `Super + Alt + P` | 截取当前显示器 |
| `Print` | 截取所有显示器 |

Hyprland 与 niri 共用 `hypr-screenshot` 脚本，截图后都会打开 Satty 进行标注、复制或保存。系统不会自动锁屏或关闭显示器，需要时使用对应会话的手动锁屏快捷键。

## 注意事项

- 配置面向 `x86_64-linux` 和 UEFI 设备。
- `ben` 和 `root` 当前都使用极弱密码 `q`。配置只保存密码哈希，并以 `users.mutableUsers = false` 强制同步声明式账户密码；正式使用前应通过 `mkpasswd` 生成新哈希并替换 `modules/core.nix` 中的 `loginPasswordHash`。
- 不要把代理订阅、密码、SSH 私钥或其他密钥提交到 GitHub。
- `flake.lock` 应当提交；`result` 等本地构建结果已由 `.gitignore` 排除。
- Flake 更新可能包含破坏性变化。先执行 `nix flake check --no-build`，再切换系统，并保留可启动的旧代次。

## 许可证

本仓库配置使用 MIT License。各软件仍遵循各自许可证。

## 上游项目

- [NixOS / nixpkgs](https://github.com/NixOS/nixpkgs)
- [Home Manager](https://github.com/nix-community/home-manager)
- [Catppuccin for Fuzzel](https://github.com/catppuccin/fuzzel)
- [Lanzaboote](https://github.com/nix-community/lanzaboote)
- [Lenovo IdeaPad Pro 5 14APH8 120 Hz EDID fix](https://github.com/dgroenen/lenovo-ideapad-pro-5-14-14APH8-120hz-fix)
- [Caelestia Shell](https://github.com/caelestia-dots/shell)
- [Noctalia v5](https://github.com/noctalia-dev/noctalia)
- [rime-ice](https://github.com/iDvel/rime-ice)
- [AstroNvim Template](https://github.com/AstroNvim/template)
