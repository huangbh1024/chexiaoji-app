# syntax=docker/dockerfile:1
#
# 车小记 Flutter Android 构建环境（固定版本，便于复现与卸载）
# 构建：
#   docker build -t cxj-flutter-builder:3.50.0 \
#     --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) \
#     -f deploy/flutter-builder/Dockerfile deploy/flutter-builder
#
# 国内镜像默认值：
#   apt       -> 清华
#   Flutter   -> storage.flutter-io.cn（失败回退 storage.googleapis.com）
#   pub       -> pub.flutter-io.cn
#   Android   -> mirrors.cloud.tencent.com/AndroidSDK（失败回退 dl.google.com）
#   Maven     -> maven.aliyun.com（通过 Gradle init.gradle 优先使用）
#
# 说明：
# - 仅用于构建 Android APK；iOS 仍需 macOS + Xcode。
# - 镜像内已接受 Android SDK License；公司环境请确认合规。
# - 不包含模拟器，也不适合日常 flutter run 热重载。
# - 签名 keystore 不要打进镜像，构建时挂载。
FROM ubuntu:24.04

ARG FLUTTER_VERSION=3.50.0
ARG CMDLINE_TOOLS_BUILD=16111833
ARG ANDROID_API=36
ARG BUILD_TOOLS=36.0.0
ARG USER_UID=1000
ARG USER_GID=1000

# 国内镜像（可用 --build-arg 覆盖）
ARG APT_MIRROR=http://mirrors.tuna.tsinghua.edu.cn
ARG FLUTTER_MIRROR=https://storage.flutter-io.cn
ARG ANDROID_MIRROR=https://mirrors.cloud.tencent.com/AndroidSDK
ARG PUB_MIRROR=https://pub.flutter-io.cn

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV FLUTTER_HOME=/opt/flutter
ENV PUB_CACHE=/home/dev/.pub-cache
ENV GRADLE_USER_HOME=/home/dev/.gradle
ENV PUB_HOSTED_URL="${PUB_MIRROR}"
ENV FLUTTER_STORAGE_BASE_URL="${FLUTTER_MIRROR}"
ENV PATH="${FLUTTER_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${PATH}"

# apt 走国内源；基础镜像没有 ca-certificates，所以先用 HTTP
RUN set -eux; \
    sed -i "s|http://archive.ubuntu.com/ubuntu|${APT_MIRROR}/ubuntu|g; \
            s|http://security.ubuntu.com/ubuntu|${APT_MIRROR}/ubuntu|g" \
        /etc/apt/sources.list.d/ubuntu.sources; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
      curl git unzip xz-utils zip libglu1-mesa ca-certificates openjdk-21-jdk; \
    rm -rf /var/lib/apt/lists/*

# Flutter SDK（国内镜像优先，断点续传；失败回退 Google）
RUN set -eux; \
    url="${FLUTTER_MIRROR}/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"; \
    fallback="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"; \
    curl -fL --retry 20 --retry-delay 3 --retry-all-errors --retry-max-time 3600 \
         --connect-timeout 30 -C - -o /tmp/flutter.tar.xz "$url" \
      || curl -fL --retry 20 --retry-delay 3 --retry-all-errors --retry-max-time 3600 \
         --connect-timeout 30 -C - -o /tmp/flutter.tar.xz "$fallback"; \
    tar -xf /tmp/flutter.tar.xz -C /opt; \
    rm -f /tmp/flutter.tar.xz; \
    git config --system --add safe.directory "${FLUTTER_HOME}"

# Android command-line tools（腾讯镜像优先，失败回退 Google）
RUN set -eux; \
    mkdir -p "${ANDROID_HOME}/cmdline-tools"; \
    url="${ANDROID_MIRROR}/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"; \
    fallback="https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_BUILD}_latest.zip"; \
    curl -fL --retry 20 --retry-delay 3 --retry-all-errors --retry-max-time 1800 \
         --connect-timeout 30 -C - -o /tmp/cmdline-tools.zip "$url" \
      || curl -fL --retry 20 --retry-delay 3 --retry-all-errors --retry-max-time 1800 \
         --connect-timeout 30 -C - -o /tmp/cmdline-tools.zip "$fallback"; \
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools; \
    mv /tmp/cmdline-tools/cmdline-tools "${ANDROID_HOME}/cmdline-tools/latest"; \
    rm -rf /tmp/cmdline-tools /tmp/cmdline-tools.zip

# 接受许可并安装 SDK；SDK_TEST_BASE_URL 让 sdkmanager 从腾讯镜像下载，失败后用官方源
RUN set -eux; \
    sdk_install() { \
      yes | sdkmanager --sdk_root="${ANDROID_HOME}" --licenses >/dev/null; \
      sdkmanager --sdk_root="${ANDROID_HOME}" --install \
        "platform-tools" \
        "platforms;android-${ANDROID_API}" \
        "build-tools;${BUILD_TOOLS}"; \
    }; \
    export SDK_TEST_BASE_URL="${ANDROID_MIRROR}/"; \
    if ! sdk_install; then \
      echo "腾讯 Android SDK 镜像安装失败，回退官方源"; \
      unset SDK_TEST_BASE_URL; \
      sdk_install; \
    fi; \
    rm -rf "${ANDROID_HOME}/.temp" "${ANDROID_HOME}/.android"

# 非 root 用户：UID/GID 与宿主机一致，避免产物变成 root 所有
RUN groupadd --gid "${USER_GID}" dev 2>/dev/null || true \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash dev \
    && mkdir -p "${PUB_CACHE}" "${GRADLE_USER_HOME}" \
    && printf '%s\n' \
       'org.gradle.jvmargs=-Xmx1536m -XX:MaxMetaspaceSize=512m' \
       'org.gradle.workers.max=2' \
       'org.gradle.parallel=false' \
       > "${GRADLE_USER_HOME}/gradle.properties" \
    && printf '%s\n' \
       'settingsEvaluated { settings ->' \
       "    settings.pluginManagement.repositories.clear()" \
       "    settings.pluginManagement.repositories {" \
       "        maven { url = uri('https://maven.aliyun.com/repository/google') }" \
       "        maven { url = uri('https://maven.aliyun.com/repository/gradle-plugin') }" \
       "        maven { url = uri('https://maven.aliyun.com/repository/public') }" \
       "        google()" \
       "        gradlePluginPortal()" \
       "        mavenCentral()" \
       "    }" \
       "    settings.dependencyResolutionManagement.repositories.clear()" \
       "    settings.dependencyResolutionManagement.repositories {" \
       "        maven { url = uri('https://maven.aliyun.com/repository/google') }" \
       "        maven { url = uri('https://maven.aliyun.com/repository/public') }" \
       "        google()" \
       "        mavenCentral()" \
       "    }" \
       '}' \
       > "${GRADLE_USER_HOME}/init.gradle" \
    && chown -R dev:dev "${FLUTTER_HOME}" "${ANDROID_HOME}" /home/dev

USER dev

# 预下载 Android 引擎产物（国内镜像，失败回退官方）；doctor 仅展示
RUN set -eux; \
    flutter config --no-analytics; \
    if ! flutter precache --android; then \
      echo "Flutter 引擎镜像失败，回退官方源"; \
      export FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com"; \
      flutter precache --android; \
    fi; \
    flutter doctor -v || true

WORKDIR /workspace
CMD ["bash"]
