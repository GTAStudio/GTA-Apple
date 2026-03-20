# GTA-Apple 操作文档

这份文档是给实际部署用的。

目标是回答这几个问题：

- 服务器到底要准备什么
- 这些内容从哪里获取
- 第一次部署怎么做
- 后续怎么更新、怎么看日志、怎么安装 IPA

## 1. 架构说明

当前项目是双容器部署：

- `dadoum/anisette-v3-server:latest`
  - 官方社区维护的 Anisette 服务
- `aizhihuxiao/gta-altserver:latest`
  - 已经打包好的 AltServer 镜像

部署入口只有一个：

- `run.sh`

执行方式：

- 直接运行 `./run.sh` 进入交互菜单
- 或直接运行子命令，例如 `./run.sh pull`

## 2. 部署前准备

部署服务器至少需要：

- Docker
- `run.sh`

可选项：

- `.env`
  - 只有你想覆盖默认配置时才需要
- `ipa/`
  - 只有你要在服务器上执行 IPA 安装时才需要

不需要：

- `docker-compose.yml`
- `Dockerfile`
- `entrypoint.sh`

前提是你走的是镜像拉取部署，而不是服务器本地构建。

## 3. 部署文件从哪里获取

### 3.1 获取 `run.sh`

有两种方式。

方式 A：直接从 GitHub 仓库拿

- 仓库地址：`https://github.com/GTAStudio/GTA-Apple`
- 你只需要把仓库里的 `run.sh` 下载到服务器上

方式 B：本地改好后单独上传

- 把你当前仓库里的 `run.sh` 上传到服务器

### 3.2 获取 AltServer 镜像

当前默认内置镜像：

- `aizhihuxiao/gta-altserver:latest`

来源：

- Docker Hub 仓库：`https://hub.docker.com/repository/docker/aizhihuxiao/gta-altserver`

`run.sh` 已经写死这个默认值，所以服务器通常不用再手动填写。

### 3.3 获取 Anisette 镜像

这个不需要你单独准备。

脚本会自动拉取：

- `dadoum/anisette-v3-server:latest`

### 3.4 获取 `.env`

通常不需要你提前手工写。

因为：

- 如果目录里没有 `.env`
- `run.sh` 会自动基于 `.env.example` 生成一份

只有以下情况你才需要主动改 `.env`：

- 你想换 AltServer 镜像仓库
- 你想改 Anisette 端口
- 你想让 Anisette 对外监听，而不是只绑定 `127.0.0.1`
- 你想指定不同的 `USBMUXD_SOCKET_ADDRESS`

### 3.5 获取 IPA

只有你要在服务器上执行签名/安装时才需要。

来源就是你自己要签名的那个 `.ipa` 文件。

上传后放到：

- `ipa/你的文件名.ipa`

## 4. 服务器目录建议

最小目录：

```text
gta-apple/
  run.sh
```

推荐目录：

```text
gta-apple/
  run.sh
  .env
  ipa/
```

说明：

- `.env` 可选
- `ipa/` 可选

## 5. 第一次部署

进入服务器目录后执行：

```bash
chmod +x run.sh
./run.sh
```

然后你有两种用法。

### 5.1 交互方式

直接执行：

```bash
./run.sh
```

会进入菜单，你可以选择：

- 自动部署
- 强制拉取镜像部署
- 强制本地构建部署
- 查看状态
- 查看日志
- 安装 IPA
- 编辑 `.env`

### 5.2 非交互方式

如果你明确只想拉镜像部署，直接运行：

```bash
./run.sh pull
```

这会做这些事：

- 拉取 `dadoum/anisette-v3-server:latest`
- 拉取 `aizhihuxiao/gta-altserver:latest`
- 创建网络和数据卷
- 启动两个容器
- 等待健康检查完成

## 6. `.env` 怎么用

默认情况下，`.env` 不是必须的。

如果你需要自定义配置，可以写成这样：

```env
ALTSERVER_IMAGE=aizhihuxiao/gta-altserver:latest
DEBIAN_RELEASE=trixie
ANISETTE_BIND_ADDRESS=127.0.0.1
ANISETTE_PORT=6969
USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015
```

各项含义：

- `ALTSERVER_IMAGE`
  - AltServer 镜像地址
  - 当前默认已经内置，可选覆盖
- `DEBIAN_RELEASE`
  - 只有你在服务器本地构建镜像时才有意义
- `ANISETTE_BIND_ADDRESS`
  - 默认 `127.0.0.1`
  - 代表只允许本机访问 Anisette
- `ANISETTE_PORT`
  - 宿主机暴露端口，默认 `6969`
- `USBMUXD_SOCKET_ADDRESS`
  - WiFi refresh / netmuxd 相关配置

## 7. IPA 安装流程

### 7.1 把 IPA 上传到服务器

上传后目录类似：

```text
gta-apple/
  run.sh
  ipa/
    app.ipa
```

### 7.2 准备安装参数

你需要：

- 设备 UDID
- Apple ID
- Apple ID 密码
- IPA 文件名

### 7.3 执行安装

方式 A：交互式

```bash
./run.sh
```

菜单里选择：

- `安装 IPA`

方式 B：命令行直接安装

```bash
./run.sh install <UDID> <AppleID> <密码> <IPA文件名>
```

示例：

```bash
./run.sh install 00008030XXXXXXXX user@example.com your-password app.ipa
```

## 8. 常用运维命令

查看状态：

```bash
./run.sh status
```

查看健康状态：

```bash
./run.sh health
```

查看全部日志：

```bash
./run.sh logs
```

只看 Anisette 日志：

```bash
./run.sh logs anisette
```

只看 AltServer 日志：

```bash
./run.sh logs altserver
```

重启服务：

```bash
./run.sh restart
```

停止服务：

```bash
./run.sh stop
```

更新部署：

```bash
./run.sh update
```

清理容器、网络和数据卷：

```bash
./run.sh clean
```

## 9. 更新 `run.sh`

如果后续仓库里的脚本有更新，服务器更新方式很简单：

1. 用新版本 `run.sh` 覆盖旧文件
2. 重新赋权
3. 执行更新命令

```bash
chmod +x run.sh
./run.sh update
```

## 10. 故障排查

### 10.1 脚本执行失败

先确认：

- Docker 已安装
- Docker daemon 正在运行
- `run.sh` 有执行权限

### 10.2 容器没起来

先看状态：

```bash
./run.sh status
```

然后看日志：

```bash
./run.sh logs anisette
./run.sh logs altserver
```

### 10.3 Anisette 没响应

检查健康状态：

```bash
./run.sh health
```

默认只绑定到本机：

- `127.0.0.1:6969`

如果你要远程访问才需要改：

- `ANISETTE_BIND_ADDRESS=0.0.0.0`

### 10.4 需要进入容器排查

进入 AltServer 容器：

```bash
docker exec -it altserver bash
```

进入 Anisette 容器：

```bash
docker exec -it anisette-v3 sh
```

## 11. 推荐部署口径

对于你现在这个项目，推荐使用下面这套最简流程：

1. 服务器只上传 `run.sh`
2. 需要安装 IPA 时再上传 `ipa/xxx.ipa`
3. 直接执行：

```bash
./run.sh
```

如果你不想走菜单，直接：

```bash
./run.sh pull
```

这样最省事，也最符合你现在“只维护 run”的目标。