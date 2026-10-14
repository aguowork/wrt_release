#!/usr/bin/env bash
# 构建树一致性检查。

verify_custom_feed_installed_paths() {
    local custom_feed_name
    local custom_feed_package_dir
    # install_feeds 后必须存在的 custom_feed 包路径。
    local required_package_dirs=(
        v2ray-geodata
        luci-app-passwall nikki luci-app-nikki mihomo-meta luci-app-emmc-health
    )
    local missing_package_dirs=()

    custom_feed_name=$(get_custom_feed_name)
    custom_feed_package_dir=$(get_custom_feed_package_dir)

    collect_missing_directories "$custom_feed_package_dir" required_package_dirs missing_package_dirs

    if [ ${#missing_package_dirs[@]} -ne 0 ]; then
        printf '错误：%s 安装后缺少以下仓库依赖路径：\n' "$custom_feed_name" >&2
        printf '  - %s\n' "${missing_package_dirs[@]}" >&2
        return 1
    fi
}


verify_adguardhome_installed_paths() {
    local entries=(
        "packages|net/adguardhome|adguardhome"
        "luci|applications/luci-app-adguardhome|luci-app-adguardhome"
    )
    local entry upstream_feed source_path package_name selected_feed installed_makefile

    for entry in "${entries[@]}"; do
        IFS='|' read -r upstream_feed source_path package_name <<< "$entry"
        selected_feed="$upstream_feed"
        if [ ! -f "$BUILD_DIR/feeds/$upstream_feed/$source_path/Makefile" ]; then
            selected_feed=$(get_custom_feed_name)
        fi

        installed_makefile="$BUILD_DIR/package/feeds/$selected_feed/$package_name/Makefile"
        if [ ! -f "$installed_makefile" ]; then
            echo "错误：$package_name 未从选定的 $selected_feed 安装：$installed_makefile" >&2
            return 1
        fi
    done
}
