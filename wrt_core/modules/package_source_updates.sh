#!/usr/bin/env bash
# install_feeds 前的软件包源码替换与补齐。

update_golang() {
    if [[ -d ./feeds/packages/lang/golang ]]; then
        echo "正在更新 golang 软件包..."
        \rm -rf ./feeds/packages/lang/golang
        if ! git_retry clone --depth 1 -b "$GOLANG_BRANCH" "$GOLANG_REPO" ./feeds/packages/lang/golang; then
            echo "错误：克隆 golang 仓库 $GOLANG_REPO 失败" >&2
            exit 1
        fi
    fi
}


check_default_settings() {
    local settings_dir="$BUILD_DIR/package/emortal/default-settings"
    if [ -z "$(find "$BUILD_DIR/package" -type d -name "default-settings" -print -quit 2>/dev/null)" ]; then
        echo "在 $BUILD_DIR/package 中未找到 default-settings 目录，正在从 immortalwrt 仓库克隆..."
        local tmp_dir
        tmp_dir=$(mktemp -d)
        if git_retry clone --depth 1 --filter=blob:none --sparse https://github.com/immortalwrt/immortalwrt.git "$tmp_dir"; then
            pushd "$tmp_dir" >/dev/null
            git_retry sparse-checkout set package/emortal/default-settings
            mkdir -p "$(dirname "$settings_dir")"
            mv package/emortal/default-settings "$settings_dir"
            popd >/dev/null
            rm -rf "$tmp_dir"
            echo "default-settings 克隆并移动成功。"
        else
            echo "错误：克隆 immortalwrt 仓库失败" >&2
            rm -rf "$tmp_dir"
            exit 1
        fi
    fi
}


add_timecontrol() {
    local timecontrol_dir="$BUILD_DIR/package/luci-app-timecontrol"
    local repo_url="https://github.com/sirpdboy/luci-app-timecontrol.git"
    rm -rf "$timecontrol_dir" 2>/dev/null
    echo "正在添加 luci-app-timecontrol..."
    if ! git_retry clone --depth 1 "$repo_url" "$timecontrol_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-timecontrol 仓库失败" >&2
        exit 1
    fi
}


update_mwan3_fw4() {
    local mwan3_repo="https://github.com/dl12345/mwan3.git"
    local luci_app_mwan3_repo="https://github.com/dl12345/luci-app-mwan3.git"
    local mwan3_branch="openwrt-25.12"
    local mwan3_dir="$BUILD_DIR/feeds/packages/net/mwan3"
    local luci_app_mwan3_dir="$BUILD_DIR/feeds/luci/applications/luci-app-mwan3"

    echo "正在更新 mwan3 fw4 适配版本..."
    mkdir -p "$(dirname "$mwan3_dir")" "$(dirname "$luci_app_mwan3_dir")"
    rm -rf "$mwan3_dir" "$luci_app_mwan3_dir"

    if ! git_retry clone --depth 1 -b "$mwan3_branch" "$mwan3_repo" "$mwan3_dir"; then
        echo "错误：从 $mwan3_repo 克隆 mwan3 仓库失败" >&2
        exit 1
    fi

    echo "正在更新 luci-app-mwan3 fw4 适配版本..."
    if ! git_retry clone --depth 1 -b "$mwan3_branch" "$luci_app_mwan3_repo" "$luci_app_mwan3_dir"; then
        echo "错误：从 $luci_app_mwan3_repo 克隆 luci-app-mwan3 仓库失败" >&2
        exit 1
    fi
}


update_diskman() {
    local path="$BUILD_DIR/feeds/luci/applications/luci-app-diskman"
    local repo_url="https://github.com/lisaac/luci-app-diskman.git"
    if [ -d "$path" ]; then
        echo "正在更新 diskman..."
        cd "$BUILD_DIR/feeds/luci/applications" || return
        \rm -rf "luci-app-diskman"

        if ! git_retry clone --filter=blob:none --no-checkout "$repo_url" diskman; then
            echo "错误：从 $repo_url 克隆 diskman 仓库失败" >&2
            exit 1
        fi
        cd diskman || return

        git_retry sparse-checkout init --cone
        git_retry sparse-checkout set applications/luci-app-diskman || return

        git_retry checkout --quiet

        mv applications/luci-app-diskman ../luci-app-diskman || return
        cd .. || return
        \rm -rf diskman
        cd "$BUILD_DIR"

        sed -i 's/fs-ntfs /fs-ntfs3 /g' "$path/Makefile"
        sed -i '/ntfs-3g-utils /d' "$path/Makefile"
    fi
}


