#!/bin/sh
# Chạy máy chủ phân tích (Pikafish) nền trước khi nginx khởi động; tự chạy lại nếu thoát.
# Cổng cố định 8080 nội bộ (nginx chuyển /api/ tới đây), không phụ thuộc biến PORT của nền tảng.
echo "90-engine-server: node $(node --version 2>&1), pikafish $(ls -la /opt/pikafish/pikafish 2>&1 | awk '{print $5}') byte" >&2
(
  while true; do
    ENGINE_PORT=8080 ENGINE_HOST=127.0.0.1 node /opt/engine-server/engine-server.js
    echo "engine-server thoát (mã $?), chạy lại sau 2 giây" >&2
    sleep 2
  done
) &
