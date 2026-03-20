#!/bin/bash
#
# GTA-Apple 自动部署脚本
# AltServer-Linux + Anisette v3 Server Docker 部署
#
# 用法:
#   ./run.sh              # 完整部署（构建+启动）
#   ./run.sh start        # 启动服务
#   ./run.sh stop         # 停止服务
#   ./run.sh restart      # 重启服务
#   ./run.sh status       # 查看服务状态
#   ./run.sh logs         # 查看日志
#   ./run.sh install      # 安装 IPA 到设备
#   ./run.sh update       # 更新镜像并重新部署
#   ./run.sh push         # 多架构推送 AltServer 镜像到 Docker Hub
#   ./run.sh pull         # 从 Docker Hub 拉取并部署
#   ./run.sh clean        # 清理所有容器和数据
#   ./run.sh health       # 健康检查
#

set -euo pipefail

# ============================================
# 配置
# ============================================
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
PROJECT_NAME="gta-apple"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ============================================
# 辅助函数
# ============================================
log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

compose_cmd() {
    $DOCKER_COMPOSE -p "$PROJECT_NAME" -f "$COMPOSE_FILE" "$@"
}

container_health() {
    local name="$1"
    docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$name" 2>/dev/null || echo "missing"
}

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║         GTA-Apple 自动部署系统               ║"
    echo "║   AltServer-Linux + Anisette v3 Server       ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 检查依赖
check_dependencies() {
    log_info "检查系统依赖..."

    if ! command -v docker &> /dev/null; then
        log_error "Docker 未安装。请先安装 Docker:"
        echo "  curl -fsSL https://get.docker.com | sh"
        echo "  sudo usermod -aG docker \$USER"
        exit 1
    fi
    log_ok "Docker 已安装: $(docker --version)"

    # 检查 docker compose (v2) 或 docker-compose (v1)
    if docker compose version &> /dev/null; then
        DOCKER_COMPOSE="docker compose"
        log_ok "Docker Compose (v2) 已安装"
    elif command -v docker-compose &> /dev/null; then
        DOCKER_COMPOSE="docker-compose"
        log_ok "Docker Compose (v1) 已安装: $(docker-compose --version)"
    else
        log_error "Docker Compose 未安装。请先安装 Docker Compose。"
        exit 1
    fi

    # 检查 Docker 守护进程
    if ! docker info &> /dev/null; then
        log_error "Docker 守护进程未运行。请启动 Docker:"
        echo "  sudo systemctl start docker"
        exit 1
    fi
    log_ok "Docker 守护进程运行中"

    if ! docker buildx version &> /dev/null; then
        log_error "Docker Buildx 不可用。需要它来发布多架构镜像。"
        exit 1
    fi
    log_ok "Docker Buildx 已安装"
}

# 初始化环境配置
init_env() {
    if [ ! -f "$ENV_FILE" ]; then
        log_info "创建 .env 配置文件..."
        cp .env.example "$ENV_FILE" 2>/dev/null || cat > "$ENV_FILE" << 'ENVEOF'
# GTA-Apple 环境配置
# AltServer 镜像地址
ALTSERVER_IMAGE=yourusername/gta-altserver:latest
# Docker Hub 用户名
DOCKERHUB_USERNAME=yourusername
# 自建镜像底层系统版本
DEBIAN_RELEASE=trixie
# Anisette 服务端口
ANISETTE_PORT=6969
# USBMUXD Socket 地址 (用于 WiFi 连接设备)
USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015
ENVEOF
        log_ok ".env 配置文件已创建"
    else
        log_ok ".env 配置文件已存在"
    fi
}

# 创建必要的目录
init_directories() {
    log_info "创建必要目录..."
    mkdir -p ipa
    log_ok "目录结构已就绪"
}

# 构建和启动服务
deploy() {
    print_banner
    check_dependencies
    init_env
    init_directories

    log_info "开始构建和部署..."

    # 拉取最新镜像
    log_info "拉取 Anisette v3 镜像..."
    compose_cmd pull anisette

    # 使用缓存构建 AltServer，仅拉取新的基础层
    log_info "构建 AltServer 镜像..."
    compose_cmd build --pull altserver

    # 启动服务
    log_info "启动所有服务..."
    compose_cmd up -d

    # 等待服务就绪
    wait_for_services

    echo ""
    log_ok "=========================================="
    log_ok "  部署完成！"
    log_ok "=========================================="
    show_service_info
}

