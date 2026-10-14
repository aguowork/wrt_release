#!/usr/bin/env bash
# install_feeds 前的 feed 工作树修正。

remove_unwanted_packages() {
    # 移除将由 custom_feed 接管或会产生冲突的上游包。
    # dae / daed 及对应 LuCI 使用上游 feeds，保留供可选配置片段选择。
    local luci_packages=(
        "luci-app-passwall" "luci-app-ddns-go" "luci-app-rclone" "luci-app-ssr-plus"
        "luci-app-vssr" "luci-app-alist" "luci-app-homeproxy"
        "luci-app-haproxy-tcp" "luci-app-openclash" "luci-app-mihomo" "luci-app-appfilter"
        "luci-app-msd_lite" "luci-app-unblockneteasemusic" "luci-app-ddnsto"
    )
    local packages_net=(
        "haproxy" "xray-core" "xray-plugin" "dns2socks" "alist" "hysteria"
        "ddns-go" "naiveproxy" "shadowsocks-rust" "ddnsto"
        "sing-box" "v2ray-core" "v2ray-geodata" "v2ray-plugin" "tuic-client"
        "chinadns-ng" "ipt2socks" "tcping" "trojan-plus" "simple-obfs" "shadowsocksr-libev"
        "mihomo" "geoview" "open-app-filter" "msd_lite"
    )
    local packages_utils=(
        "cups"
    )
    for pkg in "${luci_packages[@]}"; do
        if [[ -d ./feeds/luci/applications/$pkg ]]; then
            \rm -rf ./feeds/luci/applications/$pkg
        fi
        if [[ -d ./feeds/luci/themes/$pkg ]]; then
            \rm -rf ./feeds/luci/themes/$pkg
        fi
    done

    for pkg in "${packages_net[@]}"; do
        if [[ -d ./feeds/packages/net/$pkg ]]; then
            \rm -rf ./feeds/packages/net/$pkg
        fi
    done

    for pkg in "${packages_utils[@]}"; do
        if [[ -d ./feeds/packages/utils/$pkg ]]; then
            \rm -rf ./feeds/packages/utils/$pkg
        fi
    done

    # 上游若内置 iStore 源码，仍需清理，避免重新引入已移除的商店组件。
    if [[ -d ./package/istore ]]; then
        \rm -rf ./package/istore
    fi

    if [ -d "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults" ]; then
        find "$BUILD_DIR/target/linux/qualcommax/base-files/etc/uci-defaults/" -type f -name "99*.sh" -exec rm -f {} +
    fi
}


prepare_wechatpush() {
    local app_dir="$BUILD_DIR/feeds/luci/applications/luci-app-wechatpush"
    local app_repo="https://github.com/aguowork/luci-app-wechatpush.git"
    local wrtbwmon_repo="https://github.com/brvphoenix/wrtbwmon.git"
    local wrtbwmon_tmp="$BUILD_DIR/package/wrtbwmon-source"
    local wrtbwmon_dir="$BUILD_DIR/package/wrtbwmon"
    local upstream_wrtbwmon_dir="$BUILD_DIR/feeds/packages/net/wrtbwmon"

    if [ ! -d "$(dirname "$app_dir")" ]; then
        echo "LuCI applications feed not found: $(dirname "$app_dir")" >&2
        return 1
    fi

    echo "正在替换 luci-app-wechatpush 为 aguowork 版本..."
    rm -rf "$app_dir"
    if ! git_retry clone --depth 1 "$app_repo" "$app_dir"; then
        echo "错误：从 $app_repo 克隆 luci-app-wechatpush 失败" >&2
        return 1
    fi

    # 统一上游 Kconfig 定义与其 PKG_CONFIG_DEPENDS / LUCI_DEPENDS 中的名称。
    sed -i \
        -e 's/^config PACKAGE_$(PKG_NAME)_Local_Disk_Information_Detection$/config PACKAGE_$(PKG_NAME)_Enable_Local_Disk_Information_Detection/' \
        -e 's/^config PACKAGE_$(PKG_NAME)_Host_Information_Detection$/config PACKAGE_$(PKG_NAME)_Enable_Host_Information_Detection/' \
        "$app_dir/Makefile"

    echo "正在添加 wechatpush 流量监控依赖 wrtbwmon..."
    rm -rf "$upstream_wrtbwmon_dir" "$wrtbwmon_tmp" "$wrtbwmon_dir"
    if ! git_retry clone --depth 1 "$wrtbwmon_repo" "$wrtbwmon_tmp"; then
        echo "错误：从 $wrtbwmon_repo 克隆 wrtbwmon 失败" >&2
        rm -rf "$wrtbwmon_tmp"
        return 1
    fi

    if [ ! -f "$wrtbwmon_tmp/wrtbwmon/Makefile" ]; then
        echo "错误：wrtbwmon 包目录不存在：$wrtbwmon_tmp/wrtbwmon" >&2
        rm -rf "$wrtbwmon_tmp"
        return 1
    fi

    if ! mv "$wrtbwmon_tmp/wrtbwmon" "$wrtbwmon_dir"; then
        echo "错误：无法安装 wrtbwmon 包到 $wrtbwmon_dir" >&2
        rm -rf "$wrtbwmon_tmp"
        return 1
    fi
    rm -rf "$wrtbwmon_tmp"
}


