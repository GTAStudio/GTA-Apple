# GTA-Apple: 只维护 run.sh 的部署方式

这个仓库现在以 `run.sh` 为唯一部署入口。

- 不再依赖 `docker-compose.yml`
- 服务器上只保留 `run.sh` 也能部署
- 无参数执行 `./run.sh` 会进入交互菜单
- 如果目录里有 `Dockerfile`，默认走本地构建模式
- 如果目录里没有 `Dockerfile`，默认走镜像拉取模式

详细部署步骤和运维说明见 [DEPLOYMENT.md](DEPLOYMENT.md)。
给部署人员看的极简清单见 [MINIMAL_DEPLOY.md](MINIMAL_DEPLOY.md)。

## 最小部署方式

部署服务器只需要这些内容：

- `run.sh`
- 可选 `.env`，只有你想覆盖默认参数时才需要
- `ipa/` 目录，只有安装 IPA 时才需要

首次执行会自动生成 `.env`。

```bash
chmod +x run.sh
./run.sh
```

如果服务器上没有 `Dockerfile`，脚本会自动要求从镜像仓库拉取 AltServer 镜像。
默认内置的 AltServer 镜像是 `aizhihuxiao/gta-altserver:latest`。
如果目录里存在 `.env`，脚本会自动加载；如果不存在，会基于 `.env.example` 自动生成。

## 配置

首次运行会自动生成 `.env`，核心变量如下：

| 变量 | 说明 |
|------|------|
| `ALTSERVER_IMAGE` | 可选覆盖项，默认已内置为 `aizhihuxiao/gta-altserver:latest` |
| `DOCKERHUB_USERNAME` | 本地执行 `./run.sh push` 时可选，用来推导镜像名 |
| `DEBIAN_RELEASE` | 本地构建 AltServer 镜像时使用的 Debian 版本，默认 `trixie` |
| `ANISETTE_BIND_ADDRESS` | Anisette 绑定地址，默认 `127.0.0.1`，仅本机可访问 |
| `ANISETTE_PORT` | 宿主机暴露的 Anisette 端口，默认 `6969` |
| `USBMUXD_SOCKET_ADDRESS` | WiFi 刷新场景下的 netmuxd 地址 |

## 常用命令

| 命令 | 说明 |
|------|------|
| `./run.sh` | 进入交互菜单 |
| `./run.sh deploy` | 自动部署，优先本地构建，否则回退到镜像拉取 |
| `./run.sh deploy-build` | 强制本地构建部署 |
| `./run.sh config` | 交互式修改 `.env` |
| `./run.sh pull` | 强制从镜像仓库拉取并部署 |
| `./run.sh start` | 启动现有容器 |
| `./run.sh stop` | 停止容器 |
| `./run.sh restart` | 重启容器 |
| `./run.sh status` | 查看状态 |
| `./run.sh logs` | 查看全部日志 |
| `./run.sh logs anisette` | 查看 Anisette 日志 |
| `./run.sh logs altserver` | 查看 AltServer 日志 |
| `./run.sh update` | 更新并重新部署 |
| `./run.sh install <UDID> <AppleID> <密码> <IPA>` | 安装 IPA |
| `./run.sh push [tag]` | 多架构构建并推送 AltServer 镜像 |
| `./run.sh clean` | 清理容器、网络、数据卷 |
| `./run.sh health` | 查看健康状态 |

## 运行逻辑

脚本直接调用这些 Docker 原生命令管理服务：

- `docker network create`
- `docker volume create`
- `docker run`
- `docker rm -f`
- `docker pull`
- `docker build`

也就是说，部署服务器侧不需要再额外维护 Compose 文件。

## 镜像说明

- `dadoum/anisette-v3-server:latest`：官方社区维护的 Anisette 容器，直接复用
- `AltServer` 镜像：仓库内 `Dockerfile` 本地构建，或者通过 `ALTSERVER_IMAGE` 从仓库拉取
- 底层系统：`Debian Trixie slim`
- Anisette 默认只绑定到宿主机 `127.0.0.1`，避免 Docker 默认的全网卡暴露；如果你确实要提供远程访问，再把 `ANISETTE_BIND_ADDRESS` 改成 `0.0.0.0`

## 安装 IPA

把 IPA 放到 `ipa/` 目录后执行：

```bash
./run.sh install <UDID> <AppleID> <密码> <IPA文件名>
```

## 故障排查

```bash
./run.sh status
./run.sh health
./run.sh logs altserver
docker exec -it altserver bash
```
