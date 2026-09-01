# NixOS Configuration

面向 AMD x86-64 工作站与 Lenovo IdeaPad Pro 5 14APH8 笔记本的个人 NixOS 和 Home Manager 配置。

[English](README.en.md)

---

## 中文

### 项目概览

这是一套面向个人设备的完整系统配置，而不是可直接套用到任意机器的通用模块库。它同时管理 NixOS、Home Manager、启动链、磁盘挂载、桌面会话、开发工具和常用应用。

| 项目 | 当前值 |
|---|---|
| 架构 | <code>x86_64-linux</code> |
| Flake 输出 | <code>nixosConfigurations.nixos</code> |
| 主机名 | <code>nixos</code> |
| 用户名 | <code>ben</code> |
| Nixpkgs | <code>nixos-unstable</code> |
| NixOS / Home Manager state version | <code>25.11</code> |
| 时区 | <code>Asia/Taipei</code> |
| 桌面会话 | Hyprland 与 niri |
| 登录管理器 | greetd + tuigreet |
| 系统盘 | Btrfs，启用 zstd 压缩与 Snapper |
| 启动链 | rEFInd → systemd-boot / Lanzaboote → UKI |

主要能力：

- 使用 Flake 统一组合 NixOS、Home Manager、Lanzaboote、sops-nix 与 Noctalia。
- 同时提供 Hyprland 动态平铺和 niri 滚动平铺会话。
- 由 Noctalia 提供状态栏、启动器、剪贴板、通知、壁纸和会话界面。
- 使用 Fcitx5 + Rime Ice，提供中英文输入。
- 使用 PipeWire、NetworkManager、BlueZ/Blueman、UDisks2 与桌面门户。
- 使用 Btrfs 子卷、每小时 Snapper 快照、周期清理和 TRIM。
- 打包 ChatGPT Linux 客户端、DeepSeek Harness、Linux QQ 剪贴板同步和 AudioMonitor。
- 为 Wayland、Electron、Qt/KDE 和 GTK 应用统一 Catppuccin Mocha 风格。

### 分支模型

<code>master</code> 是带 Disko 的 AMD x86-64 基线配置；<code>laptop</code> 是当前 Lenovo 笔记本的设备专用配置。<code>master</code> 是 <code>laptop</code> 的祖先，通用改动应保持同步，设备差异保留在下表所列文件中。

| 范围 | <code>master</code> | <code>laptop</code> |
|---|---|---|
| 用途 | 新磁盘部署基线 | 已安装的 Lenovo IdeaPad Pro 5 14APH8 |
| 磁盘管理 | 引入 Disko，并将其加入 Flake、系统模块和维护工具 | 不引入 Disko，只声明现有文件系统 |
| 磁盘布局 | 将 <code>/dev/disk/by-id/CHANGE_ME</code> 重新分区为 2 GiB ESP、64 GiB swap 和 Btrfs 系统分区 | 依赖已有 2 GiB <code>NIXBOOT</code>、32 GiB <code>nixos-swap</code> 与 <code>nixos</code> 标签；不会创建分区 |
| Btrfs 子卷 | Disko 创建 <code>@root</code>、<code>@nix</code>、<code>@home</code> 及快照子卷 | 挂载已有 <code>@root</code>、<code>@nix</code>、<code>@home</code> |
| Windows 双启动 | Windows ESP 使用 PARTUUID <code>991a77db-c316-4f75-b9df-bc05e179a798</code>，并应位于不会被 Disko 清除的另一块磁盘上 | 同一 SSD 上的 Windows ESP 使用 <code>084dbc6c-e077-48f9-b6d5-ccd76d8f1d42</code> |
| 内置屏幕 | 无 EDID 覆盖 | 在 initrd 中加载校正 EDID，修复 2880×1800 面板的 120 Hz 模式 |
| Noctalia 默认栏 | 包含媒体与 mpvpaper，并为 <code>DP-2</code> 提供单独布局 | 默认栏显示网络、蓝牙和电池，不设置 <code>DP-2</code> 覆盖 |
| Flake 锁文件 | 包含 Disko 输入闭包 | 移除 Disko 输入闭包 |

