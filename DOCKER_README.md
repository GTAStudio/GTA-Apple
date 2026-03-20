# GTA-AltServer

AltServer-Linux Docker image with netmuxd, for iOS app sideloading.

Base image: Debian Trixie slim (current stable release).

## Quick Start

```bash
docker pull YOUR_USERNAME/gta-altserver:latest
```

Works with the official [Anisette v3 Server](https://hub.docker.com/r/dadoum/anisette-v3-server) for Apple authentication.

## Docker Compose (Recommended)

```yaml
services:
  anisette:
    image: dadoum/anisette-v3-server:latest
    restart: always
    ports:
      - "6969:6969"
    volumes:
      - anisette_data:/home/Alcoholic/.config/anisette-v3/lib/

  altserver:
    image: YOUR_USERNAME/gta-altserver:latest
    restart: always
    depends_on:
      - anisette
    environment:
      - ALTSERVER_ANISETTE_SERVER=http://anisette:6969
    volumes:
      - ./ipa:/opt/altserver/ipa:ro

volumes:
  anisette_data:
```

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
| `USBMUXD_SOCKET_ADDRESS` | `host.docker.internal:27015` | USBMUXD socket address |

## Source Code

[GitHub Repository](https://github.com/YOUR_USERNAME/GTA-Apple)
