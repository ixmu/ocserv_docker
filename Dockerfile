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

# 1. 专门创建一个确定的构建目录并进入
WORKDIR /build_ocserv

# 2. 下载临时包
RUN curl -sSL "http://117.55.230.121/ocserv-1.5.0.tar.xz" -o ocserv.tar.xz

# 3. 核心修改：无视文件夹名称解压
# --strip-components=1 会把压缩包里第一层目录剥掉，把里面的文件直接平铺到当前的 /build_ocserv 目录下
RUN tar -xf ocserv.tar.xz --strip-components=1

# 4. 增加排错视野：打印当前目录所有文件
# 这样在 Action 日志里就能清楚看到 ./configure 到底存不存在，以及有没有权限
RUN ls -la

# 5. 执行配置
RUN ./configure --prefix=/usr --sysconfdir=/etc

# 6. 开始编译
RUN make -j$(nproc)

# 7. 安装
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