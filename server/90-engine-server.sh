#!/bin/sh
# Chạy máy chủ phân tích (Pikafish) nền trước khi nginx khởi động; tự chạy lại nếu thoát.
(
  while true; do
    node /opt/engine-server/engine-server.js
    echo "engine-server thoát, chạy lại sau 2 giây" >&2
    sleep 2
  done
) &
