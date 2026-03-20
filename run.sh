#!/bin/bash
#
# GTA-Apple 自动部署脚本
# 单脚本管理 AltServer-Linux + Anisette v3 Server
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

ENV_FILE=".env"
DOCKERFILE_PATH="$SCRIPT_DIR/Dockerfile"
IPA_DIR="$SCRIPT_DIR/ipa"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

print_banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║         GTA-Apple 自动部署系统               ║"
    echo "║     AltServer-Linux + Anisette v3           ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"
}

load_env() {
    if [ -f "$ENV_FILE" ]; then
        set -a
        # shellcheck source=/dev/null
        source "$ENV_FILE"
        set +a
    fi

    ANISETTE_IMAGE="${ANISETTE_IMAGE:-dadoum/anisette-v3-server:latest}"
    ANISETTE_PORT="${ANISETTE_PORT:-6969}"
    ANISETTE_BIND_ADDRESS="${ANISETTE_BIND_ADDRESS:-127.0.0.1}"
    USBMUXD_SOCKET_ADDRESS="${USBMUXD_SOCKET_ADDRESS:-host.docker.internal:27015}"
    DEBIAN_RELEASE="${DEBIAN_RELEASE:-trixie}"
    NETWORK_NAME="${NETWORK_NAME:-altserver-network}"
    ANISETTE_CONTAINER="${ANISETTE_CONTAINER:-anisette-v3}"
    ALTSERVER_CONTAINER="${ALTSERVER_CONTAINER:-altserver}"
    ANISETTE_VOLUME="${ANISETTE_VOLUME:-anisette-v3_data}"
    ALTSERVER_VOLUME="${ALTSERVER_VOLUME:-altserver_data}"
    DOCKERHUB_USERNAME="${DOCKERHUB_USERNAME:-}"
    ALTSERVER_IMAGE="${ALTSERVER_IMAGE:-${DOCKERHUB_USERNAME:+${DOCKERHUB_USERNAME}/gta-altserver:latest}}"
    LOCAL_ALTSERVER_IMAGE="${LOCAL_ALTSERVER_IMAGE:-gta-apple/altserver:local}"
}

check_dependencies() {
    log_info "检查系统依赖..."

    if ! command -v docker >/dev/null 2>&1; then
        log_error "Docker 未安装。请先安装 Docker。"
        exit 1
    fi
    log_ok "Docker 已安装: $(docker --version)"

    if ! docker info >/dev/null 2>&1; then
        log_error "Docker 守护进程未运行。请先启动 Docker。"
        exit 1
    fi
    log_ok "Docker 守护进程运行中"
}

check_buildx() {
    if ! docker buildx version >/dev/null 2>&1; then
        log_error "Docker Buildx 不可用。需要它来发布多架构镜像。"
        exit 1
    fi
    log_ok "Docker Buildx 已安装"
}

init_env() {
    if [ -f "$ENV_FILE" ]; then
        log_ok ".env 配置文件已存在"
        return
    fi

    log_info "创建 .env 配置文件..."
    cat > "$ENV_FILE" << 'ENVEOF'
# GTA-Apple 环境配置
# 仅在镜像拉取部署或镜像推送时需要修改 ALTSERVER_IMAGE / DOCKERHUB_USERNAME

ALTSERVER_IMAGE=
DOCKERHUB_USERNAME=
DEBIAN_RELEASE=trixie
ANISETTE_PORT=6969
ANISETTE_BIND_ADDRESS=127.0.0.1
USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015
ENVEOF
    log_ok ".env 配置文件已创建"
}

init_directories() {
    mkdir -p "$IPA_DIR"
    log_ok "运行目录已就绪"
}

container_exists() {
    docker inspect "$1" >/dev/null 2>&1
}

container_running() {
    [ "$(docker inspect --format '{{.State.Running}}' "$1" 2>/dev/null || echo false)" = "true" ]
}

