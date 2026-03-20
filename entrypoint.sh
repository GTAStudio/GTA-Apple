#!/bin/bash
set -euo pipefail

echo "=========================================="
echo "  AltServer-Linux Container Starting"
echo "=========================================="
echo "Anisette Server: ${ALTSERVER_ANISETTE_SERVER}"
echo "USBMUXD Socket:  ${USBMUXD_SOCKET_ADDRESS}"
echo "=========================================="

# 等待 Anisette 服务就绪
echo "[*] 等待 Anisette 服务就绪..."
MAX_RETRIES="${ALT_ANISETTE_WAIT_RETRIES:-30}"
RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if curl -fsS --max-time 5 "${ALTSERVER_ANISETTE_SERVER}" > /dev/null 2>&1; then
        echo "[✓] Anisette 服务已就绪"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "[*] 等待中... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo "[!] 警告: Anisette 服务未就绪，继续启动..."
fi

# 启动 AltServer 守护进程
echo "[*] 启动 AltServer..."
exec AltServer "$@"
