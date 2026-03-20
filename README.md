# GTA-Apple: AltServer + Anisette Docker 部署

[![Build and Push](https://github.com/YOUR_USERNAME/GTA-Apple/actions/workflows/docker-publish.yml/badge.svg)](https://github.com/YOUR_USERNAME/GTA-Apple/actions/workflows/docker-publish.yml)

## 架构

```
┌───────────────────────────────────────────────────────┐
│                   Docker Network                      │
│                                                       │
│  ┌──────────────────┐   ┌──────────────────────────┐  │
│  │  Anisette v3     │   │  AltServer-Linux         │  │
│  │  (官方维护镜像)    │◄──│  (自建镜像 → Docker Hub) │  │
│  │  :6969            │   │                          │  │
│  └──────────────────┘   └──────────────────────────┘  │
│                                  │                    │
└──────────────────────────────────┼────────────────────┘
                                   │
                          USB/WiFi 连接 iOS 设备
```

**镜像发布策略：**
- **Anisette v3** → `dadoum/anisette-v3-server` — 官方社区维护，直接引用，无需自建
- **AltServer** → `YOUR_USERNAME/gta-altserver` — 自建镜像，通过 GitHub Actions 自动构建推送到 Docker Hub
- **底层 Linux** → `Debian Trixie slim` — 当前稳定版，兼顾新包与稳定性

## Docker Hub

```bash
docker pull YOUR_USERNAME/gta-altserver:latest
```

支持架构：`linux/amd64`、`linux/arm64`

## 已做的稳定性优化

- AltServer 自建镜像升级到 `Debian Trixie slim`，不再停留在旧的 `bookworm`
- 构建阶段增加下载重试和回退逻辑，降低 GitHub API 抖动导致的失败率
- 运行容器切换为非 root 用户，降低容器权限风险
- Compose 增加 `healthcheck`、`init: true`、`unless-stopped`，并在依赖 Anisette 变更时联动重启，启动和重启行为更稳
- `run.sh` 去掉默认 `--no-cache`，改为复用缓存并拉取新的基础层，构建明显更快
- `pull` 部署路径改为 `--no-build`，避免生产环境误触发本地构建
- AltServer 不再暴露未被上游官方文档证实的宿主机端口，减少误导和无效暴露面
- `run.sh push` 改为 `buildx` 多架构推送，和文档宣称的 `amd64/arm64` 支持一致

## 快速开始

### 1. 克隆项目

```bash
git clone https://github.com/YOUR_USERNAME/GTA-Apple.git
cd GTA-Apple
```

### 2. 一键部署

```bash
chmod +x run.sh
./run.sh
```

### 3. 检查状态

```bash
./run.sh status
./run.sh health
```

## 安装 IPA 到设备

1. 将 IPA 文件放到 `ipa/` 目录
2. 获取设备 UDID
3. 执行安装：

```bash
./run.sh install <UDID> <AppleID> <密码> <IPA文件名>
```

示例：
```bash
./run.sh install 00008030-XXXXXXXXXXXX user@icloud.com password123 app.ipa
```

## 常用命令

| 命令 | 说明 |
|------|------|
| `./run.sh` | 完整部署（首次使用） |
| `./run.sh start` | 启动服务 |
| `./run.sh stop` | 停止服务 |
| `./run.sh restart` | 重启服务 |
| `./run.sh status` | 查看状态 |
| `./run.sh logs` | 查看所有日志 |
| `./run.sh logs anisette` | 查看 Anisette 日志 |
| `./run.sh logs altserver` | 查看 AltServer 日志 |
| `./run.sh update` | 更新并重新部署 |
| `./run.sh push [tag]` | 本地多架构构建并推送 AltServer 镜像 |
| `./run.sh pull` | 从镜像仓库拉取 AltServer 并部署 |
| `./run.sh clean` | 清理所有数据 |
| `./run.sh health` | 健康检查 |

## 配置说明

复制 `.env.example` 为 `.env` 并按需修改（首次运行会自动创建）：

```bash
cp .env.example .env
```

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ALTSERVER_IMAGE` | yourusername/gta-altserver:latest | AltServer 镜像地址 |
| `DOCKERHUB_USERNAME` | yourusername | 本地 `push` 用的 Docker Hub 用户名 |
| `DEBIAN_RELEASE` | trixie | 自建镜像底层 Debian 稳定版 |
| `ANISETTE_PORT` | 6969 | Anisette 服务端口 |
| `USBMUXD_SOCKET_ADDRESS` | host.docker.internal:27015 | USBMUXD 地址 |

## WiFi 刷新支持

如需 WiFi 刷新功能，在宿主机上运行 netmuxd：

```bash
# 先用 USB 配对设备
sudo systemctl start usbmuxd
# 连接设备并信任

# 停止 usbmuxd，启动 netmuxd
sudo systemctl stop usbmuxd
./netmuxd --disable-unix --host 0.0.0.0
```

## 容器说明

### Anisette v3 Server (官方维护 - 无需自建)
- 镜像：`dadoum/anisette-v3-server:latest`
- 维护者：[Dadoum](https://github.com/Dadoum/anisette-v3-server) (SideStore 核心开发者)
- 端口：6969
- 提供 Apple 认证所需的 Anisette 数据
- 活跃维护中 (436 stars, 100K+ Docker pulls)
- 数据持久化到 `anisette-v3_data` 卷

### AltServer-Linux (自建镜像 → Docker Hub)
- 镜像：`YOUR_USERNAME/gta-altserver:latest`
- 基于 Debian Trixie slim 构建
- 包含 AltServer-Linux v0.0.5 和 netmuxd v0.3.0
- 支持 amd64 / arm64 多架构
- 通过 GitHub Actions 自动构建并推送到 Docker Hub
- 不对外暴露伪 HTTP 端口，主要通过 USB/WiFi mux 与设备交互
- IPA 文件通过 `ipa/` 目录挂载

## CI/CD 发布流程

推送到 `main` 分支或打 `v*` tag 时，GitHub Actions 会自动：
1. 构建 `linux/amd64` 和 `linux/arm64` 多架构镜像
2. 推送到 Docker Hub (`YOUR_USERNAME/gta-altserver`)
3. 推送到 GitHub Container Registry (`ghcr.io`)
4. 更新 Docker Hub 描述

### 配置 GitHub Secrets

在仓库 Settings → Secrets → Actions 中添加：

| Secret | 说明 |
|--------|------|
| `DOCKERHUB_USERNAME` | Docker Hub 用户名 |
| `DOCKERHUB_TOKEN` | Docker Hub Access Token |

## 故障排除

```bash
# 查看容器日志
./run.sh logs

# 测试 Anisette 服务
curl http://127.0.0.1:6969

# 进入 AltServer 容器
docker exec -it altserver bash

# 重新构建
./run.sh update
```
