# GTA-Apple 最小部署清单

这份文档只回答一件事：

- 服务器最少要上传什么
- 上传完后执行什么

## 1. 最小上传内容

如果你只是部署服务，不在服务器本地构建镜像，最少只需要：

```text
run.sh
```

可选内容：

```text
.env
ipa/
```

说明：

- `.env`
  - 可选
  - 只有你想覆盖默认配置时才需要
- `ipa/`
  - 可选
  - 只有你要在服务器上执行 IPA 安装时才需要

## 2. 默认会拉哪些镜像

脚本默认会拉这两个镜像：

- `dadoum/anisette-v3-server:latest`
- `aizhihuxiao/gta-altserver:latest`

所以大多数情况下，服务器不需要手动配置镜像地址。

## 3. 第一次部署命令

上传 `run.sh` 后执行：

```bash
chmod +x run.sh
./run.sh
```

如果你不想进交互菜单，直接拉镜像部署：

```bash
./run.sh pull
```

## 4. 如果你要装 IPA

额外上传：

```text
ipa/你的文件.ipa
```

然后执行：

```bash
./run.sh
```

或者直接：

```bash
./run.sh install <UDID> <AppleID> <密码> <IPA文件名>
```

## 5. 如果你要覆盖默认配置

这时才需要 `.env`，例如：

```env
ALTSERVER_IMAGE=aizhihuxiao/gta-altserver:latest
ANISETTE_BIND_ADDRESS=127.0.0.1
ANISETTE_PORT=6969
USBMUXD_SOCKET_ADDRESS=host.docker.internal:27015
```

## 6. 推荐给部署人员的话术

直接发这三条就够：

1. 上传 `run.sh`
2. 执行 `chmod +x run.sh ; ./run.sh`
3. 如果要安装应用，再上传 `ipa/xxx.ipa`