可用以下命令核对两个已提交分支的实际差异：

~~~bash
git diff --stat master...laptop
git diff master...laptop -- flake.nix home/default.nix hosts/nixos modules/core.nix
~~~

### 仓库结构

~~~text
.
├── .sops.yaml                        # GPG 与 Age 加密接收者规则
├── flake.nix                         # 输入、主机输出、检查与格式化器
├── flake.lock
├── hosts/nixos/
│   ├── default.nix                   # 主机模块入口和 Home Manager 接线
│   ├── disk-config.nix               # 分支相关的磁盘布局或挂载
│   ├── hardware-configuration.nix    # AMD 硬件、ESP 和笔记本 EDID
│   └── lenovo-14aph8-edid.hex        # laptop 分支的校正 EDID
├── modules/
│   ├── core.nix                      # 用户、Nix、内核、SSH 和系统工具
│   ├── desktop.nix                   # Wayland 会话、音频、蓝牙、输入法和字体
│   ├── refind.nix                    # rEFInd + Lanzaboote 安装链
│   ├── snapper.nix                   # root/home 快照策略
│   ├── clash-verge.nix               # Clash Verge service/TUN 配置
│   ├── secrets.nix                   # sops-nix Age 密钥来源
│   ├── fonts.conf                    # Fontconfig 字体优先级
│   └── patches/                      # 本地软件修补
├── home/
│   ├── default.nix                   # Home Manager、应用、主题和用户服务
│   ├── hyprland.lua                  # Hyprland Lua 配置
│   ├── niri.kdl                      # niri 配置
│   ├── niri-smart-direction.sh       # niri 浮动窗口智能方向操作
│   └── zsh.nix                       # Zsh、Starship、fzf 和终端工具
└── packages/
    ├── chatgpt.nix                   # ChatGPT 官方 Linux 二进制封装
    ├── deepseek-harness.nix          # DeepSeek Harness NPM 构建
    └── deepseek-harness/package-lock.json
~~~

### 安装前修改

#### 主机名与用户名

在 <code>flake.nix</code> 中修改下列值：

~~~nix
let
  system = "x86_64-linux";
  hostname = "nixos";
  username = "ben";
in
~~~

- <code>hostname</code> 同时决定 <code>networking.hostName</code> 和 Flake 输出名。改为 <code>my-host</code> 后，安装与重建目标也要改为 <code>.#my-host</code>。
- <code>hosts/nixos</code> 是固定的源码目录名，不会随主机名自动变化，也不需要仅因修改主机名而重命名。
- <code>username</code> 会传给 NixOS 用户和 Home Manager 配置。修改后，还应检查 <code>home/default.nix</code> 中的 Git 姓名、邮箱、签名密钥及其他个人设置。
- 文档里的 <code>ben</code> 和 <code>nixos</code> 命令示例都要替换成新值。

#### 账户与密码

<code>modules/core.nix</code> 设置了 <code>users.mutableUsers = false</code>，root 与普通用户共用变量 <code>loginPasswordHash</code>。仓库当前保存的是弱密码 <code>q</code> 对应的哈希，只能视为占位符。安装前生成新哈希并替换它：

~~~bash
nix shell nixpkgs#mkpasswd -c mkpasswd -m sha-512
~~~

如需为 root 和普通用户使用不同密码，应拆分为两个哈希变量。OpenSSH 当前已启用而防火墙关闭，也应在部署前按目标网络调整 <code>services.openssh</code>、认证方式和 <code>networking.firewall</code>。

#### CPU、显卡与笔记本面板

<code>hosts/nixos/hardware-configuration.nix</code> 假定 AMD CPU 与 AMDGPU：启用了 <code>kvm-amd</code>、AMD 微码、AMDGPU initrd KMS 以及 32 位图形支持。Intel、NVIDIA 或不同硬件必须据实调整。

<code>laptop</code> 分支额外加载 Lenovo IdeaPad Pro 5 14APH8 的校正 EDID。只有对应的 2880×1800 面板需要这组设置；其他设备应移除 EDID 固件构建、<code>drm.edid_firmware</code> 内核参数和相关固件路径。