container_health() {
    docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null || echo "missing"
}

ensure_network() {
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_info "创建网络: $NETWORK_NAME"
        docker network create "$NETWORK_NAME" >/dev/null
    fi
}

ensure_volume() {
    local volume_name="$1"
    if ! docker volume inspect "$volume_name" >/dev/null 2>&1; then
        log_info "创建数据卷: $volume_name"
        docker volume create "$volume_name" >/dev/null
    fi
}

remove_container() {
    local container_name="$1"
    if container_exists "$container_name"; then
        log_info "删除旧容器: $container_name"
        docker rm -f "$container_name" >/dev/null
    fi
}

require_registry_image() {
    if [ -z "$ALTSERVER_IMAGE" ]; then
        log_error "当前是镜像拉取部署，但 .env 中未设置 ALTSERVER_IMAGE。"
        exit 1
    fi

    if [ "$ALTSERVER_IMAGE" = "yourusername/gta-altserver:latest" ]; then
        log_error "ALTSERVER_IMAGE 仍然是占位值，请改成你的真实镜像地址。"
        exit 1
    fi
}

prepare_runtime_resources() {
    ensure_network
    ensure_volume "$ANISETTE_VOLUME"
    ensure_volume "$ALTSERVER_VOLUME"
}

build_altserver_image() {
    local image_name="$1"

    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "未找到 Dockerfile，无法本地构建 AltServer 镜像。"
        exit 1
    fi

    log_info "构建 AltServer 镜像: $image_name"
    docker build \
        --pull \
        --build-arg DEBIAN_RELEASE="$DEBIAN_RELEASE" \
        --tag "$image_name" \
        --file "$DOCKERFILE_PATH" \
        "$SCRIPT_DIR"
}

run_anisette_container() {
    log_info "启动 Anisette 容器..."
    remove_container "$ANISETTE_CONTAINER"
    docker run -d \
        --name "$ANISETTE_CONTAINER" \
        --restart unless-stopped \
        --init \
        --network "$NETWORK_NAME" \
        -p "${ANISETTE_BIND_ADDRESS}:${ANISETTE_PORT}:6969" \
        -v "${ANISETTE_VOLUME}:/home/Alcoholic/.config/anisette-v3/lib/" \
        --health-cmd 'curl -f http://localhost:6969 || exit 1' \
        --health-interval 30s \
        --health-timeout 10s \
        --health-retries 3 \
        --health-start-period 15s \
        --log-driver json-file \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        "$ANISETTE_IMAGE" >/dev/null
}

run_altserver_container() {
    local image_name="$1"

    log_info "启动 AltServer 容器..."
    remove_container "$ALTSERVER_CONTAINER"
    docker run -d \
        --name "$ALTSERVER_CONTAINER" \
        --restart unless-stopped \
        --init \
        --network "$NETWORK_NAME" \
        --add-host host.docker.internal:host-gateway \
        -e "ALTSERVER_ANISETTE_SERVER=http://${ANISETTE_CONTAINER}:6969" \
        -e "USBMUXD_SOCKET_ADDRESS=${USBMUXD_SOCKET_ADDRESS}" \
        -v "${ALTSERVER_VOLUME}:/opt/altserver/data" \
        -v "${IPA_DIR}:/opt/altserver/ipa:ro" \
        --stop-timeout 20 \
        --health-cmd 'pgrep -x AltServer >/dev/null && curl -fsS --max-time 5 "$ALTSERVER_ANISETTE_SERVER" >/dev/null || exit 1' \
        --health-interval 30s \
        --health-timeout 5s \
        --health-retries 3 \
        --health-start-period 20s \
        --log-driver json-file \
        --log-opt max-size=10m \
        --log-opt max-file=3 \
        "$image_name" >/dev/null
}

