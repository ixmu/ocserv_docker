# ==========================================
# 阶段 1：编译环境 (Builder)
# ==========================================
FROM alpine:latest AS builder

# 1. 加入 autoconf、automake、libtool、bash 和 dos2unix (专门解决各种 127 疑难杂症)
RUN apk add --no-cache \
    build-base curl gnutls-dev readline-dev libnl3-dev lz4-dev \
    libev-dev protobuf-c-dev linux-pam-dev libseccomp-dev linux-headers \
    tar xz coreutils pkgconf gperf talloc-dev \
    autoconf automake libtool bash dos2unix

WORKDIR /build_ocserv

RUN curl -sSL "http://117.55.230.121/ocserv-1.5.0.tar.xz" -o ocserv.tar.xz

RUN tar -xf ocserv.tar.xz --strip-components=1

# 2. 智能预处理环节：
# - 如果没有 configure 文件，就用 autoreconf 自动生成
# - 修复可能的 Windows 换行符问题
# - 赋予执行权限
RUN if [ ! -f "./configure" ]; then \
        echo "configure does not exist. Generating..."; \
        autoreconf -fvi; \
    fi \
    && dos2unix configure \
    && chmod +x configure

# 3. 使用 bash 显式执行 configure，彻底避开默认 sh 的兼容性问题
RUN bash ./configure --prefix=/usr --sysconfdir=/etc

RUN make -j$(nproc)

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