#### Windows ESP

rEFInd 通过 Windows ESP 的 GPT PARTUUID 定位 Windows Boot Manager。用以下命令确认实际值，再修改 <code>hosts/nixos/hardware-configuration.nix</code> 中的 <code>windowsEfiPartuuid</code>：

~~~bash
lsblk -o PATH,SIZE,FSTYPE,LABEL,PARTUUID,PARTLABEL,MOUNTPOINTS
~~~

这里需要的是分区的 PARTUUID，不是文件系统 UUID。安装前还应备份 BitLocker 恢复密钥和重要数据；双启动设备建议在 Windows 中关闭“快速启动”，并在分区或修改启动密钥前暂停 BitLocker。

### 部署前必须检查

不要在未检查下列项目时直接部署：

1. 已替换默认密码哈希，并审阅主机名、用户名、Git 身份和 sops 接收者。
2. OpenSSH 已启用，而防火墙被关闭；目标网络和 SSH 认证策略必须可接受。
3. <code>master</code> 的 Disko 设备不再是 <code>/dev/disk/by-id/CHANGE_ME</code>，且确认目标磁盘允许被完全清除。
4. <code>laptop</code> 的磁盘标签和 Btrfs 子卷都已存在；此分支不会创建它们。
5. Windows ESP PARTUUID 与当前机器一致，Windows ESP 没有被误选为 Disko 目标。
6. 仅在匹配的 Lenovo 面板上启用 <code>laptop</code> EDID 覆盖。
7. 自定义启动安装钩子会更新 ESP 中的 Lanzaboote 和 rEFInd 文件，并在允许写入 EFI 变量时把 rEFInd 放到 UEFI BootOrder 首位。
8. 已准备可启动安装介质、完整备份，以及必要时的固件/BitLocker 恢复手段。

### 选择与验证分支

~~~bash
git clone https://github.com/luobolong/nixos-config.git
cd nixos-config

# 选择一种部署目标
git switch master
# 或
git switch laptop

nix flake check
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
~~~

如果修改了 <code>hostname</code>，把上面和后续命令中的 <code>nixos</code> 替换为新的 Flake 输出名。Flake 只会读取 Git 已跟踪或已加入索引的新文件；新增本地配置文件后，应明确执行 <code>git add 文件路径</code> 再验证。

### 安装步骤

以下流程假定安装介质以 UEFI 模式启动。先连接网络并确认当前环境：

~~~bash
sudo systemctl start NetworkManager
nmtui
test -d /sys/firmware/efi && echo UEFI || echo "不是 UEFI 模式"
~~~

#### master：使用 Disko 安装到新磁盘

> **警告：** 此流程会销毁 <code>hosts/nixos/disk-config.nix</code> 指向的整块磁盘。它不适用于在同一磁盘上保留现有 Windows 分区。当前 <code>master</code> 假定 Windows ESP 位于另一块不会被 Disko 操作的磁盘。

1. 查看稳定设备路径，按容量、型号和序列号反复确认目标磁盘：

   ~~~bash
   ls -l /dev/disk/by-id/
   lsblk -o PATH,SIZE,MODEL,SERIAL,FSTYPE,LABEL,PARTUUID,MOUNTPOINTS
   ~~~

2. 把 <code>hosts/nixos/disk-config.nix</code> 中的 <code>/dev/disk/by-id/CHANGE_ME</code> 改成确认过的完整 by-id 路径。默认布局是 2 GiB ESP、64 GiB swap，以及使用其余空间的 Btrfs 分区。

3. 再次检查配置，然后执行 Disko 的销毁、格式化与挂载模式：

   ~~~bash
   nix flake check
   sudo nix --experimental-features "nix-command flakes" run github:nix-community/disko/latest -- \
     --mode destroy,format,mount ./hosts/nixos/disk-config.nix
   findmnt -R /mnt
   ~~~

4. 确认 <code>/mnt</code>、<code>/mnt/nix</code>、<code>/mnt/home</code> 和 <code>/mnt/boot</code> 均来自目标磁盘后安装：

   ~~~bash
   sudo nixos-install --flake .#nixos --no-root-passwd
   sudo reboot
   ~~~