# 启动服务
start_services() {
    check_dependencies
    log_info "启动服务..."
    compose_cmd up -d
    wait_for_services
    log_ok "所有服务已启动"
    show_service_info
}

# 停止服务
stop_services() {
    log_info "停止服务..."
    compose_cmd down
    log_ok "所有服务已停止"
}

# 重启服务
restart_services() {
    log_info "重启服务..."
    compose_cmd restart
    wait_for_services
    log_ok "所有服务已重启"
    show_service_info
}

# 查看服务状态
show_status() {
    echo ""
    log_info "服务状态:"
    echo "-------------------------------------------"
    compose_cmd ps
    echo ""
    health_check
}

# 查看日志
show_logs() {
    local service="${1:-}"
    if [ -n "$service" ]; then
        compose_cmd logs -f --tail=100 "$service"
    else
        compose_cmd logs -f --tail=100
    fi
}

# 安装 IPA
install_ipa() {
    local UDID="${1:-}"
    local APPLE_ID="${2:-}"
    local PASSWORD="${3:-}"
    local IPA_FILE="${4:-}"

    if [ -z "$UDID" ] || [ -z "$APPLE_ID" ] || [ -z "$PASSWORD" ] || [ -z "$IPA_FILE" ]; then
        echo ""
        echo "用法: $0 install <UDID> <AppleID> <密码> <IPA文件名>"
        echo ""
        echo "参数说明:"
        echo "  UDID      - 设备的 UDID"
        echo "  AppleID   - Apple ID 邮箱"
        echo "  密码      - Apple ID 密码"
        echo "  IPA文件名 - 放在 ipa/ 目录下的 IPA 文件名"
        echo ""
        echo "示例: $0 install 00008030-XXXX XXXX@icloud.com mypassword app.ipa"
        echo ""

        # 列出可用的 IPA 文件
        if compgen -G "ipa/*.ipa" > /dev/null; then
            echo "当前可用的 IPA 文件:"
            ls -la ipa/*.ipa
        else
            log_warn "ipa/ 目录中没有 IPA 文件，请先将 IPA 文件放入 ipa/ 目录"
        fi
        exit 1
    fi

    log_info "安装 IPA: $IPA_FILE -> 设备 $UDID"
    docker exec altserver AltServer \
        -u "$UDID" \
        -a "$APPLE_ID" \
        -p "$PASSWORD" \
        "/opt/altserver/ipa/$IPA_FILE"
    log_ok "IPA 安装完成"
}

# 更新部署
update_services() {
    print_banner
    check_dependencies

    log_info "更新服务..."

    # 拉取最新镜像
    log_info "拉取最新镜像..."
    compose_cmd pull anisette

    # 重新构建 AltServer
    log_info "重新构建 AltServer 镜像..."
    compose_cmd build --pull altserver

    # 重新创建并启动
    log_info "重新部署..."
    compose_cmd up -d --force-recreate

    wait_for_services
    log_ok "更新完成"
    show_service_info
}

# 推送 AltServer 镜像到 Docker Hub
push_image() {
    check_dependencies

    local username="${DOCKERHUB_USERNAME:-}"
    if [ -z "$username" ]; then
        log_error "请在 .env 中设置 DOCKERHUB_USERNAME"
        exit 1
    fi

    local image_name="${ALTSERVER_IMAGE:-${username}/gta-altserver:latest}"
    local tag="${1:-latest}"

    if [ "$tag" = "latest" ]; then
        image_name="${image_name%:*}:latest"
    else
        image_name="${image_name%:*}:${tag}"
    fi

    log_info "构建并推送多架构镜像 ${image_name}..."
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --build-arg DEBIAN_RELEASE="${DEBIAN_RELEASE:-trixie}" \
        --tag "${image_name}" \
        --file Dockerfile \
        --push \
        .

    log_ok "镜像已推送: ${image_name}"
}

# 从 Docker Hub 拉取并部署
pull_deploy() {
    print_banner
    check_dependencies
    init_env
    init_directories

    local image_name="${ALTSERVER_IMAGE:-}"
    if [ -z "$image_name" ]; then
        log_error "请在 .env 中设置 ALTSERVER_IMAGE"
        exit 1
    fi

    log_info "从镜像仓库拉取镜像: $image_name"
    compose_cmd pull anisette altserver

    log_info "启动服务..."
    compose_cmd up -d --no-build

    wait_for_services
    log_ok "部署完成 (使用 Docker Hub 镜像)"
    show_service_info
}

# 清理所有
clean_all() {
    log_warn "即将清理所有容器、镜像和数据卷！"
    read -r -p "确认清理？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消清理"
        exit 0
    fi

    log_info "停止并删除容器..."
    compose_cmd down -v --rmi local

    log_ok "清理完成"
}

# 等待服务就绪
wait_for_services() {
    log_info "等待服务就绪..."

    # 等待 Anisette 与 AltServer
    local max_wait=90
    local count=0
    while [ $count -lt $max_wait ]; do
        if curl -sf "http://127.0.0.1:${ANISETTE_PORT:-6969}" > /dev/null 2>&1 \
            && [ "$(container_health altserver)" = "healthy" ]; then
            log_ok "Anisette v3 与 AltServer 均已就绪"
            break
        fi
        count=$((count + 2))
        sleep 2
    done

    if [ $count -ge $max_wait ]; then
        log_warn "服务启动超时，请检查日志: $0 logs"
    fi
}

# 健康检查
health_check() {
    echo ""
    log_info "健康检查:"
    echo "-------------------------------------------"

    # 检查 Anisette
    local anisette_port="${ANISETTE_PORT:-6969}"
    if curl -sf "http://127.0.0.1:${anisette_port}" > /dev/null 2>&1; then
        log_ok "Anisette v3 (端口 $anisette_port)  ✓ 运行正常"
    else
        log_error "Anisette v3 (端口 $anisette_port)  ✗ 未响应"
    fi

    # 检查 AltServer 容器
    if docker ps --format '{{.Names}}' | grep -q "^altserver$"; then
        local altserver_health
        altserver_health="$(container_health altserver)"
        if [ "$altserver_health" = "healthy" ] || [ "$altserver_health" = "none" ]; then
            log_ok "AltServer 容器  ✓ 运行中"
        else
            log_error "AltServer 容器  ✗ 健康检查状态: $altserver_health"
        fi
    else
        log_error "AltServer 容器  ✗ 未运行"
    fi

    echo "-------------------------------------------"
}

# 显示服务信息
show_service_info() {
    echo ""
    echo -e "${CYAN}服务访问信息:${NC}"
    echo "-------------------------------------------"
    echo -e "  Anisette v3:  http://127.0.0.1:${ANISETTE_PORT:-6969}"
    echo -e "  AltServer:    容器 altserver 运行中"
    echo ""
    echo -e "${CYAN}常用命令:${NC}"
    echo "-------------------------------------------"
    echo "  $0 status      查看服务状态"
    echo "  $0 logs         查看日志"
    echo "  $0 logs anisette  查看 Anisette 日志"
    echo "  $0 logs altserver 查看 AltServer 日志"
    echo "  $0 install      安装 IPA"
    echo "  $0 push         多架构推送镜像"
    echo "  $0 restart      重启服务"
    echo "  $0 stop         停止服务"
    echo "  $0 pull         拉取镜像部署"
    echo ""
}

# 显示帮助
show_help() {
    print_banner
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "命令:"
    echo "  (无参数)                    完整部署（构建+启动）"
    echo "  start                       启动服务"
    echo "  stop                        停止服务"
    echo "  restart                     重启服务"
    echo "  status                      查看服务状态"
    echo "  logs [服务名]               查看日志（可选指定服务）"
    echo "  install <UDID> <ID> <密码> <IPA>  安装 IPA 到设备"
    echo "  update                      更新镜像并重新部署"
    echo "  push [tag]                  多架构推送 AltServer 镜像到 Docker Hub"
    echo "  pull                        从 Docker Hub 拉取并部署"
    echo "  clean                       清理所有容器和数据"
    echo "  health                      执行健康检查"
    echo "  help                        显示此帮助信息"
    echo ""
}

# ============================================
# 主入口
# ============================================

# 加载 .env
if [ -f "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

case "${1:-}" in
    start)
        start_services
        ;;
    stop)
        stop_services
        ;;
    restart)
        restart_services
        ;;
    status)
        show_status
        ;;
    logs)
        shift
        show_logs "$@"
        ;;
    install)
        shift
        install_ipa "$@"
        ;;
    update)
        update_services
        ;;
    push)
        shift
        push_image "$@"
        ;;
    pull)
        pull_deploy
        ;;
    clean)
        clean_all
        ;;
    health)
        health_check
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        deploy
        ;;
    *)
        log_error "未知命令: $1"
        show_help
        exit 1
        ;;
esac
