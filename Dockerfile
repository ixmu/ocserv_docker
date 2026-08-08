# ==========================================
# 阶段 1：编译环境 (Builder)
# ==========================================
FROM alpine:latest AS builder

# 声明变量（如果不传参，默认是 1.3.0。如果 Actions 传了参数，就会覆盖这个默认值）
ARG OCSERV_VERSION=1.3.0

# 打印一下构建时的版本号，方便在 Actions 日志中确认
RUN echo "Building ocserv version: ${OCSERV_VERSION}"

# 安装编译所需的依赖...
RUN apk add --no-cache \
    build-base \
    curl \
    gnutls-dev \
    readline-dev \
    libnl3-dev \
    lz4-dev \
    libev-dev \
    protobuf-c-dev \
    pam-dev \
    libseccomp-dev \
    linux-headers \
    tar \
    xz

# 下载源码并编译安装到指定目录
RUN curl -SL "ftp://ftp.infradead.org/pub/ocserv/ocserv-${OCSERV_VERSION}.tar.xz" -o ocserv.tar.xz \
    && tar -xf ocserv.tar.xz \
    && cd ocserv-${OCSERV_VERSION} \
    && ./configure --prefix=/usr --sysconfdir=/etc \
    && make -j$(nproc) \
    && make install DESTDIR=/install_root


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
    pam \
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