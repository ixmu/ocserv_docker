# ==========================================
# 阶段 1：编译环境 (Builder) - GitLab 源码直接编译版
# ==========================================
FROM alpine:latest AS builder

# 接收从 GitHub Actions 传进来的动态版本号
ARG OCSERV_VERSION=1.5.0

# 1. 安装极其完整的依赖环境（新增 git、gettext-dev 等底层构建工具）
RUN apk add --no-cache \
    build-base git gnutls-dev readline-dev libnl3-dev lz4-dev \
    libev-dev protobuf-c-dev linux-pam-dev libseccomp-dev linux-headers \
    coreutils pkgconf gperf talloc-dev \
    autoconf automake libtool bash gettext-dev

WORKDIR /build_ocserv

# 2. 【核心】直接从官方 GitLab 克隆对应版本的源码！
# 完美避开 infradead 网站对云服务器 IP 的封锁，不需要解压，绝对不会出现目录名错误
RUN git clone --depth 1 --branch ${OCSERV_VERSION} https://gitlab.com/openconnect/ocserv.git .

# 3. Git 仓库拉下来的源码默认没有 configure，必须生成
RUN autoreconf -fvi

# 4. 执行配置，开始编译
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