**本机教程：从 64 GiB swap 分区迁移到 Btrfs swapfile，并配置休眠**

适用仓库：`/home/ben/nixos-config`，分支：`master`，主机：台式机 `nixos`。检查日期：2026-09-09。

`laptop` 分支保留 32 GiB 的 `/dev/disk/by-label/nixos-swap` 分区，未启用本文的 swapfile 配置。下文磁盘标识、UUID、容量及分区操作仅对应台式机，不适用于笔记本。

本文按这台机器的实际配置编写。目标是使用 `/swap/swapfile` 进行交换和休眠。以下第 1 步记录迁移前的状态；后续用户已完成验证，复查也确认新配置已启动、64 GiB swapfile 已启用。回收旧分区空间可选择第 13 步的离线移动，或在满足容量等条件时采用第 14 步的在线设备迁移。

**设备名会在重启后变化。** 本机重启后 NixOS 系统盘已从 `nvme0n1` 变为 `nvme1n1`，Windows 盘则变为 `nvme0n1`。下文迁移前表格中的设备名仅作历史记录；实际操作必须按稳定设备路径、分区标签和 UUID 重新识别。

**1. 当前状态与迁移结果**

| 项目 | 本机检查结果 |
|---|---|
| 旧 swap 分区 | `/dev/nvme0n1p2`，64 GiB |
| 旧分区稳定路径 | `/dev/disk/by-partlabel/disk-main-swap` |
| 旧分区 UUID | `314385cf-5091-47e6-84f4-ae2f8f832ad1` |
| 系统分区 | `/dev/nvme0n1p3`，Btrfs，标签 `nixos` |
| 系统分区 UUID | `4b1afa78-d632-4509-b6af-a2bce080a0b6` |
| 内存 | 64 GiB 物理内存，系统可见约 60 GiB |
| 系统分区可用空间 | 检查时约 1.8 TiB |
| 当前启用的 swap | 无；旧分区已停用，新文件尚未创建 |
| 当前错误配置 | `/etc/fstab` 仍引用不存在的 `//swapfile` |
| 启动环境 | UEFI、systemd 261.2、Lanzaboote，Secure Boot 已启用 |
| 当前运行内核 | 7.2.3；已构建的新系统使用 7.2.4 |
| 当前启动参数 | 仍含 `resume=/dev/disk/by-partlabel/disk-main-swap` |

目标布局：

```text
/dev/nvme0n1
├─p1  ESP                         保持现状
├─p2  64 GiB 旧 swap 分区          停用，暂时保留
└─p3  Btrfs 系统分区
     ├─@root                     /
     │  └─swap                   /swap，独立的嵌套子卷
     │     └─swapfile             /swap/swapfile，64 GiB
     ├─@nix                      /nix
     └─@home                     /home
```

这里的“迁移”是更换系统使用的交换空间，无需把旧分区内容复制到新文件。请在正常运行的系统里操作；如果此前已经休眠，先恢复该会话。

**2. 为什么原来的 switch 会失败**

Disko 中的 `swap.swapfile.size = "64G"` 用于运行 Disko 安装流程时创建文件。普通的 `nixos-rebuild switch` 会更新 swap 配置，却不会执行 Disko 的磁盘创建脚本。因此配置要求启动 `/swapfile`，实际文件却不存在。