_sync_luci_lib_docker() {
    local lib_path="$BUILD_DIR/feeds/luci/libs/luci-lib-docker"
    local repo_url="https://github.com/lisaac/luci-lib-docker.git"

    if [ ! -d "$lib_path" ]; then
        echo "正在同步 luci-lib-docker..."
        mkdir -p "$BUILD_DIR/feeds/luci/libs" || return
        cd "$BUILD_DIR/feeds/luci/libs" || return

        if ! git_retry clone --filter=blob:none --no-checkout "$repo_url" luci-lib-docker-tmp; then
            echo "错误：从 $repo_url 克隆 luci-lib-docker 仓库失败" >&2
            exit 1
        fi
        cd luci-lib-docker-tmp || return

        git_retry sparse-checkout init --cone
        git_retry sparse-checkout set collections/luci-lib-docker || return

        git_retry checkout --quiet

        mv collections/luci-lib-docker ../luci-lib-docker || return
        cd .. || return
        \rm -rf luci-lib-docker-tmp
        cd "$BUILD_DIR"
        echo "luci-lib-docker 同步完成"
    fi
}


update_dockerman() {
    local path="$BUILD_DIR/feeds/luci/applications/luci-app-dockerman"
    local repo_url="https://github.com/lisaac/luci-app-dockerman.git"

    if [ -d "$path" ]; then
        echo "正在更新 dockerman..."
        _sync_luci_lib_docker || return

        cd "$BUILD_DIR/feeds/luci/applications" || return
        \rm -rf "luci-app-dockerman"

        if ! git_retry clone --filter=blob:none --no-checkout "$repo_url" dockerman; then
            echo "错误：从 $repo_url 克隆 dockerman 仓库失败" >&2
            exit 1
        fi
        cd dockerman || return

        git_retry sparse-checkout init --cone
        git_retry sparse-checkout set applications/luci-app-dockerman || return

        git_retry checkout --quiet

        mv applications/luci-app-dockerman ../luci-app-dockerman || return
        cd .. || return
        \rm -rf dockerman
        cd "$BUILD_DIR"

        if declare -F docker_stack_sync_dockerman_nftables_compat >/dev/null 2>&1; then
            docker_stack_sync_dockerman_nftables_compat "$BUILD_DIR" "0" || return 1
        fi

        echo "dockerman 更新完成"
    fi
}


add_quickfile() {
    local repo_url="https://github.com/sbwml/luci-app-quickfile.git"
    local target_dir="$BUILD_DIR/package/emortal/quickfile"
    if [ -d "$target_dir" ]; then
        rm -rf "$target_dir"
    fi
    echo "正在添加 luci-app-quickfile..."
    if ! git_retry clone --depth 1 "$repo_url" "$target_dir"; then
        echo "错误：从 $repo_url 克隆 luci-app-quickfile 仓库失败" >&2
        exit 1
    fi

    local makefile_path="$target_dir/quickfile/Makefile"
    if [ -f "$makefile_path" ]; then
        sed -i '/\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-\$(ARCH_PACKAGES)/c\
\t\t\$(INSTALL_BIN) \$(PKG_BUILD_DIR)\/quickfile-aarch64_generic \$(1)\/usr\/bin\/quickfile' "$makefile_path"
    fi
}


update_argon() {
    local repo_url="https://github.com/ZqinKing/luci-theme-argon.git"
    local dst_theme_path="$BUILD_DIR/feeds/luci/themes/luci-theme-argon"
    local tmp_dir
    tmp_dir=$(mktemp -d)

    echo "正在更新 argon 主题..."

    if ! git_retry clone --depth 1 "$repo_url" "$tmp_dir"; then
        echo "错误：从 $repo_url 克隆 argon 主题仓库失败" >&2
        rm -rf "$tmp_dir"
        exit 1
    fi

    rm -rf "$dst_theme_path"
    rm -rf "$tmp_dir/.git"
    mv "$tmp_dir" "$dst_theme_path"

    echo "luci-theme-argon 更新完成"
}