update_homeproxy() {
    local repo_url="https://github.com/immortalwrt/homeproxy.git"
    local target_dir="$(get_custom_feed_worktree_dir)/luci-app-homeproxy"

    if [ -d "$target_dir" ]; then
        echo "正在更新 homeproxy..."
        rm -rf "$target_dir"
        if ! git_retry clone --depth 1 "$repo_url" "$target_dir"; then
            echo "错误：从 $repo_url 克隆 homeproxy 仓库失败" >&2
            exit 1
        fi
    fi
}


remove_attendedsysupgrade() {
    find "$BUILD_DIR/feeds/luci/collections" -name "Makefile" | while read -r makefile; do
        if grep -q "luci-app-attendedsysupgrade" "$makefile"; then
            sed -i "/luci-app-attendedsysupgrade/d" "$makefile"
            echo "Removed luci-app-attendedsysupgrade from $makefile"
        fi
    done
}


update_tcping() {
    local tcping_path="$(get_custom_feed_worktree_dir)/tcping/Makefile"
    local url="https://raw.githubusercontent.com/Openwrt-Passwall/openwrt-passwall-packages/refs/heads/main/tcping/Makefile"

    if [ -d "$(dirname "$tcping_path")" ]; then
        echo "正在更新 tcping Makefile..."
        if ! curl_retry -fsSL -o "$tcping_path" "$url"; then
            echo "错误：从 $url 下载 tcping Makefile 失败" >&2
            exit 1
        fi
    fi
}


apply_passwall_tweaks() {
    local chnlist_path="$(get_custom_feed_worktree_dir)/luci-app-passwall/root/usr/share/passwall/rules/chnlist"
    if [ -f "$chnlist_path" ]; then
        >"$chnlist_path"
    fi

    local xray_util_path="$(get_custom_feed_worktree_dir)/luci-app-passwall/luasrc/passwall/util_xray.lua"
    if [ -f "$xray_util_path" ]; then
        sed -i 's/maxRTT = "1s"/maxRTT = "2s"/g' "$xray_util_path"
        sed -i 's/sampling = 3/sampling = 5/g' "$xray_util_path"
    fi
}


update_oaf_deconfig() {
    local conf_path="$(get_custom_feed_worktree_dir)/open-app-filter/files/appfilter.config"
    local uci_def="$(get_custom_feed_worktree_dir)/luci-app-oaf/root/etc/uci-defaults/94_feature_3.0"
    local disable_path="$(get_custom_feed_worktree_dir)/luci-app-oaf/root/etc/uci-defaults/99_disable_oaf"

    if [ -d "${conf_path%/*}" ] && [ -f "$conf_path" ]; then
        sed -i \
            -e "s/record_enable '1'/record_enable '0'/g" \
            -e "s/disable_hnat '1'/disable_hnat '0'/g" \
            -e "s/auto_load_engine '1'/auto_load_engine '0'/g" \
            "$conf_path"
    fi

    if [ -d "${uci_def%/*}" ] && [ -f "$uci_def" ]; then
        sed -i '/\(disable_hnat\|auto_load_engine\)/d' "$uci_def"

        cat >"$disable_path" <<-EOF
#!/bin/sh
[ "\$(uci get appfilter.global.enable 2>/dev/null)" = "0" ] && {
    /etc/init.d/appfilter disable
    /etc/init.d/appfilter stop
}
EOF
        chmod +x "$disable_path"
    fi
}


remove_tweaked_packages() {
    local target_mk="$BUILD_DIR/include/target.mk"
    if [ -f "$target_mk" ]; then
        if grep -q "^DEFAULT_PACKAGES += \$(DEFAULT_PACKAGES.tweak)" "$target_mk"; then
            sed -i 's/DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.tweak)/# DEFAULT_PACKAGES += $(DEFAULT_PACKAGES.tweak)/g' "$target_mk"
        fi
    fi
}