修复使用 NixOS 的 `swapDevices[].size`，由系统服务在启动或切换时创建文件。当前锁定的 nixpkgs 会识别 Btrfs，并调用 `btrfs filesystem mkswapfile`。[对应的 NixOS 实现](https://github.com/NixOS/nixpkgs/blob/d6524aaca2ff07876657ae2b323f24be4874944b/nixos/modules/config/swap.nix)

此外，启用中的 swapfile 会阻止包含它的 Btrfs 子卷创建快照。你的 Snapper 会对 `/` 创建快照，所以文件放在独立的 `/swap` 子卷里；不能直接放到 root 子卷的 `/swapfile`。[Btrfs swapfile 限制](https://btrfs.readthedocs.io/en/latest/ch-swapfile.html)

本次迁移直接使用现有 Btrfs 文件系统。**不要运行 Disko 的 `destroy`、`format` 安装流程，也不要对现有系统分区执行 `mkfs`。**

**3. 保存配置并检查休眠条件**

在本机终端执行：

```bash
cd /home/ben/nixos-config
migration_backup="$HOME/swap-migration-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$migration_backup"
cp hosts/nixos/disk-config.nix hosts/nixos/hardware-configuration.nix "$migration_backup/"
git diff HEAD -- hosts/nixos/disk-config.nix hosts/nixos/hardware-configuration.nix > "$migration_backup/config-changes.patch"
swapon --show
free -h
df -h /
```

这份备份保存的是当前工作区，其中已经包含待应用的修复；不是“旧 swap 分区配置”的自动回退点。恢复旧分区的方法见第 11 步。

检查启动和内核能力：

```bash
sudo bootctl status --no-pager
findmnt -no FSTYPE,OPTIONS /sys/firmware/efi/efivars
cat /sys/power/state
cat /sys/power/disk
sudo cat /sys/kernel/security/lsm
if test -e /sys/kernel/security/lockdown; then
  sudo cat /sys/kernel/security/lockdown
fi
```

本次检查中，`efivarfs` 为 `rw`，`/sys/power/state` 包含 `disk`，`/sys/power/disk` 为 `[platform] shutdown reboot suspend test_resume`。当前 LSM 列表没有 `lockdown`，对应状态文件也不存在；目前没有观察到 lockdown 阻止休眠。

**Secure Boot 已启用不代表本机一定禁止休眠，也不代表休眠一定可用。** 如果后续内核启用了 lockdown，且 `/sys/power/disk` 显示 `[disabled]`，需要先排查内核限制；增加 swap 或修改 offset 不能解决这类问题。内核明确检查 `LOCKDOWN_HIBERNATION`。[Linux 休眠能力检查](https://github.com/torvalds/linux/blob/master/kernel/power/hibernate.c)

重启到新内核后，应再执行一次上述检查。本文不需要修改你的 Secure Boot、签名密钥或 LSM 设置。

**4. 核对 NixOS 配置**

下面的设置已写入 [hardware-configuration.nix](../hosts/nixos/hardware-configuration.nix)。这是配置片段，不是整个文件；核对即可，不要重复追加同名属性。文件顶部函数参数需要包含 `pkgs`。

```nix
swapDevices = [
  {
    device = "/swap/swapfile";
    size = 64 * 1024; # 单位 MiB，即 64 GiB
  }
];

systemd.services.mkswap-swap-swapfile.preStart = ''
  if [ ! -e /swap ]; then
    ${pkgs.btrfs-progs}/bin/btrfs subvolume create /swap
  fi
  ${pkgs.btrfs-progs}/bin/btrfs subvolume show /swap > /dev/null
  chmod 0700 /swap
'';

boot.initrd.systemd.enable = true;
```

初始化服务先创建并核验 `/swap` 子卷，随后由 NixOS 创建 swapfile。若 `/swap` 已经是普通目录，服务会停止，以免误把 swapfile 放进 root 子卷。

[disk-config.nix](../hosts/nixos/disk-config.nix) 中已经取消直接创建 root swapfile，并声明了 `"@root/swap" = { };`，供以后全新安装时创建子卷。当前安装的子卷由上述服务补齐。

64 GiB 是本机的初始容量选择。休眠还取决于实际可用 swap 和内存负载；容量等于物理内存不意味着所有负载下都保证成功。首次测试时先关闭虚拟机、大型编译等高内存任务。

**本机采用自动记录休眠位置的方式：** 保留 systemd initrd，移除固定的 `boot.resumeDevice` 和 `resume_offset=`。systemd 在休眠时选择 swap、记录设备与 offset，并通过 UEFI 的 `HibernateLocation` 让 initrd 在下次启动时找到映像。现有仓库已采用这一设置。[systemd 休眠写入实现](https://github.com/systemd/systemd/blob/main/src/sleep/sleep.c)、[恢复生成器文档](https://github.com/systemd/systemd/blob/main/man/systemd-hibernate-resume-generator.xml)

自动方式依赖可写的 EFI 变量和正确的启动环境。如果实际测试发现固件不支持可靠保存变量，再使用第 10 步的显式配置。

**5. 构建、应用并验证 swapfile**

核对最终启用的 swap 列表：

```bash
cd /home/ben/nixos-config
nix eval --json .#nixosConfigurations.nixos.config.swapDevices \
  --apply 'devices: map (d: { inherit (d) device size; }) devices'
```

预期只有：

```json
[{"device":"/swap/swapfile","size":65536}]
```

然后构建并应用：

```bash
nix build .#nixosConfigurations.nixos.config.system.build.toplevel --no-link
sudo nixos-rebuild switch --flake .#nixos
```

遇到失败先处理错误，不要继续重启。成功后检查：

```bash
swapon --show --output NAME,TYPE,SIZE,USED,PRIO
systemctl is-active swap-swapfile.swap
sudo btrfs subvolume show /swap
sudo stat -c '%a %U:%G %s %n' /swap/swapfile
sudo lsattr /swap/swapfile
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
```

判断标准：

- swap 列表中有 `/swap/swapfile`，类型为 `file`，大小约 64 GiB。
- `swap-swapfile.swap` 返回 `active`。
- `btrfs subvolume show` 成功，说明 `/swap` 是子卷。
- 文件权限为 `600 root:root`，文件大小为 `68719476736` 字节。
- `lsattr` 包含 `C`，表示 NOCOW。
- `map-swapfile -r` 成功输出一个整数。自动方式下无需把这个数字写入配置。

`map-swapfile` 同时检查文件是否符合 Btrfs swapfile 的要求。Btrfs 的休眠偏移不能直接使用 `filefrag` 输出的物理偏移。[Btrfs 映射命令](https://btrfs.readthedocs.io/en/latest/btrfs-inspect-internal.html)

`mkswap-swap-swapfile.service` 是一次性初始化服务，成功后显示 `inactive (dead)` 可以是正常现象；持续运行状态应检查 `.swap` 单元。

如果 `swapon --show` 中还出现旧分区，先确认新文件已启用且有足够空间，再执行：

```bash
sudo swapoff /dev/disk/by-partlabel/disk-main-swap
swapon --show
```

旧分区已经停用时，跳过这条 `swapoff`。不要用 `swapoff -a` 同时停用新文件。若 `swapoff` 因内存不足失败，先降低内存负载再重试，不要删除分区。

**6. 确认 Snapper 仍可创建根快照**

在 swapfile 保持启用时执行：

```bash
sudo snapper -c root create --description 'swapfile migration verification' --print-number
sudo snapper -c root list
```

成功创建快照说明此次迁移没有阻止 root 快照。记录新快照的编号，之后可按需删除这个测试快照。

`/swap` 是嵌套子卷，没有单独挂载，所以 `findmnt -T /swap` 仍可能显示根挂载的 `@root`；这不表示它是普通目录，应以 `btrfs subvolume show /swap` 为准。

根快照不备份 swap 子卷的数据。以后恢复根快照时，需要保留或重新准备 `/swap` 子卷；如果恢复后留下的是普通目录，初始化服务会拒绝继续，按第 12 步检查。

**7. 先正常重启到新配置**

```bash
sudo reboot
```

本机本次检查时，正在运行的内核是 7.2.3，新系统是 7.2.4，且当前启动参数仍指向旧 swap 分区。`switch` 不会更换正在运行的内核，也不会改写 `/proc/cmdline`，所以不要直接在旧启动状态下测试新休眠方案。

重启后进入最新的 NixOS 代次，检查：

```bash
uname -r
readlink -f /run/booted-system
readlink -f /run/current-system
cat /proc/cmdline
swapon --show
cat /sys/power/disk
```

如果期间没有再次切换配置，`booted-system` 和 `current-system` 应指向同一代次。自动方式下，启动参数中不应再有旧分区的 `resume=`、固定的 `resume_offset=` 或禁止恢复的 `noresume`。swapfile 应在启动后自动启用。

自动方式下，普通冷启动后 `/sys/power/resume` 为 `0:0`、`resume_offset` 为 `0` 不一定是错误；位置可由 systemd 在休眠时写入。同样，不要求普通运行期间一直存在 `HibernateLocation` 变量。[systemd 休眠处理](https://github.com/systemd/systemd/blob/main/src/sleep/sleep.c)

**8. 检查是否允许休眠，再实际测试恢复**

先查询能力，不会让机器休眠：

```bash
busctl call org.freedesktop.login1 /org/freedesktop/login1 \
  org.freedesktop.login1.Manager CanHibernate
```

`s "yes"` 表示当前用户可请求休眠；`s "challenge"` 表示需要认证；`s "no"` 或 `s "na"` 需要先排查权限或系统条件。本次迁移前查询为 `s "na"`，当时没有可用 swap，不能据此认定硬件不支持。[logind 接口定义](https://github.com/systemd/systemd/blob/main/man/org.freedesktop.login1.xml)

先保存工作。在一个终端里记录当前 boot ID，然后执行休眠：

```bash
mkdir -p "$HOME/.cache"
cat /proc/sys/kernel/random/boot_id > "$HOME/.cache/swapfile-hibernate-test.boot-id"
systemctl hibernate
```

机器应写入休眠映像并关机。按电源键重新开机，选择**刚才休眠时使用的同一个 NixOS 代次**。恢复后，桌面、终端和原进程应继续存在。

不要在 NixOS 已休眠后进入另一个系统写入它休眠时挂载的文件系统。你的机器还会使用 Windows、NTFS 和 exFAT 数据盘，这一点尤其需要注意。[Linux 休眠文档](https://docs.kernel.org/power/swsusp.html)

恢复后核对：

```bash
diff -u "$HOME/.cache/swapfile-hibernate-test.boot-id" /proc/sys/kernel/random/boot_id
sudo journalctl -b -k --no-pager | rg -i 'hibernation|swsusp|PM:.*image'
sudo journalctl -b -u systemd-hibernate.service --no-pager
swapon --show
```

boot ID 相同、原进程仍在，并且日志显示休眠进入和退出，才算完成了一次恢复验证。仅看到正常的开机登录界面不能证明恢复成功，部分桌面会在冷启动后自动重新打开应用。

若变成了全新启动，检查本次启动的恢复日志，以及上一次启动的休眠日志：

```bash
sudo journalctl -b --no-pager | rg -i 'hibernate|hibernation|resume|HibernateLocation'
sudo journalctl -b -1 -u systemd-hibernate.service --no-pager
```

建议再做一次正常重启和一次休眠恢复，确认行为可重复后，再考虑处置旧分区。

**9. 旧 64 GiB 分区如何处理**

完成上述步骤后，交换和休眠已可以使用文件；旧分区仍保留在磁盘上，但不再作为 swap 使用。

停用旧分区不会把它的 64 GiB 自动归还给 Btrfs。新文件实际占用系统分区的另外 64 GiB，所以保留旧分区期间，两处空间都会被占用。

当前布局中，旧 swap 分区 `p2` 位于系统分区 `p3` 前面。即使删除 `p2`，空闲空间也在 Btrfs 分区前端，不能靠执行 `btrfs filesystem resize max /` 自动并入。

如果只是希望使用可调大小的 swapfile，到这里即可保留旧分区作为回退。若要合并空间，可以离线移动原分区；也可以在空间足够时，通过 Btrfs 在线设备迁移，把数据先迁到前面的分区，再向后扩容。两者都需要先确认实际布局和备份。在线迁移不等于直接修改正在使用的分区的起始扇区，具体区别见第 14 步。

**10. 备用：显式指定休眠设备和 resume_offset**

只有自动方式的实际恢复失败，且排查指向 EFI 变量问题时，再考虑此方案。它不能绕过内核 lockdown，也不能修复驱动恢复故障。

先保证 `/swap/swapfile` 已创建并启用，然后读取本机实际 offset：

```bash
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
readlink -f /dev/disk/by-uuid/4b1afa78-d632-4509-b6af-a2bce080a0b6
```

第二条应指向当前承载文件的系统分区。把第一条输出的整数填入以下配置；`YOUR_ACTUAL_OFFSET` 是占位符，必须替换：

```nix
boot.initrd.systemd.enable = true;
boot.resumeDevice = "/dev/disk/by-uuid/4b1afa78-d632-4509-b6af-a2bce080a0b6";
boot.kernelParams = [ "resume_offset=YOUR_ACTUAL_OFFSET" ];
```

如果文件内已有 `boot.kernelParams`，把参数加入已有列表，不要定义同名属性两次。`boot.resumeDevice` 指向的是**承载 swapfile 的 Btrfs 分区**，不是 `/swap/swapfile`，也不是 swapfile 内部的 swap UUID。

应用并重启：

```bash
sudo nixos-rebuild switch --flake .#nixos
sudo reboot
```

重启后核对 `cat /proc/cmdline`、`cat /sys/power/resume_offset` 与实际 `map-swapfile -r` 的输出，再重复第 8 步。

**只写 `boot.resumeDevice` 而不写正确 offset 是不完整的文件休眠配置。** offset 默认是 0，不是系统自动寻找任意文件的开关。[systemd 恢复参数](https://github.com/systemd/systemd/blob/main/man/systemd-hibernate-resume-generator.xml)

重建、移动、调整 swapfile 大小，或在停用期间执行可能移动文件区块的维护操作后，都应重新读取 offset；显式配置需要随之更新并重启。Btrfs 必须使用 `map-swapfile -r` 获取合适的偏移值。[Btrfs 映射说明](https://btrfs.readthedocs.io/en/latest/btrfs-inspect-internal.html)

**11. 回退到旧 swap 分区**

只要旧分区没有删除或重新格式化，就可以回退。若当前只是缺少可用 swap，且旧分区尚未启用，可先临时恢复它：

```bash
sudo swapon /dev/disk/by-partlabel/disk-main-swap
swapon --show
```

不要对旧分区执行 `mkswap`，它已有 swap 签名。临时 `swapon` 不会修改 NixOS 的持久配置。

要持久回退，在 `hardware-configuration.nix` 中把文件版 `swapDevices` 替换为：

```nix
swapDevices = [
  { device = "/dev/disk/by-partlabel/disk-main-swap"; }
];

boot.initrd.systemd.enable = true;
boot.resumeDevice = "/dev/disk/by-partlabel/disk-main-swap";
```

同时删除 `systemd.services.mkswap-swap-swapfile.preStart`，并移除为文件设置的任何 `resume_offset=`。保留其他无关的内核参数。如果此前已经有 `boot.resumeDevice`，替换其值即可。

随后执行：

```bash
sudo nixos-rebuild switch --flake .#nixos
swapon --show
sudo reboot
```

重启后确认旧分区已经启用，swapfile 没有启用，再验证休眠。未使用的 `/swap` 子卷和文件可以先保留，不必在回退过程中立即删除。

此处恢复的是现有主机的运行配置；Disko 文件仍描述未来安装时的文件方案。若以后也希望新安装重新创建独立 swap 分区，需要再同步调整 Disko 布局。

**12. 常见问题与后续维护**

| 现象 | 检查与处理 |
|---|---|
| 仍报 `/swapfile` 不存在 | 看 `/etc/fstab` 是否仍是旧路径；确认在正确仓库执行 switch，并核对最终 `swapDevices`。不要手改生成的 fstab。 |
| `mkswap-swap-swapfile.service` 失败 | 查看 `sudo journalctl -b -u mkswap-swap-swapfile.service --no-pager`，确认 `/swap` 是子卷、磁盘空间充足。 |
| `swapon: Invalid argument` | 运行 `map-swapfile`，再检查 `sudo journalctl -b -k --no-pager` 中的 Btrfs/swapfile 错误。不要直接重建文件覆盖现场。 |
| 提示内存或 swap 空间不足 | 检查 `free -h` 和 `swapon --show`，降低负载；不要仅绕过 systemd 的内存检查。 |
| `CanHibernate` 为 `na` 或 `no` | 检查 swap 是否启用、`/sys/power/disk`、logind 日志、sleep 配置及权限。 |
| `/sys/power/disk` 显示 `[disabled]` | 检查新内核的 lockdown 和日志；这不是缺少 offset 的表现。 |
| 能关机但不能恢复会话 | 检查是否选择同一 NixOS 代次、旧 `resume=` 是否已清除、EFI 变量错误或显式 offset 是否匹配。 |
| 恢复后黑屏或设备异常 | 查看内核日志中的 AMDGPU、ACPI 和设备恢复错误；先区分显像问题与实际冷启动。 |
| 初始化服务 inactive | 一次性服务可以成功后退出；以 `swap-swapfile.swap` 和 `swapon --show` 为准。 |

如果 `/swap` 是普通目录，先用 `sudo ls -la /swap` 查看内容。如果只是空目录，可以执行 `sudo rmdir /swap`，然后重新运行 `sudo nixos-rebuild switch --flake .#nixos` 让服务创建子卷。`rmdir` 会拒绝删除非空目录；若里面已有文件，应先查清来源和使用状态。

如果当前确实完全没有 `/swap`，也可以手工执行与配置相同的创建过程，再运行 switch。以下是排查时的备用操作，不需要在正常自动创建前执行：

```bash
sudo btrfs subvolume create /swap
sudo chmod 0700 /swap
sudo btrfs filesystem mkswapfile --size 64G /swap/swapfile
sudo nixos-rebuild switch --flake .#nixos
```

以后调整大小时，先确保已正常恢复所有休眠会话，停用 `swap-swapfile.swap`，修改 `swapDevices[].size`，再让初始化服务重新创建文件并启用 swap。当前 nixpkgs 在检测到大小不符时会重新创建文件；所以不能把修改 `size` 当成对正在使用的文件进行在线扩容。若停用失败，应先解决内存负载问题。

活动 swapfile 也会影响 Btrfs balance、scrub 和缩容等操作。独立子卷解决的是快照隔离，并没有把文件移到另一个物理文件系统；做这些维护前，应按对应工具的要求处理活动 swapfile。[Btrfs 维护限制](https://btrfs.readthedocs.io/en/latest/ch-swapfile.html)

最后，本机当前的系统分区没有加密，休眠映像可能包含内存中的敏感数据。文件权限 `0600` 和 Secure Boot 均不等于休眠映像加密。

**13. 离线方案：移动原 Btrfs 分区并回收 64 GiB**

复查已确认 `/swap/swapfile` 是唯一启用的 swap，当前启动参数没有固定 `resume=`，运行代次与启动代次一致。用户已确认休眠恢复测试通过。旧 swap 分区尚未删除。

本机的目标系统盘为 **SHPP41-2000GM，2 TB**，稳定设备路径为：

```text
/dev/disk/by-id/nvme-eui.ace42e0035f2b5482ee4ac0000000001
```

Windows 所在的 **Samsung SSD 9100 PRO 4TB** 不参与操作。每次进入 Live 环境，都应重新核对型号、容量、标签和 UUID。

已核对的布局及目标边界如下，扇区单位为 512 字节：

| 区域 | 起始扇区 | 结束扇区 | 大小 |
|---|---:|---:|---:|
| ESP，保持不变 | 2048 | 4196351 | 2 GiB |
| 旧 swap，待删除 | 4196352 | 138414079 | 64 GiB |
| 当前 Btrfs | 138414080 | 3907028991 | 1797.015625 GiB |
| 移动并扩容后的 Btrfs | 4196352 | 3907028991 | 1861.015625 GiB |

这个方案需要把 Btrfs 的实际数据向前移动，再扩容。仅删除分区表条目或修改 Btrfs 起始扇区不会完成数据搬移，会导致文件系统无法按原位置读取。GParted 的移动操作要求分区未挂载，因此此方案要从 Live USB 启动。另有第 14 步的在线设备迁移路线。[GParted 分区移动说明](https://gparted.org/display-doc.php?name=help-manual)

**准备工作：** 备份重要数据到另一块磁盘，准备支持本机 Btrfs 特性的当前 Live 环境及 GParted。正常关机后进入 Live 环境，不能从休眠状态转入维护系统。不要在当前运行的根文件系统上做移动。

在 Live 环境里先检查：

```bash
system_disk=/dev/disk/by-id/nvme-eui.ace42e0035f2b5482ee4ac0000000001
readlink -f "$system_disk"
lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,PARTLABEL,UUID,MOUNTPOINTS "$system_disk"
sudo sfdisk --dump "$system_disk"
swapon --show
```

旧 swap 的 UUID 必须为 `314385cf-5091-47e6-84f4-ae2f8f832ad1`；Btrfs 的 UUID 必须为 `4b1afa78-d632-4509-b6af-a2bce080a0b6`。若识别结果不同，先查明原因。

把 `sfdisk --dump` 输出保存到异盘备份目录，同时保存分区列表。下面 `/media/backup` 仅为示例，必须替换为已挂载且确认位于另一块磁盘上的备份目录：

```bash
merge_backup=/media/backup/nixos-swap-merge
mkdir -p "$merge_backup"
sudo sfdisk --dump "$system_disk" > "$merge_backup/partition-table.sfdisk"
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,PARTUUID,UUID "$system_disk" > "$merge_backup/partition-identifiers.txt"
test -s "$merge_backup/partition-table.sfdisk"
```

分区表备份只记录边界和标识，不能替代文件数据备份。数据已经移动后，也不能直接恢复旧分区表来撤销整个操作。

在 GParted 中执行：

1. 选择核验过的 SHPP41-2000GM 系统盘。确认 Btrfs 分区及它的所有子卷挂载均未使用；若 Live 环境自动启用了旧 swap，先执行 Swapoff。
2. 将 `disk-main-swap` 对应的 64 GiB 分区加入删除队列。
3. 对 `disk-main-system` 对应的 Btrfs 分区选择 Resize/Move，将左边界扩展到刚释放空间的起点，右边界保持原位。预期新大小为 `1905680 MiB`，比原大小增加 `65536 MiB`；目标扇区见上表。
4. 核对待执行队列包含“删除旧 swap”和“移动并扩容 Btrfs”，ESP 和 Windows 盘均无操作。不要选择 Format、New UUID 或创建新分区表。
5. 应用操作，保持供电并等待完成，保存 GParted 的操作详情。移动可能涉及大量数据，不能根据只回收 64 GiB 来估计耗时。

操作完成后，在 Live 环境检查分区大小、`disk-main-system` 分区名称和 Btrfs UUID；原 ESP 的 PARTUUID `d8655e96-84bd-4812-a8d3-ffbfb8ea309a` 应保持不变。现有配置通过分区名称挂载 `/`、`/nix`、`/home`，因此应保留 `disk-main-system` 这个 GPT 分区名称。

正常重启回 NixOS 后验证：

```bash
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,UUID,MOUNTPOINTS
sudo btrfs filesystem usage /
swapon --show
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
systemctl --failed --no-pager
```

应看到系统 Btrfs 分区增加了 64 GiB、旧 swap 分区消失、swapfile 仍然启用。如果分区已经扩容而 Btrfs 自身仍显示原大小，确认标识和边界正确后，可执行 `sudo btrfs filesystem resize max /` 扩展文件系统。

现有自动休眠配置不需要硬编码新的 offset。仍应重新验证一次休眠恢复；若使用了第 10 步的显式配置，则应重新测量 offset，必要时更新配置并重建、重启后再测试。

此方案保持单设备 Btrfs。仅执行 `btrfs device add` 并长期停留在多设备状态，会改变现有 swapfile 的支持条件。临时加入设备、迁移后再恢复单设备，是另一种方案，见下一步。[Btrfs swapfile 与设备操作限制](https://btrfs.readthedocs.io/en/latest/ch-swapfile.html)

**14. 在线方案：分阶段执行命令**

此方案先把数据迁到原 64 GiB swap 分区，再删除腾空的原系统分区，最后向后扩容。Btrfs 支持在挂载状态下迁出并移除最初用于挂载的设备。[Btrfs 设备管理](https://btrfs.readthedocs.io/en/latest/btrfs-device.html)

本节专用于上面核验过的 SHPP41-2000GM 系统盘。最终保留原第 2 分区，删除原第 3 分区；保留文件系统 UUID、子卷和快照，最后重新创建 swapfile。以下命令尚未在你的实际磁盘上执行。

请先完成重要数据的异盘备份。分区表备份不能代替数据备份。迁移期间关闭虚拟机、编译、下载等大量写入或耗内存的任务，保持供电，不重启、不休眠。容量检查不通过或任何命令失败，就停在该阶段处理；不要继续后面的删除命令，也不要把整个章节一次性粘贴执行。

**14.1 进入 Bash，固定稳定设备标识**

你的日常 shell 是 Zsh，下面使用 Bash 数组和语法。先单独执行：

```bash
bash
```

后续命令按顺序在同一个 Bash 终端执行。`set -e` 会在普通命令失败时退出这个 Bash，避免继续后续操作；如果退出，不要直接在 Zsh 里粘贴下一阶段。

```bash
set -euo pipefail
cd /home/ben/nixos-config

export merge_disk=/dev/disk/by-id/nvme-eui.ace42e0035f2b5482ee4ac0000000001
export merge_target=/dev/disk/by-partuuid/09660c25-db47-44d3-beff-f8cddad19871
export merge_source=/dev/disk/by-partuuid/0bb8b079-a23d-4154-8b00-79862d213103
export merge_fsuuid=4b1afa78-d632-4509-b6af-a2bce080a0b6
export merge_sysfs=/sys/fs/btrfs/$merge_fsuuid

sudo -v
test -b "$merge_disk"
test -b "$merge_target"
test -b "$merge_source"
test "$(sudo blockdev --getss "$merge_disk")" = 512
test "$(sudo blockdev --getsize64 "$merge_disk")" = 2000398934016
test "$(sudo blkid -p -s UUID -o value "$merge_target")" = 314385cf-5091-47e6-84f4-ae2f8f832ad1
test "$(sudo blkid -p -s UUID -o value "$merge_source")" = "$merge_fsuuid"
test -d "$merge_sysfs/devices/$(basename "$(readlink -e "$merge_source")")"
merge_members=("$merge_sysfs"/devices/*)
test "${#merge_members[@]}" = 1

lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL,PARTLABEL,PARTUUID,UUID,MOUNTPOINTS "$merge_disk"
sudo btrfs filesystem usage -T /
sudo btrfs filesystem df /
sudo btrfs device stats --check /
cat "$merge_sysfs/exclusive_operation"
swapon --show
free -h
```

检查点：目标盘是 2 TB SHPP41-2000GM；只有一个 Btrfs 成员；当前是 `Data, single`、`Metadata, DUP`、`System, DUP`；设备错误统计全为 0；独占操作为 `none`。本节不包含其他 RAID/profile 的转换，出现不同结果先停止。

**14.2 保存分区表和配置到异盘**

输入一个已挂载、可写、位于另一块磁盘上的目录。下面会拒绝根 Btrfs、tmpfs 和无法识别为独立分区的路径；采用 LVM 等其他备份布局时应另行核验，不能删除检查来强行继续。

```bash
read -r -p '已挂载的异盘备份目录：' merge_backup_root
test -d "$merge_backup_root"
test -w "$merge_backup_root"
merge_backup_device=$(findmnt -n -o SOURCE -T "$merge_backup_root")
merge_backup_device=${merge_backup_device%%\[*}
test -b "$merge_backup_device"
merge_backup_parent=$(lsblk -dn -o PKNAME "$merge_backup_device")
test -n "$merge_backup_parent"
test "$(readlink -e "/dev/$merge_backup_parent")" != "$(readlink -e "$merge_disk")"
findmnt -T "$merge_backup_root"

export merge_backup="$merge_backup_root/nixos-swap-merge-$(date +%Y%m%d-%H%M%S)"
mkdir -m 700 "$merge_backup"
sudo sfdisk --dump "$merge_disk" > "$merge_backup/partition-table.before.sfdisk"
sudo sfdisk --json "$merge_disk" > "$merge_backup/partition-table.before.json"
sudo btrfs subvolume list / > "$merge_backup/subvolumes.before.txt"
cp hosts/nixos/default.nix hosts/nixos/hardware-configuration.nix hosts/nixos/disk-config.nix flake.lock "$merge_backup/"
git diff HEAD --binary > "$merge_backup/config-changes.patch"
git status --short > "$merge_backup/git-status.before.txt"
sha256sum hosts/nixos/hardware-configuration.nix hosts/nixos/disk-config.nix flake.lock > "$merge_backup/config.sha256"
test -s "$merge_backup/partition-table.before.sfdisk"
printf '备份目录：%s\n' "$merge_backup"

python3 - <<'PY'
import json, os
from pathlib import Path
t = json.loads((Path(os.environ['merge_backup']) / 'partition-table.before.json').read_text())['partitiontable']
assert t['label'] == 'gpt' and t['sectorsize'] == 512, t
p = t['partitions']
assert len(p) == 3, p
expected = [
    (2048, 4194304, 'd8655e96-84bd-4812-a8d3-ffbfb8ea309a'),
    (4196352, 134217728, '09660c25-db47-44d3-beff-f8cddad19871'),
    (138414080, 3768614912, '0bb8b079-a23d-4154-8b00-79862d213103'),
]
for part, (start, size, uuid) in zip(p, expected):
    assert (part['start'], part['size'], part['uuid'].lower()) == (start, size, uuid), part
assert Path(p[1]['node']).resolve() == Path(os.environ['merge_target']).resolve()
assert Path(p[2]['node']).resolve() == Path(os.environ['merge_source']).resolve()
print('分区边界、分区 UUID 和目标设备核验通过。')
PY
```

**14.3 先安装迁移期间可启动的配置**

原配置用 `disk-main-system` 定位原第 3 分区。必须先准备按文件系统 UUID 启动、且不会自动创建 64 GiB swapfile 的临时配置。这样迁移中途意外重启时，应选择这个迁移代次，不能选择仍依赖旧布局的历史代次。

以下命令创建临时模块，只在 `hosts/nixos/default.nix` 增加一条导入；最后会移除。若同名文件已存在，检查会停止。

```bash
test ! -e hosts/nixos/swap-migration.nix
cat > hosts/nixos/swap-migration.nix <<'NIX'
{ lib, ... }:
{
  fileSystems = lib.genAttrs [ "/" "/nix" "/home" ] (_: {
    device = lib.mkForce "/dev/disk/by-uuid/4b1afa78-d632-4509-b6af-a2bce080a0b6";
  });
  swapDevices = lib.mkForce [ ];
  systemd.services.mkswap-swap-swapfile.enable = false;
  boot.resumeDevice = lib.mkForce "";
  systemd.sleep.settings.Sleep.AllowHibernation = false;
}
NIX

python3 - <<'PY'
from pathlib import Path
p = Path('hosts/nixos/default.nix')
s = p.read_text()
anchor = '    ./hardware-configuration.nix\n'
assert s.count(anchor) == 1 and './swap-migration.nix' not in s
p.write_text(s.replace(anchor, anchor + '    ./swap-migration.nix\n'))
PY
git add --intent-to-add -- hosts/nixos/swap-migration.nix
nix eval --json .#nixosConfigurations.nixos.config.swapDevices
sudo nixos-rebuild boot --flake .#nixos

merge_boot_system=$(readlink -e /nix/var/nix/profiles/system)
printf '%s\n' "$merge_boot_system" > "$merge_backup/migration-system.txt"
cat "$merge_boot_system/etc/fstab"
cat "$merge_boot_system/kernel-params"
```

检查点：求值结果为 `[]`；新代次的 fstab 中 `/`、`/nix`、`/home` 指向上述 UUID，swap 条目为空；没有旧 `resume=` 或 `resume_offset=`。`nixos-rebuild boot` 必须成功完成，包括安装启动项。这个命令只更新下次启动配置，当前 swapfile 仍需在下一步停用。

不要在第 2 分区还只有 64 GiB 时恢复普通配置，它会尝试重新创建 64 GiB 文件而耗尽临时空间。

**14.4 停用 swapfile，释放 64 GiB，并重新检查容量**

```bash
sudo systemd-run --unit=btrfs-migration-inhibit --property=Type=exec \
  /run/current-system/sw/bin/systemd-inhibit \
  --what=sleep:shutdown:idle --mode=block --why='Btrfs online migration' \
  /run/current-system/sw/bin/sleep infinity
sudo systemctl stop snapper-timeline.timer snapper-cleanup.timer
sudo systemctl stop swap-swapfile.swap
sudo systemctl mask --runtime swap-swapfile.swap
test "$(systemctl show -p LoadState --value swap-swapfile.swap)" = masked
test -z "$(swapon --noheadings --raw --show=NAME)"
sudo test -f /swap/swapfile
test "$(sudo stat -c %s /swap/swapfile)" = 68719476736
sudo rm -- /swap/swapfile
sudo btrfs filesystem sync /

sudo btrfs filesystem usage -T /
sudo btrfs device stats --check /
python3 - <<'PY'
import os
from pathlib import Path
p = Path(os.environ['merge_sysfs'])
assert (p / 'exclusive_operation').read_text().strip() == 'none'
used = sum(int((p / 'allocation' / kind / 'disk_used').read_text()) for kind in ['data', 'metadata', 'system'])
print(f'数据、元数据和系统块的物理占用合计：{used / 2**30:.2f} GiB')
assert used < 52 * 2**30, '超过本教程为 64 GiB 中转分区设定的保守门槛；停止，不继续加入或删除设备。'
PY
```

预期占用约 49 GiB。52 GiB 是此流程的停止门槛，用于预留空间，不是 Btrfs 官方保证值；即使通过，迁移仍可能因为空间分配等原因失败。失败时原大分区不能删除。

**14.5 将旧 swap 分区变为临时 Btrfs 成员**

这里保留第 2 分区的起始扇区、大小和 PARTUUID，先将 GPT 类型改为 Linux filesystem，防止以后把它当 swap 自动启用。

```bash
test -z "$(swapon --noheadings --raw --show=NAME)"
test "$(sudo blkid -p -s UUID -o value "$merge_target")" = 314385cf-5091-47e6-84f4-ae2f8f832ad1
printf 'type=0FC63DAF-8483-4772-8E79-3D69D8477DE4,name="btrfs-migration"\n' | \
  sudo sfdisk --no-reread --no-tell-kernel --wipe never --wipe-partitions never -N 2 "$merge_disk"
sudo partx --update --nr 2 "$merge_disk"
sudo udevadm settle
test "$(sudo blockdev --getsize64 "$merge_target")" = 68719476736
test "$(cat "/sys/class/block/$(basename "$(readlink -e "$merge_target")")/start")" = 4196352

sudo btrfs device add -f "$merge_target" /
sudo btrfs filesystem show --raw /
merge_members=("$merge_sysfs"/devices/*)
test "${#merge_members[@]}" = 2
test -d "$merge_sysfs/devices/$(basename "$(readlink -e "$merge_target")")"
test -d "$merge_sysfs/devices/$(basename "$(readlink -e "$merge_source")")"
sudo btrfs device stats --check /
```

`device add -f` 会覆盖**已核验的旧 swap 分区**上的签名；这里的强制参数用于覆盖 swap，不能改成对整块磁盘或其他设备执行。

**14.6 迁出原第 3 分区，等待完成**

```bash
sudo btrfs device remove "$merge_source" /
sudo btrfs filesystem sync /
sudo btrfs filesystem show --raw / | tee "$merge_backup/filesystem.after-remove.txt"
sudo btrfs device stats --check /

merge_members=("$merge_sysfs"/devices/*)
test "${#merge_members[@]}" = 1
test "$(basename "${merge_members[0]}")" = "$(basename "$(readlink -e "$merge_target")")"
test ! -e "$merge_sysfs/devices/$(basename "$(readlink -e "$merge_source")")"
test "$(cat "$merge_sysfs/exclusive_operation")" = none
sha256sum -c "$merge_backup/config.sha256"
```

第一条可能需要较长时间，保持终端运行。**只有命令成功返回，并且设备列表中仅剩原第 2 分区，才进入下一步。** `device remove` 失败、空间不足、或仍能看到原第 3 分区时，都不能继续删除分区表条目。

**14.7 删除已腾空的第 3 分区，再扩展第 2 分区**

这是删除分区表条目的阶段。先重复检查成员设备，并保存此时的分区表：

```bash
merge_members=("$merge_sysfs"/devices/*)
test "${#merge_members[@]}" = 1
test "$(basename "${merge_members[0]}")" = "$(basename "$(readlink -e "$merge_target")")"
test ! -e "$merge_sysfs/devices/$(basename "$(readlink -e "$merge_source")")"
sudo sfdisk --dump "$merge_disk" > "$merge_backup/partition-table.before-delete.sfdisk"

sudo sfdisk --no-reread --no-tell-kernel --delete "$merge_disk" 3
sudo partx --delete --nr 3 "$merge_disk"

printf 'start=4196352,size=3902832640,type=0FC63DAF-8483-4772-8E79-3D69D8477DE4,name="disk-main-system"\n' | \
  sudo sfdisk --no-reread --no-tell-kernel --wipe never --wipe-partitions never -N 2 "$merge_disk"
sudo partx --update --nr 2 "$merge_disk"
sudo udevadm trigger --action=change --sysname-match="$(basename "$(readlink -e "$merge_target")")"
sudo udevadm settle

test "$(sudo blockdev --getsize64 "$merge_target")" = 1998250311680
test "$(cat "/sys/class/block/$(basename "$(readlink -e "$merge_target")")/start")" = 4196352
test "$(readlink -e /dev/disk/by-partlabel/disk-main-system)" = "$(readlink -e "$merge_target")"
sudo sfdisk --verify "$merge_disk"
sudo sfdisk --json "$merge_disk" > "$merge_backup/partition-table.after.json"

python3 - <<'PY'
import json, os
from pathlib import Path
p = json.loads((Path(os.environ['merge_backup']) / 'partition-table.after.json').read_text())['partitiontable']['partitions']
assert len(p) == 2, p
assert p[0]['start'] == 2048 and p[0]['size'] == 4194304, p[0]
assert p[0]['uuid'].lower() == 'd8655e96-84bd-4812-a8d3-ffbfb8ea309a', p[0]
assert p[1]['start'] == 4196352 and p[1]['size'] == 3902832640, p[1]
assert p[1]['uuid'].lower() == '09660c25-db47-44d3-beff-f8cddad19871', p[1]
assert p[1]['name'] == 'disk-main-system', p[1]
print('分区表核验通过：ESP 未变，原第 2 分区已向后扩容。')
PY
```

`--no-tell-kernel` 将分区表写入与内核更新分开；`partx` 只更新指定分区。这些命令不搬移分区起点，也不执行文件系统格式化。`--wipe never` 和 `--wipe-partitions never` 用来保留现有 Btrfs 签名。[sfdisk 手册](https://man7.org/linux/man-pages/man8/sfdisk.8.html)、[partx 手册](https://man7.org/linux/man-pages/man8/partx.8.html)

若 `partx` 返回 busy 等错误，或 `blockdev` 仍显示旧的 64 GiB，立即停止；此时不能扩展 Btrfs。先保存输出、确认磁盘分区表正确，再按迁移启动配置安排维护重启。不要强制重读整块正在使用的磁盘。

**14.8 按剩余设备编号扩展 Btrfs**

```bash
merge_devid=$(sudo btrfs filesystem show --raw / | \
  awk '$1 == "devid" { id = $2; count++ } END { if (count == 1) print id; else exit 1 }')
[[ "$merge_devid" =~ ^[1-9][0-9]*$ ]]
printf '剩余 Btrfs 设备编号：%s\n' "$merge_devid"
test "$(sudo blockdev --getsize64 "$merge_target")" = 1998250311680
sudo btrfs filesystem resize "$merge_devid:max" /
sudo btrfs filesystem usage -T /
sudo btrfs filesystem show --raw /
sudo btrfs device stats --check /
test "$(sudo blkid -p -s UUID -o value "$merge_target")" = "$merge_fsuuid"
```

设备编号通常是 `2`，但以上命令会实际读取它。预期设备大小约 `1861.02 GiB`，仍是单设备 Btrfs；`resize` 不会替你扩展底层分区，所以前一阶段的内核大小检查必须通过。[Btrfs 扩容说明](https://btrfs.readthedocs.io/en/latest/btrfs-filesystem.html)

**14.9 移除临时配置，重建 swapfile**

确认文件系统已经扩容后再执行：

```bash
cd /home/ben/nixos-config
python3 - <<'PY'
from pathlib import Path
p = Path('hosts/nixos/default.nix')
s = p.read_text()
line = '    ./swap-migration.nix\n'
assert s.count(line) == 1
p.write_text(s.replace(line, ''))
PY
git restore --staged -- hosts/nixos/swap-migration.nix
rm -- hosts/nixos/swap-migration.nix
git diff --check
nix eval --json .#nixosConfigurations.nixos.config.swapDevices \
  --apply 'devices: map (d: { inherit (d) device size; }) devices'

sudo systemctl unmask --runtime swap-swapfile.swap
sudo nixos-rebuild switch --flake .#nixos
sudo systemctl start swap-swapfile.swap
sudo systemctl start snapper-timeline.timer snapper-cleanup.timer

swapon --show
sudo btrfs inspect-internal map-swapfile -r /swap/swapfile
sudo btrfs filesystem show --raw /
sudo btrfs device stats --check /
sha256sum -c "$merge_backup/config.sha256"
sudo btrfs subvolume list / > "$merge_backup/subvolumes.after.txt"
sudo sfdisk --dump "$merge_disk" > "$merge_backup/partition-table.final.sfdisk"
systemctl --failed --no-pager
sudo systemctl stop btrfs-migration-inhibit.service
```

检查点：配置中只有 `/swap/swapfile`、大小 `65536 MiB`；swapfile 已启用；Btrfs 只包含扩容后的原第 2 分区；文件系统 UUID 未变；错误计数仍为 0。

此流程仅对新建的临时模块使用了 `git add --intent-to-add` 和对应清理命令，没有提交配置，也不需要修改 `flake.lock`。最后用 `git status --short` 检查工作区；不要用整仓库 reset 来清理临时修改。

最后正常重启一次，确认最新 NixOS 代次能够启动，再按第 8 步做一次休眠恢复测试。自动休眠方式会重新记录位置；不要沿用迁移前记录的 offset。

**14.10 中途失败时停在哪里**

| 失败阶段 | 正确处理 |
|---|---|
| 临时配置构建/启动项安装失败 | 不开始设备迁移。处理构建问题，或移除临时导入并恢复普通配置。 |
| 删除 swapfile 后容量门槛未通过 | 不加入或移除设备。原大分区仍完整，可先恢复普通配置和 swapfile。 |
| 已加入第 2 分区，`device remove` 失败 | 保留两个分区，保存 `btrfs filesystem show`、`usage` 和日志。不能删除第 3 分区，也不要在临时空间紧张时重新创建 swapfile。 |
| 第 3 分区已迁出，但分区表更新失败 | 数据位于第 2 分区。保留现场；不要恢复旧布局来尝试撤销数据迁移。 |
| 磁盘分区表已扩容，但内核长度未更新 | 不执行 filesystem resize，不创建 swapfile；核验磁盘表后使用迁移代次进行维护重启，再重新读取设备大小和编号。 |
| 最终 rebuild 失败 | 数据迁移结果不因此撤销；先处理配置/启动项错误，保留备份和迁移启动项。 |

如果 Bash 退出或机器中途重启，先重新核验所在阶段。不要从 14.1 整章重跑：旧 swap 签名、成员数量和分区布局已经变化。备份目录中的分区表、迁移代次路径和本机命令输出用于判断下一步。
