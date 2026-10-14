# 编译指南

本仓库用于按设备配置自动拉取 OpenWrt / ImmortalWrt / LiBwrt 源码、应用自定义补丁与软件包配置，并输出固件到 `firmware/` 目录。

## 1. 环境准备

推荐使用 Ubuntu LTS 或其他主流 Linux 发行版。OpenWrt 编译对磁盘空间、内存和文件系统大小写敏感性有要求，建议预留充足磁盘空间并在原生 Linux 文件系统中编译。

## 2. 安装编译依赖

```bash
sudo apt -y update
sudo apt -y full-upgrade
sudo apt install -y dos2unix libfuse-dev
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'
```

容器构建还需要已安装并可正常运行的 Docker。

## 3. 获取源码

```bash
git clone https://github.com/ZqinKing/wrt_release.git
cd wrt_release
```

## 4. 编译用法

### 交互式选择

直接运行脚本会列出当前 `wrt_core/compilecfg/*.ini` 与 `wrt_core/deconfig/*.config` 同时存在的设备配置，并提示选择构建模式：

```bash
./build.sh
```

### 直接指定设备

```bash
./build.sh <设备配置名> [debug|container|container_debug|config_preview]
```

构建模式说明：

| 模式 | 命令示例 | 说明 |
| --- | --- | --- |
| 默认 | `./build.sh redmi_ax6_immwrt` | 拉取源码、应用配置、下载依赖并完整编译固件。 |
| `debug` | `./build.sh redmi_ax6_immwrt debug` | 执行到 `make defconfig` 后停止，用于检查配置，不产出固件。 |
| `container` | `./build.sh redmi_ax6_immwrt container` | 使用 Docker 容器执行完整构建，减少本机环境差异。 |
| `container_debug` | `./build.sh redmi_ax6_immwrt container_debug` | 在 Docker 容器中执行 debug 流程并进入交互 shell。 |
| `config_preview` | `./build.sh redmi_ax6_immwrt config_preview` | 只预览配置片段组合，不拉取源码、不写构建目录。 |

可通过环境变量临时追加或移除配置片段：

```bash
ADD_CONFIG_FRAGMENTS=docker_deps ./build.sh redmi_ax6_immwrt config_preview
REMOVE_CONFIG_FRAGMENTS=proxy ./build.sh redmi_ax6_immwrt config_preview
```

GitHub Actions 的手动构建也提供 `add_fragments` 与 `remove_fragments` 输入项，语义与上述环境变量一致。

编译完成后，脚本会从 `<BUILD_DIR>/bin/targets/` 收集固件文件到仓库根目录的 `firmware/`。每次完整构建前会清理旧的目标固件文件，`firmware/Packages.manifest` 会被移除。

## 5. 支持设备

设备配置名来自 `wrt_core/compilecfg/` 和 `wrt_core/deconfig/` 中同名文件。当前支持：

| 厂商 / 平台 | 设备 | 配置名 |
| --- | --- | --- |
| 红米 | AX6 | `redmi_ax6_immwrt` |
| 红米 | AX6 - LiBwrt | `redmi_ax6_libwrt` |
| 红米 | AX6000 | `redmi_ax6000_immwrt` |

示例：

```bash
./build.sh redmi_ax6_immwrt
./build.sh redmi_ax6000_immwrt
./build.sh redmi_ax6_libwrt container
```

## 6. 配置来源

每个设备由两类文件共同定义：

- `wrt_core/compilecfg/<设备配置名>.ini`：定义源码仓库、分支、构建目录、默认配置片段、可选提交哈希和容器 SDK 镜像。
- `wrt_core/deconfig/<设备配置名>.config`：定义 OpenWrt 目标平台、设备和软件包配置。

不同设备会使用不同上游源码，例如 `VIKINGYFY/immortalwrt`、`immortalwrt/immortalwrt`、`LiBwrt/openwrt-6.x`、`padavanonly/immortalwrt-mt798x` 或本仓库维护的特定分支。`BUILD_TARGET_SDK` 未配置时，容器构建默认使用 `immortalwrt/sdk:openwrt-25.12`。

构建时会按顺序组合配置：

1. 设备专用 `.config`
2. `compile_base.config`
3. `wrt_core/deconfig/fragments/<name>.config` 中的有效配置片段

设备配置保留原有设置；同名选项由后追加的公共配置或片段覆盖，最终再由 `make defconfig` 解析依赖。

默认片段由 `compilecfg/*.ini` 的 `CONFIG_FRAGMENTS` 指定：

- 所有设备默认包含 `proxy`。
- AX6（IPQ807x）设备默认额外包含 `nss`。
- 只有已显式选择 Dockerman 或明确适合运行 Docker 的设备默认包含 `docker_deps`，用于预置手动安装 Docker 所需的运行依赖，避免 NAND 空间紧张或无 USB 设备被默认加入 Docker 依赖。

