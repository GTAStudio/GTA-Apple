# GTA-AltServer

AltServer-Linux Docker image with netmuxd, for iOS app sideloading.

Base image: Debian Trixie slim (current stable release).

## Quick Start

```bash
docker pull YOUR_USERNAME/gta-altserver:latest
```

Works with the official [Anisette v3 Server](https://hub.docker.com/r/dadoum/anisette-v3-server) for Apple authentication.

## Recommended Deployment

Use the repository's `run.sh` as the deployment entrypoint. It manages:

- Docker network creation
- volume creation
- `dadoum/anisette-v3-server` startup
- AltServer container startup
- health checks and restart flow

If the deployment host only keeps `run.sh`, configure `ALTSERVER_IMAGE` in `.env` and run the script in pull mode.

## Install IPA

```bash
docker exec altserver AltServer -u <UDID> -a <AppleID> -p <password> /opt/altserver/ipa/app.ipa
```

## Included Components

| Component | Version | Source |
|-----------|---------|--------|
| AltServer-Linux | v0.0.5 | [NyaMisty/AltServer-Linux](https://github.com/NyaMisty/AltServer-Linux) |
| netmuxd | v0.3.0 | [jkcoxson/netmuxd](https://github.com/jkcoxson/netmuxd) |
| Debian | Trixie slim | [Debian Official Images](https://hub.docker.com/_/debian) |

## Supported Architectures

- `linux/amd64`
- `linux/arm64`

Local publishing should use Docker Buildx so the pushed tag remains multi-architecture.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ALTSERVER_ANISETTE_SERVER` | `http://anisette:6969` | Anisette server URL |
| `ANISETTE_BIND_ADDRESS` | `127.0.0.1` | Recommended host bind address when publishing the Anisette port |
| `USBMUXD_SOCKET_ADDRESS` | `host.docker.internal:27015` | USBMUXD socket address |

## Source Code

[GitHub Repository](https://github.com/YOUR_USERNAME/GTA-Apple)
