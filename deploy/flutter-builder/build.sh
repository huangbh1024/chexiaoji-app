#!/usr/bin/env bash
# 车小记 Flutter Android 构建脚本（Docker，可选）
#
# 用法（在仓库根目录执行）：
#   ./deploy/flutter-builder/build.sh image   # 构建/更新构建镜像
#   ./deploy/flutter-builder/build.sh doctor # 在容器里执行 flutter doctor -v
#   ./deploy/flutter-builder/build.sh shell  # 进入容器 shell
#   ./deploy/flutter-builder/build.sh apk --release --target-platform android-arm64
#   ./deploy/flutter-builder/build.sh apk --debug
#   ./deploy/flutter-builder/build.sh apk --release --split-per-abi
#
# 环境变量：
#   IMAGE              镜像名（默认 cxj-flutter-builder:3.50.0）
#   APP_DIR            Flutter 工程相对仓库根的路径（默认 .，即仓库根）
#   GRADLE_DIST_MIRROR Gradle 发行包镜像（默认腾讯；设为 off 关闭临时替换）
set -euo pipefail

IMAGE="${IMAGE:-cxj-flutter-builder:3.50.0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
APP_DIR="${APP_DIR:-.}"
GRADLE_DIST_MIRROR="${GRADLE_DIST_MIRROR:-https://mirrors.cloud.tencent.com/gradle}"

WRAPPER_BAK=""
WRAPPER_DEST=""
restore_wrapper() {
  if [[ -n "$WRAPPER_BAK" && -n "$WRAPPER_DEST" && -f "$WRAPPER_BAK" ]]; then
    mv "$WRAPPER_BAK" "$WRAPPER_DEST"
  fi
}
trap restore_wrapper EXIT

# 构建前把 wrapper 的 services.gradle.org 临时换成国内镜像，构建结束（含失败）自动恢复。
# 优先用 -bin 包（体积约为 -all 的一半，构建足够）。
patch_gradle_wrapper() {
  local w="$REPO_ROOT/$APP_DIR/android/gradle/wrapper/gradle-wrapper.properties"
  [[ -f "$w" ]] || return 0
  [[ "$GRADLE_DIST_MIRROR" == "off" ]] && return 0
  grep -q 'services.gradle.org/distributions' "$w" || return 0
  WRAPPER_DEST="$w"
  WRAPPER_BAK="$w.cxj-bak"
  cp "$w" "$WRAPPER_BAK"
  # wrapper 文件里是 https\://...（冒号被转义），只替换 host/path，保留原有协议前缀
  local mirror_host_path="${GRADLE_DIST_MIRROR#*://}"
  sed -E -i "s#services\.gradle\.org/distributions/(gradle-[0-9.]+)-all\.zip#${mirror_host_path}/\1-bin.zip#" "$w"
  sed -E -i "s#services\.gradle\.org/distributions/#${mirror_host_path}/#" "$w"
  if grep -q 'services.gradle.org/distributions' "$w"; then
    echo "警告：Gradle Wrapper 镜像替换失败，仍使用官方源" >&2
  else
    echo "Gradle Wrapper 临时切换到国内镜像：$GRADLE_DIST_MIRROR"
  fi
}

build_image() {
  docker build -t "$IMAGE" \
    --build-arg "USER_UID=$(id -u)" \
    --build-arg "USER_GID=$(id -g)" \
    -f "$SCRIPT_DIR/Dockerfile" \
    "$@" \
    "$SCRIPT_DIR"
}

run_in() {
  local workdir="$1"
  shift
  # DOCKER_RUN_ARGS 用于追加挂载等参数，例如：-v "$HOME/keys:/keys:ro"
  # shellcheck disable=SC2086
  docker run --rm --init ${DOCKER_RUN_ARGS:-} \
    -v "$REPO_ROOT:/workspace" \
    -v cxj-flutter-pub-cache:/home/dev/.pub-cache \
    -v cxj-flutter-gradle-cache:/home/dev/.gradle \
    -v cxj-flutter-android-sdk:/opt/android-sdk \
    -w "$workdir" \
    "$IMAGE" "$@"
}

require_app() {
  if [[ ! -f "$REPO_ROOT/$APP_DIR/pubspec.yaml" ]]; then
    echo "找不到 Flutter 工程：$REPO_ROOT/$APP_DIR/pubspec.yaml" >&2
    echo "请在仓库根目录执行，或通过 APP_DIR=路径 指定工程目录。" >&2
    exit 1
  fi
}

case "${1:-}" in
  image)
    shift
    build_image "$@"
    ;;
  doctor)
    run_in /workspace flutter doctor -v
    ;;
  shell)
    run_in /workspace bash
    ;;
  apk)
    shift
    require_app
    patch_gradle_wrapper
    run_in "/workspace/$APP_DIR" flutter build apk "$@"
    echo
    echo "APK 输出目录：$REPO_ROOT/$APP_DIR/build/app/outputs/flutter-apk/"
    ;;
  *)
    echo "用法: $0 {image|doctor|shell|apk [flutter build apk 参数]}" >&2
    exit 1
    ;;
esac