wait_for_container_health() {
    local container_name="$1"
    local timeout_seconds="$2"
    local waited=0

    while [ "$waited" -lt "$timeout_seconds" ]; do
        case "$(container_health "$container_name")" in
            healthy)
                log_ok "$container_name 已就绪"
                return 0
                ;;
            unhealthy)
                log_error "$container_name 健康检查失败"
                return 1
                ;;
        esac
        sleep 2
        waited=$((waited + 2))
    done

    log_warn "$container_name 启动超时，请检查日志"
    return 1
}

wait_for_services() {
    log_info "等待服务就绪..."
    wait_for_container_health "$ANISETTE_CONTAINER" 90
    wait_for_container_health "$ALTSERVER_CONTAINER" 90
}

deploy_from_build() {
    local build_image="${ALTSERVER_IMAGE:-$LOCAL_ALTSERVER_IMAGE}"

    log_info "使用本地构建模式部署"
    docker pull "$ANISETTE_IMAGE"
    build_altserver_image "$build_image"
    prepare_runtime_resources
    run_anisette_container
    wait_for_container_health "$ANISETTE_CONTAINER" 90
    run_altserver_container "$build_image"
    wait_for_container_health "$ALTSERVER_CONTAINER" 90
}

deploy_from_registry() {
    require_registry_image

    log_info "使用镜像拉取模式部署"
    docker pull "$ANISETTE_IMAGE"
    docker pull "$ALTSERVER_IMAGE"
    prepare_runtime_resources
    run_anisette_container
    wait_for_container_health "$ANISETTE_CONTAINER" 90
    run_altserver_container "$ALTSERVER_IMAGE"
    wait_for_container_health "$ALTSERVER_CONTAINER" 90
}

deploy_auto() {
    if [ -f "$DOCKERFILE_PATH" ]; then
        deploy_from_build
    else
        deploy_from_registry
    fi
}

deploy() {
    print_banner
    check_dependencies
    init_env
    load_env
    init_directories
    deploy_auto
    log_ok "部署完成"
    show_service_info
}

start_services() {
    check_dependencies
    load_env

    if ! container_exists "$ANISETTE_CONTAINER" || ! container_exists "$ALTSERVER_CONTAINER"; then
        log_warn "容器不存在，转为执行部署流程"
        deploy
        return
    fi

    log_info "启动现有容器..."
    docker start "$ANISETTE_CONTAINER" >/dev/null
    wait_for_container_health "$ANISETTE_CONTAINER" 90
    docker start "$ALTSERVER_CONTAINER" >/dev/null
    wait_for_container_health "$ALTSERVER_CONTAINER" 90
    log_ok "所有服务已启动"
    show_service_info
}

stop_services() {
    check_dependencies
    load_env
    log_info "停止服务..."

    if container_exists "$ALTSERVER_CONTAINER"; then
        docker stop "$ALTSERVER_CONTAINER" >/dev/null
    fi
    if container_exists "$ANISETTE_CONTAINER"; then
        docker stop "$ANISETTE_CONTAINER" >/dev/null
    fi

    log_ok "所有服务已停止"
}

restart_services() {
    check_dependencies
    load_env

    if ! container_exists "$ANISETTE_CONTAINER" || ! container_exists "$ALTSERVER_CONTAINER"; then
        log_warn "容器不存在，转为执行部署流程"
        deploy
        return
    fi

    log_info "重启服务..."
    docker restart "$ANISETTE_CONTAINER" >/dev/null
    wait_for_container_health "$ANISETTE_CONTAINER" 90
    docker restart "$ALTSERVER_CONTAINER" >/dev/null
    wait_for_container_health "$ALTSERVER_CONTAINER" 90
    log_ok "所有服务已重启"
    show_service_info
}

show_status() {
    check_dependencies
    load_env
    echo ""
    log_info "服务状态:"
    echo "-------------------------------------------"
    for container_name in "$ANISETTE_CONTAINER" "$ALTSERVER_CONTAINER"; do
        if container_exists "$container_name"; then
            docker ps -a --filter "name=${container_name}" --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
        else
            echo "$container_name\tmissing\t-"
        fi
    done
    health_check
}

