# NixOS Hyprland / niri 工作站

一套可以直接放到 GitHub 管理的 NixOS 配置。它使用 Flakes、Home Manager、Disko 和 Btrfs，提供 Hyprland 与 niri 两套 Noctalia v5 桌面（在登录界面自由选择）、雾凇拼音和常用桌面/开发软件。

> [!WARNING]
> 安装命令会**清空目标磁盘的全部数据**。执行 Disko 前，务必备份数据并反复确认磁盘的 `/dev/disk/by-id/...` 路径。不要使用容易变化的 `/dev/sda` 或 `/dev/nvme0n1`。

## 包含内容

- NixOS unstable + Flakes
- Home Manager
- Disko + GPT + UEFI
- Btrfs：`@root`、`@nix`、`@home` 分别挂载到 `/`、`/nix`、`/home`，并使用 Zstd 压缩
- Snapper：分别为 `/` 和 `/home` 自动创建快照，并按小时、天、周、月清理
- rEFInd（10 秒）→ systemd-boot（2 秒）→ Lanzaboote UKI；支持 UEFI Secure Boot，最多保留 10 个系统代次
- 每周自动清理 7 天前的 Nix 代次，并优化 Nix Store
- Hyprland（UWSM 会话，Lua 配置）与 niri（滚动平铺，KDL 配置）+ Noctalia v5
- greetd + tuigreet 登录界面
- Kitty（Wayland 模糊背景）+ Zsh + Starship 提示符
- NetworkManager、蓝牙、PipeWire
- Fcitx5 + Rime + rime-ice（雾凇拼音）+ Catppuccin Mocha Sapphire 皮肤
- Inter、Source Serif 4、Noto CJK/Emoji、Sarasa Gothic 字体 + Papirus Dark 图标主题 + Adwaita 32px 鼠标主题
- Dolphin、Fastfetch、Mission Center、btop、Fuzzel（Catppuccin Mocha）、Satty、Hyprlock、Neovim + AstroNvim v5、VS Code、IntelliJ IDEA Ultimate、DataGrip、GoLand、Claude Code、Codex、Spotify、QQ、FlClash
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
│   └── hardware-configuration.nix
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
├── secrets/
│   └── claude-code.yaml
└── packages/
    └── flclash.nix
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

### 3. 调整 Swap 大小

默认 Swap 分区与本机 64 GiB 内存等大，并作为休眠恢复设备。可在 `hosts/nixos/disk-config.nix` 中修改：

```nix
size = "64G";
```

若机器内存容量不同，请将 Swap 的 `size` 改为不小于实际内存的值。休眠 Swap 未启用随机加密，因为随机密钥会在重启后丢失，导致无法恢复休眠镜像。

### 4. 确认 Windows ESP

rEFInd 的 Windows 条目使用 ESP 的 GPT 分区 UUID，当前配置位于 `hosts/nixos/default.nix`：

```nix
windowsEfiPartuuid = "991a77db-c316-4f75-b9df-bc05e179a798";
```

如果 Windows ESP 发生变化，使用 `lsblk -o PATH,FSTYPE,PARTUUID,PARTLABEL` 找到包含 Windows Boot Manager 的 FAT 分区，并同步修改这个值。

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

执行 Disko：

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --root-mountpoint /mnt \
  ./hosts/nixos/disk-config.nix
```

确认结果中 `/mnt`、`/mnt/nix`、`/mnt/home` 和 `/mnt/boot` 都已挂载：

```bash
findmnt -R /mnt
```

### 6. 安装 NixOS

默认主机名为 `nixos`：

```bash
sudo nixos-install --flake .#nixos --no-root-passwd
```

如果你修改了 `hostname`，把 `#nixos` 换成新名称。

配置已经声明 `ben` 和 `root` 的初始登录密码均为单字母 `q`，不需要再进入安装目标执行 `passwd`。然后重启：

```bash
sudo reboot
```

拔掉安装 U 盘后，应先看到只包含 `systemd-boot` 和 `Windows` 的 rEFInd 菜单；选择带 NixOS 图标的 `systemd-boot` 后，再选择 NixOS 系统代次。首次登录在 tuigreet 中输入用户名 `ben`、密码 `q`，并选择 Hyprland 或 niri 会话（tuigreet 会记住上次选择）。此时先保持固件 Secure Boot 关闭，首次启动的 rEFInd 和 UKI 尚未签名。

## 首次登录

### Claude Code

Claude Code 默认连接 `https://openapi.troncode.cn`，并通过 `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1` 关闭非必要流量。`ANTHROPIC_AUTH_TOKEN` 不会写入 Nix store 或全局会话环境：`claude` 启动器只在运行时从 `/run/secrets/claude-code-auth-token` 读取它。

当获得真实令牌后，编辑 SOPS 密文：

```bash
sops secrets/claude-code.yaml
```

把解密后的占位值替换为真实的 `sk-...`，保存后磁盘上仍只保留密文。然后应用配置：

```bash
sudo nixos-rebuild switch --flake .#nixos
```

如果密文文件尚未加入 Git，运行 Flake 命令前先执行 `git add .sops.yaml modules/secrets.nix secrets/claude-code.yaml`。

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

### Noctalia

Noctalia 作为用户服务随桌面（Hyprland 或 niri）启动。它的图形设置保存在 `~/.config/noctalia`。检查服务：

```bash
systemctl --user status noctalia
```

### FlClash

FlClash 使用官方 x86_64 AppImage 发行包封装，版本、SHA-256 和额外运行库已在 `packages/flclash.nix` 中固定。配置目录是 `~/.local/share/com.follow.clash`。

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
| `Super + L` | 使用 Hyprlock 锁定屏幕 |
| `Shift + F11` / `Super + D` | 切换全屏 |
| `Super + Shift + W` | 切换窗口置顶；平铺窗口会先转为浮动 |
| `Super + J` | 切换 Dwindle 分割方向 |
| `Super + Ctrl + H` / `Super + Ctrl + L` | 向后 / 向前切换活动分组 |
| `Super + 方向键` | 向对应方向切换焦点 |
| `Alt + Tab` | 打开 Noctalia 窗口总览；连续按键切换选择，松开 `Alt` 确认 |
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
| `Super + Alt + T` | 切换下拉 Kitty 终端 |
| `Super + E` | 打开文件管理器 |
| `Super + C` | 打开 VS Code |
| `Super + B` | 打开 Firefox |
| `Ctrl + Shift + Escape` | 打开 Mission Center；终端中也可运行 `btop` |
| `Super + A` | 打开 Noctalia 应用启动器 |
| `Super + V` | 打开 Noctalia 剪贴板 |
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
| `Super + Alt + L` | 使用 Hyprlock 锁定屏幕；锁屏器异常退出后仍可再次调用 |
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

Hyprland 与 niri 共用 `hypr-screenshot` 脚本，截图后都会打开 Satty 进行标注、复制或保存。两套会话也共用闲置策略：闲置 5 分钟自动锁屏，5 分 30 秒关闭显示器；恢复输入时自动点亮，并在系统睡眠前锁屏。

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
- [Disko](https://github.com/nix-community/disko)
- [Lanzaboote](https://github.com/nix-community/lanzaboote)
- [Noctalia v5](https://github.com/noctalia-dev/noctalia)
- [rime-ice](https://github.com/iDvel/rime-ice)
- [AstroNvim Template](https://github.com/AstroNvim/template)
- [FlClash](https://github.com/chen08209/FlClash)