`ADD_CONFIG_FRAGMENTS` 会在默认片段后追加，`REMOVE_CONFIG_FRAGMENTS` 会从最终片段中移除对应配置片段。移除只表示“不追加这个 fragment”，不会反向修改设备 `.config` 或 `compile_base.config` 中已经写明的配置。

公共配置的可用选项取决于设备源码分支、上游 feeds 和 `custom_feed`。不存在的 Kconfig 选项通常会被 `make defconfig` 丢弃，并不直接导致构建失败，但对应功能不会启用；缺失依赖、源码不兼容和下载失败则可能中断构建。可运行 `./build.sh redmi_ax6000_immwrt debug`，检查生成的 `imm-mt798x/.config`；`config_preview` 只展示组合顺序，不验证软件包是否可用。

当前同步流程会修正 aguowork/wechatpush 的主机与磁盘信息检测选项名，使其与公共配置及上游依赖声明一致。

## 7. 三方插件

三方插件主要通过 feeds 机制加入，其中 small-package 源自：

```text
https://github.com/kenzok8/small-package.git
```

相关增删和同步逻辑位于 `wrt_core/update.sh` 编排的 `wrt_core/modules/` 静态阶段。配置片段只选择 Kconfig，不负责 clone 仓库、修改 feeds 或安装 feeds。

AdGuard Home 按程序与 LuCI 插件分别采用“上游优先、缺失补充”：构建时检查上游对应软件包的 `Makefile`，已有的直接使用；程序缺失时从 `kenzok8/small-package` 补充 `adguardhome`，LuCI 插件缺失时从 `ZqinKing/luci-app-adguardhome` 补充。补充源码在 feed 建索引前准备，安装后检查所选来源的包路径。

按当前上游情况，AX6 的 ImmortalWrt 默认 feeds 和 LiBwrt 的 25.12 feeds 均提供两者，直接使用上游；AX6000 的 24.10 feeds 提供程序但缺少 LuCI 插件，因此只补充自定义 LuCI。判断依据是实际拉取的源码，不按设备名写死。上游与自定义 LuCI 的界面、服务及配置文件名称不同，从旧自定义版本升级到上游版本后需检查 AdGuard Home 设置。

固件不再预装 iStoreX、iStore 商店、QuickStart 和 Lucky，也不再从 `custom_feed` 同步这些插件及 `taskd`、`luci-lib-taskd`、`luci-lib-xterm`。对应的更新脚本、兼容补丁、Lucky 本地二进制包及其额外升级备份目录已移除。其他插件仍需的通用依赖由 Kconfig 正常解析，例如 wechatpush 的磁盘信息检测仍会选择 `lsblk`、`smartmontools` 和 `smartmontools-drivedb`。

公共配置同时禁用 SmartDNS、MosDNS、PBR、EasyTier（含额外 Web 控制台）和独立 WireGuard 组件（LuCI 界面、工具及内核模块）。相关自定义源码同步、补丁和安装检查已清理，包括 MosDNS 的 `geo2txt`、PBR 的 CMCC 规则以及 EasyTier 的额外备份目录。开机脚本会清理旧固件遗留的 WireGuard watchdog 定时任务。AdGuard Home、Passwall、ZeroTier 及它们仍需要的通用依赖继续保留。

CoreMark 基准测试工具也已禁用，其专属优化、多线程配置和构建修正已移除。

## 8. 项目结构说明

- `build.sh`：主编译入口，负责设备选择、模式选择、配置组合、容器构建和固件收集。
- `firmware/`：完整构建后的固件输出目录，由脚本自动创建和刷新。
- `wrt_core/build_container.sh`：容器内构建入口。
- `wrt_core/update.sh`：源码更新、feeds 调整、软件包同步和补丁应用主流程。
- `wrt_core/pre_clone_action.sh`：GitHub Actions 预克隆辅助脚本。
- `wrt_core/compilecfg/`：设备构建元信息 `.ini`。
- `wrt_core/deconfig/`：设备和共享默认配置 `.config`。
- `wrt_core/deconfig/fragments/`：可组合配置片段。
- `wrt_core/modules/`：模块化脚本，包括仓库准备、网络重试、feeds/custom_feed、源码修正、LuCI 修正、服务修正、验证、Docker、CUPS 等静态职责模块。
- `wrt_core/patches/`：补丁、默认设置、Wi-Fi 初始化、NSS 诊断和其他构建时注入文件。

## 9. OAF（应用过滤）功能使用说明

使用 OAF（应用过滤）功能前，需先完成以下操作：

1. 打开系统设置 → 启动项 → 定位到「appfilter」
2. 将「appfilter」当前状态从已禁用更改为已启用
3. 完成配置后，点击启动按钮激活服务
