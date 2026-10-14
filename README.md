# 编译指南

本仓库基于 [ZqinKing/wrt_release](https://github.com/ZqinKing/wrt_release)，按设备配置自动拉取 OpenWrt / ImmortalWrt / LiBwrt 源码，并应用自定义补丁与软件包配置。编译完成后，固件输出到 `firmware/` 目录。

## 1. 环境准备

推荐使用 Ubuntu LTS，在 Linux 文件系统中编译，并预留充足的磁盘空间和内存。

安装编译依赖：

```bash
sudo apt -y update
sudo apt -y full-upgrade
sudo apt install -y dos2unix libfuse-dev
sudo bash -c 'bash <(curl -sL https://build-scripts.immortalwrt.org/init_build_environment.sh)'
```

## 2. 获取源码

```bash
git clone https://github.com/aguowork/wrt_release.git
cd wrt_release
```

## 3. 编译固件

直接运行 `./build.sh`，按提示选择设备和构建模式；也可以指定设备编译：

| 设备 | 固件源码 | 配置名 |
| --- | --- | --- |
| 红米 AX6 | ImmortalWrt | `redmi_ax6_immwrt` |
| 红米 AX6 | LiBwrt | `redmi_ax6_libwrt` |
| 红米 AX6000 | ImmortalWrt | `redmi_ax6000_immwrt` |

```bash
# 本机编译
./build.sh redmi_ax6000_immwrt

# Docker 容器编译（需先安装并启动 Docker）
./build.sh redmi_ax6_libwrt container
```

编译完成后，固件保存在 `firmware/` 目录。

三个设备的默认 LAN 地址统一为 `192.168.169.1`。首次初始化或恢复出厂设置时生效；保留配置升级会沿用原有 LAN 地址。

需要调试时，在设备配置名后追加以下参数：

| 参数 | 用途 |
| --- | --- |
| `debug` | 准备源码并执行 `make defconfig` 后停止，不编译固件 |
| `container_debug` | 在 Docker 中执行 `debug`，随后进入交互 shell |
| `config_preview` | 预览配置组合，不拉取源码，也不验证软件包是否可用 |

## 4. 选择插件

默认不编入 Passwall 和大鹅，可通过 `ADD_CONFIG_FRAGMENTS` 按需选择，多个片段用逗号分隔：

| 配置片段 | 用途 |
| --- | --- |
| `proxy` | Passwall |
| `daed` | 大鹅 Dashboard（已集成 dae） |

```bash
# 编入 Passwall
ADD_CONFIG_FRAGMENTS=proxy ./build.sh redmi_ax6000_immwrt

# 编入大鹅；同时选择两者时改为 proxy,daed
ADD_CONFIG_FRAGMENTS=daed ./build.sh redmi_ax6000_immwrt
```

AX6 默认加载平台片段 `nss`，建议保留；AX6000 默认不加载任何片段。可用 `REMOVE_CONFIG_FRAGMENTS` 排除片段，但不会撤销设备或公共配置中已有的选项。

大鹅需要上游 feeds 和内核支持；可先用 `debug` 检查生成的 `.config`。同时编入 Passwall 和大鹅时，避免两者同时接管相同流量。

面向资源有限的路由器，固件不预装 Docker、Dockerman 及容器运行时，也不预置 Docker 专用依赖。`container` / `container_debug` 使用的是编译主机上的 Docker，不会因此在路由器固件中安装 Docker。

## 5. GitHub Actions 编译

在仓库的 **Actions** 页面选择工作流，点击 **Run workflow**：

- **WRT 固件构建**：编译后在运行页面的 Artifacts 中下载固件。
- **WRT 固件发布**：编译后将固件和内核模块归档发布到 Releases。

`model` 选择设备；`add_fragments` 按上一节填写，留空使用默认配置；`remove_fragments` 通常留空。

## 6. 配置与目录

自定义源码仓库、分支或默认片段，修改设备对应的 `.ini`；调整软件包，修改设备配置、公共配置或片段。

```text
build.sh                       主编译入口
firmware/                      固件输出（编译后生成）
wrt_core/
├── compilecfg/*.ini            设备源码、分支及默认片段
├── deconfig/*.config           设备配置与公共配置 compile_base.config
├── deconfig/fragments/         可选配置片段
├── modules/                    源码与软件包处理脚本
├── patches/                    补丁与默认设置
└── update.sh                   源码与 feeds 更新入口
```

配置按「设备配置 → 公共配置 → 选用片段」合并，后面的同名选项覆盖前面的设置，最终由 `make defconfig` 解析依赖。

## 7. 插件使用提示

- **OAF（应用过滤）**：在「系统 → 启动项」中找到 `appfilter`，启用后点击启动。
- **DDNSTO**：在「服务 → DDNSTO 远程控制」中填写自己的 Token 并启用。
- **AdGuard Home**：从旧自定义版本升级到上游版本后，需检查原有设置。

第三方插件主要来自上游 feeds 和 [kenzok8/small-package](https://github.com/kenzok8/small-package)，DDNSTO 来自 [linkease/ddnsto-openwrt-package](https://github.com/linkease/ddnsto-openwrt-package)。