resolve_log_target() {
    case "${1:-}" in
        "" )
            echo ""
            ;;
        anisette|anisette-v3)
            echo "$ANISETTE_CONTAINER"
            ;;
        altserver)
            echo "$ALTSERVER_CONTAINER"
            ;;
        *)
            log_error "未知服务名: $1"
            exit 1
            ;;
    esac
}

show_logs() {
    check_dependencies
    load_env

    local target
    target="$(resolve_log_target "${1:-}")"
    if [ -n "$target" ]; then
        if ! container_exists "$target"; then
            log_error "容器不存在: $target"
            exit 1
        fi
        docker logs -f --tail=100 "$target"
        return
    fi

    if ! container_exists "$ANISETTE_CONTAINER" || ! container_exists "$ALTSERVER_CONTAINER"; then
        log_error "容器不存在，请先执行部署。"
        exit 1
    fi

    docker logs -f --tail=100 "$ANISETTE_CONTAINER" &
    local anisette_pid=$!
    docker logs -f --tail=100 "$ALTSERVER_CONTAINER" &
    local altserver_pid=$!
    trap 'kill "$anisette_pid" "$altserver_pid" 2>/dev/null || true' EXIT INT TERM
    wait "$anisette_pid" "$altserver_pid"
}

install_ipa() {
    check_dependencies
    load_env

    local udid="${1:-}"
    local apple_id="${2:-}"
    local password="${3:-}"
    local ipa_file="${4:-}"

    if [ -z "$udid" ] || [ -z "$apple_id" ] || [ -z "$password" ] || [ -z "$ipa_file" ]; then
        echo ""
        echo "用法: $0 install <UDID> <AppleID> <密码> <IPA文件名>"
        if compgen -G "$IPA_DIR/*.ipa" >/dev/null 2>&1; then
            echo ""
            echo "当前可用的 IPA 文件:"
            ls -la "$IPA_DIR"/*.ipa
        fi
        exit 1
    fi

    if ! container_running "$ALTSERVER_CONTAINER"; then
        log_error "AltServer 容器未运行，请先执行 $0 或 $0 start"
        exit 1
    fi

    if [ ! -f "$IPA_DIR/$ipa_file" ]; then
        log_error "未找到 IPA 文件: $IPA_DIR/$ipa_file"
        exit 1
    fi

    log_info "安装 IPA: $ipa_file -> 设备 $udid"
    docker exec "$ALTSERVER_CONTAINER" AltServer \
        -u "$udid" \
        -a "$apple_id" \
        -p "$password" \
        "/opt/altserver/ipa/$ipa_file"
    log_ok "IPA 安装完成"
}

update_services() {
    print_banner
    check_dependencies
    init_env
    load_env
    init_directories

    if [ -f "$DOCKERFILE_PATH" ]; then
        deploy_from_build
    else
        deploy_from_registry
    fi

    log_ok "更新完成"
    show_service_info
}

push_image() {
    check_dependencies
    check_buildx
    init_env
    load_env

    if [ ! -f "$DOCKERFILE_PATH" ]; then
        log_error "未找到 Dockerfile，无法执行镜像构建和推送。"
        exit 1
    fi

    local image_name="${ALTSERVER_IMAGE:-}"
    local tag="${1:-latest}"

    if [ -z "$image_name" ] && [ -n "$DOCKERHUB_USERNAME" ]; then
        image_name="${DOCKERHUB_USERNAME}/gta-altserver:latest"
    fi

    if [ -z "$image_name" ]; then
        log_error "请在 .env 中设置 ALTSERVER_IMAGE 或 DOCKERHUB_USERNAME。"
        exit 1
    fi

    image_name="${image_name%:*}:$tag"
    log_info "构建并推送多架构镜像: $image_name"
    docker buildx build \
        --platform linux/amd64,linux/arm64 \
        --build-arg DEBIAN_RELEASE="$DEBIAN_RELEASE" \
        --tag "$image_name" \
        --file "$DOCKERFILE_PATH" \
        --push \
        "$SCRIPT_DIR"
    log_ok "镜像已推送: $image_name"
}

pull_deploy() {
    print_banner
    check_dependencies
    init_env
    load_env
    init_directories
    deploy_from_registry
    log_ok "部署完成"
    show_service_info
}

clean_all() {
    check_dependencies
    load_env

    log_warn "即将删除容器、网络和数据卷。"
    read -r -p "确认清理？(y/N): " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        log_info "取消清理"
        exit 0
    fi

    remove_container "$ALTSERVER_CONTAINER"
    remove_container "$ANISETTE_CONTAINER"

    if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        docker network rm "$NETWORK_NAME" >/dev/null
    fi
    if docker volume inspect "$ANISETTE_VOLUME" >/dev/null 2>&1; then
        docker volume rm "$ANISETTE_VOLUME" >/dev/null
    fi
    if docker volume inspect "$ALTSERVER_VOLUME" >/dev/null 2>&1; then
        docker volume rm "$ALTSERVER_VOLUME" >/dev/null
    fi

    log_ok "清理完成"
}

health_check() {
    check_dependencies
    load_env
    echo ""
    log_info "健康检查:"
    echo "-------------------------------------------"

    if container_exists "$ANISETTE_CONTAINER"; then
        log_info "Anisette: $(container_health "$ANISETTE_CONTAINER")"
    else
        log_error "Anisette 容器不存在"
    fi

    if container_exists "$ALTSERVER_CONTAINER"; then
        log_info "AltServer: $(container_health "$ALTSERVER_CONTAINER")"
    else
        log_error "AltServer 容器不存在"
    fi

    echo "-------------------------------------------"
}

show_service_info() {
    echo ""
    echo -e "${CYAN}服务访问信息:${NC}"
    echo "-------------------------------------------"
    echo "  Anisette v3: http://127.0.0.1:${ANISETTE_PORT}"
    echo "  AltServer:   容器 ${ALTSERVER_CONTAINER}"
    echo ""
    echo -e "${CYAN}常用命令:${NC}"
    echo "-------------------------------------------"
    echo "  $0 status"
    echo "  $0 logs"
    echo "  $0 logs anisette"
    echo "  $0 logs altserver"
    echo "  $0 install <UDID> <AppleID> <密码> <IPA>"
    echo "  $0 restart"
    echo "  $0 stop"
    echo "  $0 pull"
    echo ""
}

show_help() {
    print_banner
    echo "用法: $0 [命令] [参数]"
    echo ""
    echo "说明:"
    echo "  默认优先本地构建部署；如果目录中没有 Dockerfile，则自动改为镜像拉取部署。"
    echo "  因此部署服务器只保留 run.sh 也可以，但需要在 .env 中设置 ALTSERVER_IMAGE。"
    echo "  Anisette 默认只绑定到 127.0.0.1；如需对外暴露，设置 ANISETTE_BIND_ADDRESS=0.0.0.0。"
    echo ""
    echo "命令:"
    echo "  (无参数)                    自动部署"
    echo "  start                       启动现有容器"
    echo "  stop                        停止服务"
    echo "  restart                     重启服务"
    echo "  status                      查看服务状态"
    echo "  logs [anisette|altserver]   查看日志"
    echo "  install <UDID> <ID> <密码> <IPA>  安装 IPA"
    echo "  update                      更新并重新部署"
    echo "  push [tag]                  多架构推送 AltServer 镜像"
    echo "  pull                        强制走镜像拉取部署"
    echo "  clean                       清理容器、网络、数据卷"
    echo "  health                      查看健康状态"
    echo "  help                        显示帮助信息"
    echo ""
}

load_env

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
