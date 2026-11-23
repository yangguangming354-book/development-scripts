#!/usr/bin/env bash

[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RAW_INSTALL_ZH_SH_URL="${FLOCKS_RAW_INSTALL_ZH_SH_URL:-https://gitee.com/flocks/flocks/raw/main/install_zh.sh}"
RAW_INSTALL_ZH_PS1_URL="${FLOCKS_RAW_INSTALL_ZH_PS1_URL:-https://gitee.com/flocks/flocks/raw/main/install_zh.ps1}"
UNOFFICIAL_NODE_INSTALL_SCRIPT_URL="${FLOCKS_UNOFFICIAL_NODE_INSTALL_SCRIPT_URL:-https://unofficial-builds.nodejs.org/install-node.sh}"
MIN_NODE_MAJOR=22

print_usage() {
  cat <<EOF
用法: ./scripts/install_zh.sh [--with-tui]

Flocks 中国用户源码安装脚本。
该脚本会默认使用国内软件源，并转交 ./scripts/install.sh 执行实际安装流程。

默认软件源：
  PyPI: https://mirrors.aliyun.com/pypi/simple
  npm : https://registry.npmmirror.com/
  uv  : https://astral.org.cn/uv/install.sh
  nvm : https://gitee.com/mirrors/nvm/raw/v0.40.3/install.sh
  旧版 glibc Node.js: https://unofficial-builds.nodejs.org/install-node.sh
  uv 备用源: https://uv.agentsmirror.com/install-cn.sh
  uv 官方回退: https://astral.sh/uv/install.sh

一键安装入口：
  curl -fsSL $RAW_INSTALL_ZH_SH_URL | bash
  curl -fsSL $RAW_INSTALL_ZH_SH_URL | bash -s -- --with-tui
  powershell -c "irm $RAW_INSTALL_ZH_PS1_URL | iex"

选项：
  --with-tui, -t  同时安装 TUI 依赖
  --help, -h      显示帮助信息
EOF
}

configure_cn_environment() {
  export FLOCKS_INSTALL_LANGUAGE="${FLOCKS_INSTALL_LANGUAGE:-zh-CN}"
  export FLOCKS_INSTALL_REPO_URL="${FLOCKS_INSTALL_REPO_URL:-https://gitee.com/flocks/flocks.git}"
  export FLOCKS_RAW_INSTALL_SH_URL="${FLOCKS_RAW_INSTALL_SH_URL:-$RAW_INSTALL_ZH_SH_URL}"
  export FLOCKS_RAW_INSTALL_PS1_URL="${FLOCKS_RAW_INSTALL_PS1_URL:-$RAW_INSTALL_ZH_PS1_URL}"
  export FLOCKS_UV_DEFAULT_INDEX="${FLOCKS_UV_DEFAULT_INDEX:-https://mirrors.aliyun.com/pypi/simple}"
  export FLOCKS_UV_INSTALL_SH_URL="${FLOCKS_UV_INSTALL_SH_URL:-https://astral.org.cn/uv/install.sh}"
  export FLOCKS_UV_INSTALL_SH_FALLBACK_URL="${FLOCKS_UV_INSTALL_SH_FALLBACK_URL:-https://uv.agentsmirror.com/install-cn.sh}"
  export FLOCKS_UV_INSTALL_SH_SECONDARY_FALLBACK_URL="${FLOCKS_UV_INSTALL_SH_SECONDARY_FALLBACK_URL:-https://astral.sh/uv/install.sh}"
  export FLOCKS_UV_INSTALL_PS1_URL="${FLOCKS_UV_INSTALL_PS1_URL:-https://astral.org.cn/uv/install.ps1}"
  export FLOCKS_UV_INSTALL_PS1_SECONDARY_FALLBACK_URL="${FLOCKS_UV_INSTALL_PS1_SECONDARY_FALLBACK_URL:-https://astral.sh/uv/install.ps1}"
  export FLOCKS_NPM_REGISTRY="${FLOCKS_NPM_REGISTRY:-https://registry.npmmirror.com/}"
  export FLOCKS_NVM_INSTALL_SCRIPT_URL="${FLOCKS_NVM_INSTALL_SCRIPT_URL:-https://gitee.com/mirrors/nvm/raw/v0.40.3/install.sh}"
  export PUPPETEER_CHROME_DOWNLOAD_BASE_URL="${PUPPETEER_CHROME_DOWNLOAD_BASE_URL:-https://cdn.npmmirror.com/binaries/chrome-for-testing}"
  export FLOCKS_NODEJS_MANUAL_DOWNLOAD_URL="${FLOCKS_NODEJS_MANUAL_DOWNLOAD_URL:-https://nodejs.org/zh-cn/download}"
}

node_version_is_compatible() {
  local node_major=""

  command -v node >/dev/null 2>&1 || return 1
  node_major="$(node -p 'process.versions.node.split(".")[0]' 2>/dev/null)" || return 1
  [[ "$node_major" =~ ^[0-9]+$ ]] && [[ "$node_major" -ge "$MIN_NODE_MAJOR" ]]
}

glibc_is_older_than_228() {
  local glibc_version=""

  command -v getconf >/dev/null 2>&1 || return 1
  glibc_version="$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{ print $2 }')" || return 1
  [[ -n "$glibc_version" ]] || return 1
  [[ "$(printf '2.28\n%s\n' "$glibc_version" | sort -V | head -n 1)" != "2.28" ]]
}

install_legacy_glibc_nodejs() {
  local installer=""
  local install_dir="/usr/local"
  local install_status=0
  local path_line='export PATH="$HOME/.local/nodejs-22/bin:$PATH"'

  [[ "$(uname -s 2>/dev/null || true)" == "Linux" ]] || return 0
  [[ "$(uname -m 2>/dev/null || true)" == "x86_64" ]] || return 0
  glibc_is_older_than_228 || return 0
  node_version_is_compatible && return 0

  printf '[flocks] 检测到 glibc 低于 2.28，正在安装兼容 glibc 2.17 的 Node.js %s...\n' "$MIN_NODE_MAJOR"

  installer="$(mktemp)"
  if ! curl -fsSL "$UNOFFICIAL_NODE_INSTALL_SCRIPT_URL" -o "$installer"; then
    rm -f "$installer"
    printf '[flocks] 错误: 下载旧版 glibc Node.js 安装器失败。\n' >&2
    return 1
  fi

  if [[ -w "$install_dir" ]]; then
    bash "$installer" --line "$MIN_NODE_MAJOR" --platform x64-glibc-217 --dir "$install_dir" --yes || install_status=$?
  elif command -v sudo >/dev/null 2>&1; then
    sudo bash "$installer" --line "$MIN_NODE_MAJOR" --platform x64-glibc-217 --dir "$install_dir" --yes || install_status=$?
  else
    install_dir="$HOME/.local/nodejs-22"
    mkdir -p "$install_dir"
    bash "$installer" --line "$MIN_NODE_MAJOR" --platform x64-glibc-217 --dir "$install_dir" --yes || install_status=$?
    export PATH="$install_dir/bin:$PATH"
    if [[ -n "${HOME:-}" ]]; then
      touch "$HOME/.bashrc"
      grep -Fqx "$path_line" "$HOME/.bashrc" || printf '\n%s\n' "$path_line" >> "$HOME/.bashrc"
    fi
  fi
  rm -f "$installer"

  [[ "$install_status" -eq 0 ]] || return "$install_status"
  hash -r 2>/dev/null || true

  if ! node_version_is_compatible || ! command -v npm >/dev/null 2>&1; then
    printf '[flocks] 错误: 兼容版 Node.js 安装完成，但 node 或 npm 不可用。\n' >&2
    return 1
  fi

  printf '[flocks] 已安装兼容版 Node.js %s，npm %s。\n' "$(node --version)" "$(npm --version)"
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    print_usage
    exit 0
  fi

  configure_cn_environment
  install_legacy_glibc_nodejs
  exec bash "$SCRIPT_DIR/install.sh" "$@"
}

main "$@"