Disko 的上游 Quickstart 同样明确说明该流程会擦除磁盘，且不支持双启动布局；执行前请阅读 [Disko Quickstart](https://github.com/nix-community/disko/blob/master/docs/quickstart.md)。

#### laptop：在 Windows 磁盘的空闲空间中手工安装

此分支不会运行 Disko。它假定 Windows 已使用 UEFI/GPT，并只在预留的未分配空间中新增以下分区：

| 分区 | 大小 | 格式/标签 | 用途 |
|---|---:|---|---|
| NixOS ESP | 2 GiB | FAT32，<code>NIXBOOT</code> | <code>/boot</code> 与多个 UKI 代次 |
| Swap | 32 GiB | swap，<code>nixos-swap</code> | swap / resume |
| 系统分区 | 剩余空间 | Btrfs，<code>nixos</code> | root、nix、home 子卷 |

1. 找出目标磁盘，在 Windows 已释放的空闲空间中创建三个新分区。不要格式化 Windows ESP、MSR、系统或恢复分区：

   ~~~bash
   ls -l /dev/disk/by-id/
   lsblk -o PATH,SIZE,MODEL,FSTYPE,LABEL,PARTUUID,PARTLABEL,MOUNTPOINTS
   sudo cfdisk /dev/disk/by-id/DEVICE
   ~~~

2. 只格式化刚创建的三个新分区，把示例设备名替换为实际路径：

   ~~~bash
   sudo mkfs.fat -F 32 -n NIXBOOT /dev/NEW_ESP
   sudo mkswap -L nixos-swap /dev/NEW_SWAP
   sudo mkfs.btrfs -f -L nixos /dev/NEW_BTRFS
   ~~~

3. 创建配置需要的 Btrfs 子卷：

   ~~~bash
   sudo mount -o subvolid=5 /dev/disk/by-label/nixos /mnt
   sudo btrfs subvolume create /mnt/@root
   sudo btrfs subvolume create /mnt/@root/.snapshots
   sudo btrfs subvolume create /mnt/@nix
   sudo btrfs subvolume create /mnt/@home
   sudo btrfs subvolume create /mnt/@home/.snapshots
   sudo umount /mnt
   ~~~

4. 按配置挂载系统：

   ~~~bash
   sudo mount -o subvol=@root,compress=zstd,noatime /dev/disk/by-label/nixos /mnt
   sudo mkdir -p /mnt/nix /mnt/home /mnt/boot
   sudo mount -o subvol=@nix,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/nix
   sudo mount -o subvol=@home,compress=zstd,noatime /dev/disk/by-label/nixos /mnt/home
   sudo mount -o umask=0077 /dev/disk/by-label/NIXBOOT /mnt/boot
   sudo swapon /dev/disk/by-label/nixos-swap
   findmnt -R /mnt
   swapon --show
   ~~~

5. 临时挂载原有 Windows ESP，确认启动文件和 PARTUUID；不要在此步骤格式化它：

   ~~~bash
   sudo mkdir -p /mnt/windows-esp
   sudo mount /dev/WINDOWS_ESP /mnt/windows-esp
   test -f /mnt/windows-esp/EFI/Microsoft/Boot/bootmgfw.efi
   lsblk -no PARTUUID /dev/WINDOWS_ESP
   sudo umount /mnt/windows-esp
   ~~~

6. 将得到的 PARTUUID 写入 <code>hosts/nixos/hardware-configuration.nix</code>，确认标签和子卷无误后安装：

   ~~~bash
   ls -l /dev/disk/by-label/NIXBOOT
   ls -l /dev/disk/by-label/nixos-swap
   ls -l /dev/disk/by-label/nixos
   sudo btrfs subvolume list /mnt
   sudo nixos-install --flake .#nixos --no-root-passwd
   sudo reboot
   ~~~

两种安装方式的第一次重启都应暂时保持 Secure Boot 关闭。首次启动时才会自动生成本机签名密钥，初始 ESP 内容不一定已经全部签名。

### 应用配置

在已经运行 NixOS 的目标机器上：

~~~bash
sudo nixos-rebuild switch --flake .#nixos
~~~

如果只想生成下一次启动使用的系统，而不立即切换：

~~~bash
sudo nixos-rebuild boot --flake .#nixos
~~~

如果主机名已修改，请使用对应的 <code>.#新主机名</code>。每次重建都会运行自定义启动安装钩子，更新 Lanzaboote 与 rEFInd 文件。rEFInd 只显示两个手工条目：

- Windows Boot Manager。
- systemd-boot；由它选择 NixOS 系统代次。

### Secure Boot

配置启用了 Lanzaboote，并在 <code>/var/lib/sbctl</code> 自动生成签名密钥；固件密钥注册被刻意保留为手工操作。建议按以下顺序启用：

1. 保持 Secure Boot 关闭，完成首次 NixOS 启动。检查自动密钥服务和 sbctl 状态：

   ~~~bash
   systemctl status generate-sb-keys.service --no-pager
   sudo sbctl status
   ~~~

2. 密钥生成后再次构建启动项，并检查签名：

   ~~~bash
   sudo nixos-rebuild boot --flake .#nixos
   sudo sbctl verify
   ~~~

   Lanzaboote 使用 <code>/boot/EFI/Linux/nixos-generation-*.efi</code> 形式的签名 UKI。<code>sbctl verify</code> 仍可能列出未签名的原始 <code>/boot/EFI/nixos/kernel-*.efi</code>；判断时应重点确认实际启动的 UKI、systemd-boot 与 rEFInd 文件。

3. 重启进入固件设置，将 Secure Boot 切换到 Setup Mode。不同固件通常通过删除 Platform Key（PK）实现；不要清除 dbx 或笼统删除全部固件密钥。保留 BitLocker 恢复密钥和固件恢复方案。

4. 回到 Secure Boot 仍关闭但处于 Setup Mode 的 NixOS，注册本机密钥并保留 Microsoft 证书：

   ~~~bash
   sudo sbctl enroll-keys --microsoft
   ~~~

5. 再次进入固件启用 Secure Boot，启动 NixOS 后验证：

   ~~~bash
   bootctl status
   sudo sbctl status
   ~~~

保留 Microsoft 证书有助于 Windows Boot Manager 和部分硬件 Option ROM 继续启动。不要提交或备份到公共位置的 <code>/var/lib/sbctl</code> 私钥。Secure Boot 只验证启动链，不等同于磁盘加密；当前磁盘配置没有启用全盘加密。更多背景见 [Lanzaboote 安装指南](https://github.com/nix-community/lanzaboote/blob/master/docs/getting-started/prepare-your-system.md)。

### 首次登录检查

首次进入图形会话后建议逐项确认：

- 在 tuigreet 中分别启动一次 Hyprland 和 niri，确认登录、锁屏、退出及重登正常。
- 在对应会话运行 <code>hyprctl monitors</code> 或 <code>niri msg outputs</code>；<code>laptop</code> 还应确认内屏存在 2880×1800@120 Hz 模式。
- 使用 <code>journalctl -b -k | grep -Ei 'edid|displayid|amdgpu'</code> 检查 EDID 与 AMDGPU 日志。
- 用 <code>Ctrl + Space</code> 切换 Fcitx5/Rime，并用 <code>F4</code> 选择雾凇拼音方案；候选窗异常时可运行 <code>fcitx5 -r</code> 和 <code>fcitx5-configtool</code>。
- 检查 <code>systemctl --user --failed</code> 和 <code>systemctl --user status noctalia</code>，确认 Noctalia、Linux QQ 剪贴板同步等用户服务没有失败。
- 首次使用 Claude Code、Codex 或 Gemini CLI 前，在 CC Switch 中添加并启用对应的 API 供应商；配置本身不保存这些服务的令牌。
- 首次运行 <code>nvim</code>，让 AstroNvim 完成插件初始化。
- 再次确认 <code>sudo sbctl status</code>、Windows 启动项、音频、蓝牙、挂起与恢复。

### 日常维护

~~~bash
# 格式化 Nix 文件
nix fmt

# 完整 Flake 检查
nix flake check

# 只验证 Home Manager 生成
nix build .#nixosConfigurations.nixos.config.home-manager.users.ben.home.activationPackage --no-link

# 更新锁文件；提交前应审阅 flake.lock
nix flake update

# 查看新旧系统闭包差异
nix build .#nixosConfigurations.nixos.config.system.build.toplevel
nvd diff /run/current-system result
~~~

系统每周清理超过 7 天的旧 Nix store 代次并执行 store 优化。Snapper 为 <code>/</code> 和 <code>/home</code> 每小时创建时间线快照，保留 24 个小时、7 个日、4 个周和 6 个月快照。若修改了用户名或主机名，请同步替换上述属性路径。

### 数据与备份

root 与 Home 使用独立的持久化 Btrfs 子卷，<code>XDG_PROJECTS_DIR</code> 指向 <code>~/Workspace</code>。可用以下命令检查空间和快照：

~~~bash
sudo btrfs filesystem usage /
snapper -c root list
snapper -c home list
systemctl list-timers 'snapper-*'
~~~

Snapper 快照便于本机回滚，但不能替代异机备份。至少应单独备份用户数据、未提交的本地配置、<code>/var/lib/sbctl</code> Secure Boot 密钥，以及用于解密 sops secret 的主机 SSH Ed25519 私钥；这些私钥都不得进入公开仓库。

### 桌面与用户环境

| 类别 | 配置 |
|---|---|
| 会话 | tuigreet 可选择 Hyprland 或 niri |
| Shell | Zsh vi mode、共享历史、fzf、zoxide、eza、bat、lf |
| 提示符 | Starship，显示系统、目录、Git 状态和语言版本 |
| 终端 | Kitty，JetBrains Mono Nerd Font，Catppuccin Mocha，90% 透明度 |
| 文件管理器 | Dolphin + Kvantum，紧凑工具栏和右侧信息面板 |
| 启动器/栏/通知 | Noctalia；禁用 Mako 及旧式网络/蓝牙托盘自启动 |
| 输入法 | Fcitx5 + Rime Ice，横向候选框，每页 7 个候选词 |
| 主题 | Catppuccin Mocha Mauve、Papirus Dark、Adwaita 32 px 光标 |
| 编辑器 | AstroNvim 模板、绝对行号；VS Code 与 JetBrains IDE |
| 默认程序 | Kitty 终端、Dolphin 目录、Firefox 网页、VS Code 文本、Okular PDF、Gwenview 图片、mpv 音视频、Ark 压缩包 |
| 音频 | PipeWire 的 ALSA、32 位 ALSA 与 PulseAudio 兼容层 |
| Wayland | GTK portal、wl-clipboard、Satty、grim/slurp、nwg-displays |
| 网络代理 | Clash Verge 使用 service mode 与 TUN mode，默认不自动启动 |

常用桌面应用包括 Firefox、Spotify、QQ、LocalSend、OBS Studio、Mission Center、Pavucontrol、AudioMonitor、ChatGPT、Okular、Gwenview、Ark、VS Code、IntelliJ IDEA、DataGrip 和 GoLand。

开发与维护工具包括 GCC、CMake、Make、pkg-config、Node.js、Python、OpenJDK 25、Lua language server、nil、nixfmt、ShellCheck、Codex、Claude Code、DeepSeek Harness、sops、nh、nvd 和 nix-output-monitor。

系统字体覆盖 Inter、Source Serif、Noto CJK/Emoji、Sarasa Gothic、Cousine Nerd Font 和 JetBrains Mono Nerd Font。

### Hyprland 快捷键

#### 窗口、焦点与应用

| 快捷键 | 动作 |
|---|---|
| <code>Super + Q</code> / <code>Alt + F4</code> | 关闭活动窗口 |
| <code>Super + Alt + F4</code> | 强制终止活动窗口 |
| <code>Super + W</code> | 切换浮动 |
| <code>Super + Shift + W</code> | 设为浮动并切换置顶 |
| <code>Super + G</code> | 切换窗口组 |
| <code>Super + Ctrl + H/L</code> | 切换组内上一个/下一个窗口 |
| <code>Super + J</code> | 切换 Dwindle 分割方向 |
| <code>Super + D</code> / <code>Shift + F11</code> | 切换全屏 |
| <code>Super + M</code> | 切换最大化 |
| <code>Super + 方向键</code> | 按方向移动焦点 |
| <code>Super + Ctrl + Shift + 方向键</code> | 按方向移动窗口 |
| <code>Super + Shift + 方向键</code> | 以 50 px 步长缩放窗口 |
| <code>Super + 鼠标左键</code> / <code>Super + Z</code> | 拖动窗口 |
| <code>Super + 鼠标右键</code> / <code>Super + X</code> | 调整窗口大小 |
| <code>Alt + Tab</code> | 打开 Noctalia 窗口切换器 |
| <code>Super + L</code> | 使用 Hyprlock 锁屏 |
| <code>Super + Alt + Z</code> | 在 1× 与 2× 指针居中缩放之间切换 |
| <code>Super + Alt + 滚轮</code> | 以 0.25× 步长调整屏幕缩放 |
| <code>Super + T/E/C/B/F</code> | 打开 Kitty / Dolphin / VS Code / Firefox |
| <code>Ctrl + Shift + Escape</code> | 打开 Mission Center |
| <code>Super + A/V</code> | 打开 Noctalia 启动器 / 剪贴板 |
| <code>Super + /</code> | 打开可搜索的 Hyprland 命令面板 |

#### 工作区与手势

| 快捷键或手势 | 动作 |
|---|---|
| <code>Super + 1..9/0</code> | 切换到工作区 1..9/10 |
| <code>Super + Shift + 1..9/0</code> | 把窗口移到工作区并跟随 |
| <code>Super + Ctrl + Down</code> | 切换到空工作区 |
| <code>Super + Ctrl + Left/Right</code> | 切换到前一个/后一个相对工作区 |
| <code>Super + Alt + Ctrl + Left/Right</code> | 把窗口移到相对工作区并跟随 |
| <code>Super + 外接鼠标滚轮</code> | 在已有工作区之间切换；触控板不触发 |
| <code>Super + S</code> | 切换特殊工作区 S |
| <code>Super + Shift + S</code> | 把窗口移到 S 并跟随 |
| <code>Super + Alt + S</code> | 把窗口静默移到 S |
| 三指水平滑动 | 一次切换一个工作区 |
| 四指滑动 | 拖动活动窗口 |
| 四指捏合 / 张开 | 取消最大化 / 切换最大化 |

#### 截图

| 快捷键 | 动作 |
|---|---|
| <code>Super + Shift + P</code> | 取色并复制 |
| <code>Super + P</code> | 选区截图 |
| <code>Super + Ctrl + P</code> | 冻结画面后选区截图 |
| <code>Super + Alt + P</code> | 当前输出截图 |
| <code>Print</code> | 全部输出截图 |

截图保存到 XDG 图片目录的 <code>Screenshots</code> 子目录，并在 Satty 中打开。

音量增加、降低、静音和亮度键在锁屏时仍可用；音量与亮度按 5% 调整，并支持按住重复。

### niri 快捷键

#### 窗口、方向操作与显示器

| 快捷键 | 动作 |
|---|---|
| <code>Super + Q</code> / <code>Alt + F4</code> | 关闭窗口 |
| <code>Super + W</code> | 切换浮动 |
| <code>Super + Shift + V</code> | 在浮动层和平铺层之间切换焦点 |
| <code>Super + Shift + F</code> / <code>Super + F11</code> | 切换全屏 |
| <code>Super + F</code> | 最大化列 |
| <code>Super + M</code> | 将窗口最大化到可用边缘 |
| <code>Super + Backslash</code> | 切换列标签显示 |
| <code>Super + Alt + L</code> | 使用 Noctalia 锁屏 |
| <code>Alt + Tab</code> | niri 原生最近窗口切换 |
| <code>Super + Tab</code> | 返回上一个工作区 |
| <code>Super + Escape</code> | 切换快捷键抑制 |
| <code>Super + Shift + E</code> | 退出 niri |
| <code>Super + 方向键</code> | 浮动窗口移动 50 px；平铺窗口按方向切换焦点 |
| <code>Super + H/J/K/L</code> | 按方向切换焦点 |
| <code>Super + Ctrl + 方向键</code> / <code>Super + Ctrl + H/J/K/L</code> | 左右移动列或上下移动列内窗口 |
| <code>Super + Shift + 方向键</code> | 浮动窗口缩放 50 px；平铺窗口按方向切换显示器 |
| <code>Super + Shift + H/J/K/L</code> | 按方向切换显示器 |
| <code>Super + Ctrl + Shift + 方向键</code> / <code>H/J/K/L</code> | 把列移到对应显示器 |

智能方向脚本会先读取焦点窗口类型。对浮动窗口执行移动或缩放时，它使用同一次查询捕获的窗口 ID，避免焦点在 IPC 请求之间变化时误操作其他窗口。

#### 动态工作区与滚动布局

| 快捷键 | 动作 |
|---|---|
| <code>Super + 1..9/0</code> | 聚焦动态索引 1..9/10 |
| <code>Super + Shift + 1..9/0</code> | 把当前列移到对应索引 |
| <code>Super + PageDown/PageUp</code> / <code>Super + U/I</code> | 聚焦下一个/上一个工作区 |
| <code>Super + Ctrl + PageDown/PageUp</code> / <code>Super + Ctrl + U/I</code> | 把列移到相邻工作区 |
| <code>Super + Shift + PageDown/PageUp</code> / <code>Super + Shift + U/I</code> | 重排当前工作区 |
| <code>Super + 滚轮</code> | 切换工作区 |
| <code>Super + Ctrl + 滚轮</code> | 把列移到相邻工作区 |
| <code>Super + O</code> | 切换概览 |
| <code>Super + R</code> / <code>Super + Shift + R</code> | 正向/反向循环预设列宽 |
| <code>Super + Ctrl + R</code> | 重置窗口高度 |
| <code>Super + -/=</code> | 以 10% 调整列宽 |
| <code>Super + Shift + -/=</code> | 以 10% 调整窗口高度 |
| <code>Super + [/]</code> | 向左/右并入或弹出窗口 |
| <code>Super + ,/.</code> | 并入右侧窗口 / 弹出列底部窗口 |
| <code>Super + Home/End</code> | 聚焦第一列/最后一列 |
| <code>Super + Ctrl + Home/End</code> | 把列移到最前/最后 |
| <code>Super + G</code> / <code>Super + Ctrl + G</code> | 居中当前列 / 居中完整可见列 |
| <code>Super + Ctrl + F</code> | 把列扩展到剩余宽度 |
| <code>Super + Shift + /</code> | 显示 niri 快捷键覆盖层 |

应用启动和截图快捷键与 Hyprland 基本一致：<code>Super + T/E/C/B</code>、<code>Super + A/V</code>、<code>Ctrl + Shift + Escape</code> 以及同一组 <code>P</code>/<code>Print</code> 截图键。niri 另外配置了麦克风静音、Playerctl 播放控制和锁屏状态下可用的媒体/亮度键。

### 运行时生成的配置

- Noctalia 写入 <code>~/.config/niri/noctalia.kdl</code>。
- nwg-displays 写入 <code>~/.config/niri/monitor.kdl</code>，以及 Hyprland 的 monitor/workspace Lua 模块。
- Home Manager 首次激活时会创建 niri 的两个可写 include 文件，但主 <code>config.kdl</code> 仍由声明式配置管理。
- Rime Ice 以可写副本同步到用户数据目录，以便 Fcitx5 生成编译产物。
- Linux QQ 剪贴板同步作为图形会话内的 systemd user service 运行。
- sops-nix 运行时使用主机 SSH Ed25519 密钥作为 Age 密钥来源；<code>.sops.yaml</code> 为 <code>secrets/*.yaml</code> 声明 GPG 与 Age 接收者，但仓库当前没有具体 secret 文件。
- <code>/var/lib/sbctl</code> 保存本机 Secure Boot 私钥，必须纳入安全离线备份，但不能提交到仓库。

### 许可证

MIT
