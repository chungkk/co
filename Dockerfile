# ---------- Biên dịch Pikafish (GPLv3: https://github.com/official-pikafish/Pikafish) ----------
# Dùng bản phát hành cố định, kiểm tra SHA-256 của mã nguồn, gói phát hành và file mạng nơ-ron.
# pikafish.nnue lấy từ chính gói phát hành để khớp phiên bản engine (giấy phép riêng: NNUE-License.md,
# không dùng cho mục đích thương mại khi chưa được phép).
FROM debian:bookworm-slim AS pikafish
ARG PIKA_TAG=Pikafish-2026-09-06
ARG PIKA_REL=Pikafish.2026-09-06.7z
ARG PIKA_SRC_SHA=4d905f5bb9d96632900aa88505d816e2d5997919e1375077a591cfeb0e6c7a10
ARG PIKA_REL_SHA=41952bbfe2520faceb5902c69e6ab4845cc999841d2b49a95cc1be7867a25e5b
ARG NNUE_SHA=7d13d73569a9b571ba0eb20cf1596247bc2a42738967e61afef6482b231e900e
RUN apt-get update && apt-get install -y --no-install-recommends build-essential ca-certificates curl p7zip-full \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /build
RUN curl -fsSL -o src.tgz "https://github.com/official-pikafish/Pikafish/archive/refs/tags/${PIKA_TAG}.tar.gz" \
 && echo "${PIKA_SRC_SHA}  src.tgz" | sha256sum -c - \
 && tar xzf src.tgz && mv "Pikafish-${PIKA_TAG}" pika \
 && curl -fsSL -o rel.7z "https://github.com/official-pikafish/Pikafish/releases/download/${PIKA_TAG}/${PIKA_REL}" \
 && echo "${PIKA_REL_SHA}  rel.7z" | sha256sum -c - \
 && 7z e -y rel.7z pikafish.nnue NNUE-License.md -o/build/pika/src >/dev/null \
 && echo "${NNUE_SHA}  pika/src/pikafish.nnue" | sha256sum -c -
# Máy build cũng là máy chạy (Coolify): chọn tập lệnh theo CPU
RUN cd pika/src \
 && case "$(uname -m)" in \
      aarch64) if grep -q asimddp /proc/cpuinfo; then A=armv8-dotprod; else A=armv8; fi ;; \
      x86_64) A=native ;; \
      *) A=general-64 ;; \
    esac \
 && echo "ARCH=$A" && make -j"$(nproc)" build ARCH="$A" COMP=gcc >/dev/null \
 && strip pikafish \
 && mkdir -p /opt/pikafish \
 && cp pikafish pikafish.nnue NNUE-License.md ../Copying.txt ../AUTHORS /opt/pikafish/ \
 && printf 'uci\nisready\nposition startpos\ngo depth 8\n' | (cd /opt/pikafish && timeout 20 ./pikafish) | grep -q bestmove

# ---------- Trang web (nginx) + máy chủ phân tích (Node) ----------
FROM nginx:1.27-bookworm
RUN apt-get update && apt-get install -y --no-install-recommends nodejs libstdc++6 \
 && rm -rf /var/lib/apt/lists/*
COPY --from=pikafish /opt/pikafish /opt/pikafish
COPY server/ /opt/engine-server/
COPY server/90-engine-server.sh /docker-entrypoint.d/90-engine-server.sh
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY site/ /usr/share/nginx/html/
RUN chmod +x /docker-entrypoint.d/90-engine-server.sh
EXPOSE 80
