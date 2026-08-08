# ==========================================
# 阶段 1：编译环境 (Builder) - 拆分调试版
# ==========================================
FROM alpine:latest AS builder

# 安装所有可能的依赖
RUN apk add --no-cache \
    build-base \
    curl \
    gnutls-dev \
    readline-dev \
    libnl3-dev \
    lz4-dev \
    libev-dev \
    protobuf-c-dev \
    linux-pam-dev \
    libseccomp-dev \
    linux-headers \
    tar \
    xz \
    coreutils \
    pkgconf \
    gperf \
    talloc-dev

# 调试步骤 1：单独下载
RUN curl -sSL "http://117.55.230.121/ocserv-1.5.0.tar.xz" -o ocserv.tar.xz

# 调试步骤 2：单独解压
RUN tar -xf ocserv.tar.xz

# 切换工作目录（相当于在接下来的所有步骤前执行 cd ocserv-1.5.0）
WORKDIR /ocserv-1.5.0

# 调试步骤 3：配置生成 Makefile (如果报错127，说明 ./configure 内部找不到某些库或 pkg-config)
RUN ./configure --prefix=/usr --sysconfdir=/etc

# 调试步骤 4：开始编译 (如果报错127，说明系统里没有 make，或者没有 nproc，或者缺 gperf)
RUN make -j$(nproc)

# 调试步骤 5：安装到目标文件夹
RUN make install DESTDIR=/install_root


# ==========================================
# 阶段 2：运行环境 (Runtime)
# ==========================================
FROM alpine:latest

# 安装运行所需的动态库与网络工具（不包含庞大的编译工具链）
RUN apk add --no-cache \
    gnutls \
    readline \
    libnl3 \
    lz4-libs \
    libev \
    protobuf-c \
    linux-pam \
    libseccomp \
    iptables \
    iproute2 \
    gnutls-utils \
    tzdata

# 从 builder 阶段复制编译好的二进制文件
COPY --from=builder /install_root/usr/sbin/ocserv /usr/sbin/ocserv
COPY --from=builder /install_root/usr/sbin/ocserv-worker /usr/sbin/ocserv-worker
COPY --from=builder /install_root/usr/bin/occtl /usr/bin/occtl
COPY --from=builder /install_root/usr/bin/ocpasswd /usr/bin/ocpasswd

# 创建配置目录
RUN mkdir -p /etc/ocserv

# 暴露 VPN 默认端口（可根据配置文件修改）
EXPOSE 443/tcp 443/udp

# 以前台模式启动 ocserv，确保 Docker 容器不会退出
CMD ["ocserv", "-c", "/etc/ocserv/ocserv.conf", "-f"]