# ============================================
# GTA-AltServer Docker Image
# AltServer-Linux + netmuxd
# 基于 Debian Trixie (当前稳定版)
# ============================================

ARG DEBIAN_RELEASE=trixie
ARG ALTSERVER_VERSION=v0.0.5
ARG NETMUXD_VERSION=v0.3.0

# Stage 1: 下载 AltServer-Linux 和 netmuxd
# ============================================
FROM debian:${DEBIAN_RELEASE}-slim AS downloader

ARG TARGETARCH
ARG ALTSERVER_VERSION
ARG NETMUXD_VERSION

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        ca-certificates \
        curl \
        jq; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# 下载 AltServer-Linux (根据架构选择)
RUN set -eux; \
    case "${TARGETARCH}" in \
        "amd64") ARCH_SUFFIX="x86_64" ;; \
        "arm64") ARCH_SUFFIX="aarch64" ;; \
        *) ARCH_SUFFIX="x86_64" ;; \
    esac; \
    ALTSERVER_URL="$(curl -fsSL --retry 5 --retry-all-errors https://api.github.com/repos/NyaMisty/AltServer-Linux/releases/latest \
        | jq -r ".assets[] | select(.name == \"AltServer-${ARCH_SUFFIX}\") | .browser_download_url" \
        | head -n 1)"; \
    if [ -z "$ALTSERVER_URL" ] || [ "$ALTSERVER_URL" = "null" ]; then \
        ALTSERVER_URL="https://github.com/NyaMisty/AltServer-Linux/releases/download/${ALTSERVER_VERSION}/AltServer-${ARCH_SUFFIX}"; \
    fi; \
    curl -fsSL --retry 5 --retry-all-errors -o /tmp/AltServer "$ALTSERVER_URL"; \
    chmod +x /tmp/AltServer

# 下载 netmuxd (根据架构选择)
RUN set -eux; \
    case "${TARGETARCH}" in \
        "amd64") ARCH_SUFFIX="x86_64" ;; \
        "arm64") ARCH_SUFFIX="aarch64" ;; \
        *) ARCH_SUFFIX="x86_64" ;; \
    esac; \
    NETMUXD_URL="$(curl -fsSL --retry 5 --retry-all-errors https://api.github.com/repos/jkcoxson/netmuxd/releases/latest \
        | jq -r ".assets[] | select(.name | contains(\"${ARCH_SUFFIX}\") and (contains(\"linux\") or contains(\"Linux\"))) | .browser_download_url" \
        | head -n 1)"; \
    if [ -z "$NETMUXD_URL" ] || [ "$NETMUXD_URL" = "null" ]; then \
        NETMUXD_URL="https://github.com/jkcoxson/netmuxd/releases/download/${NETMUXD_VERSION}/netmuxd-${ARCH_SUFFIX}-linux"; \
    fi; \
    curl -fsSL --retry 5 --retry-all-errors -o /tmp/netmuxd "$NETMUXD_URL"; \
    chmod +x /tmp/netmuxd

# ============================================
# Stage 2: 运行环境
# ============================================
FROM debian:${DEBIAN_RELEASE}-slim

LABEL org.opencontainers.image.title="GTA-AltServer"
LABEL org.opencontainers.image.description="AltServer-Linux with netmuxd for iOS sideloading"
LABEL org.opencontainers.image.source="https://github.com/YOUR_USERNAME/GTA-Apple"

ARG DEBIAN_RELEASE

RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y \
        bash \
        ca-certificates \
        curl \
        libimobiledevice-utils \
        procps \
        usbmuxd; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# 创建运行用户
RUN set -eux; \
    useradd --create-home --shell /bin/bash --uid 10001 altserver; \
    mkdir -p /opt/altserver/data /opt/altserver/ipa; \
    chown -R altserver:altserver /opt/altserver

WORKDIR /opt/altserver

# 从下载阶段复制二进制文件
COPY --from=downloader /tmp/AltServer /usr/local/bin/AltServer
COPY --from=downloader /tmp/netmuxd /usr/local/bin/netmuxd
COPY --chown=altserver:altserver entrypoint.sh /opt/altserver/entrypoint.sh
RUN chmod +x /opt/altserver/entrypoint.sh

# 环境变量
ENV ALTSERVER_ANISETTE_SERVER=http://anisette:6969
ENV USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015

USER altserver:altserver

HEALTHCHECK --interval=30s --timeout=5s --start-period=20s --retries=3 \
    CMD pgrep -x AltServer >/dev/null && curl -fsS --max-time 5 "$ALTSERVER_ANISETTE_SERVER" >/dev/null || exit 1

ENTRYPOINT ["/opt/altserver/entrypoint.sh"]
