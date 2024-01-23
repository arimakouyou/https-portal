FROM debian:bookworm-slim

ARG NGINX_VERSION=1.25.3
#ARG NGINX_CHANGESET=7c2adf237091
ARG OPENSSL_URL=https://github.com/quictls/openssl
ARG OPENSSL_BRANCH=openssl-3.1.4+quic


RUN mkdir -p /usr/local/src \
    && apt update \
    && apt install --no-install-recommends --no-install-suggests -y \
           patch \
           curl \
           git \
           ca-certificates \
           gcc \
           make \
           libpcre3 \
           libpcre3-dev \
           zlib1g \
           zlib1g-dev \
           libxslt1.1 \
           libxslt1-dev \
           libgd3 \
           libgd-dev \
           libgeoip1 \
           libgeoip-dev \
           libperl-dev \
           mercurial \
           libxml2 \
           libxml2-dev \
    && git clone -b $OPENSSL_BRANCH --depth=1 $OPENSSL_URL /usr/local/src/openssl \
    && hg clone https://hg.nginx.org/nginx /usr/local/src/nginx \
    && hg clone http://hg.nginx.org/njs /usr/local/src/njs \
    && cd /usr/local/src/nginx \
    && hg update release-$NGINX_VERSION

    RUN cd /usr/local/src/openssl \
    && ./config \
    && make \
    && make install

    RUN  cd /usr/local/src/nginx \
    && auto/configure --with-openssl=/usr/local/src/openssl --with-openssl-opt=enable-tls1_3 --prefix=/etc/nginx --sbin-path=/usr/sbin/nginx --add-module=/usr/local/src/njs/nginx --modules-path=/usr/lib/nginx/modules --conf-path=/etc/nginx/nginx.conf --error-log-path=/var/log/nginx/error.log --http-log-path=/var/log/nginx/access.log --pid-path=/var/run/nginx.pid --lock-path=/var/run/nginx.lock --http-client-body-temp-path=/var/cache/nginx/client_temp --http-proxy-temp-path=/var/cache/nginx/proxy_temp --http-fastcgi-temp-path=/var/cache/nginx/fastcgi_temp --http-uwsgi-temp-path=/var/cache/nginx/uwsgi_temp --http-scgi-temp-path=/var/cache/nginx/scgi_temp --user=nginx --group=nginx --with-compat --with-file-aio --with-threads --with-http_addition_module --with-http_auth_request_module --with-http_dav_module --with-http_flv_module --with-http_gunzip_module --with-http_gzip_static_module --with-http_mp4_module --with-http_random_index_module --with-http_realip_module --with-http_secure_link_module --with-http_slice_module --with-http_ssl_module --with-http_stub_status_module --with-http_sub_module --with-http_v2_module --with-mail --with-mail_ssl_module --with-stream --with-stream_realip_module --with-stream_ssl_module --with-stream_ssl_preread_module --with-http_v3_module --with-cc-opt='-g -O2 -fdebug-prefix-map=/data/builder/debuild/nginx-1.17.0/debian/debuild-base/nginx-1.17.0=. -fstack-protector-strong -Wformat -Werror=format-security -Wp,-D_FORTIFY_SOURCE=2 -fPIC' --with-ld-opt='-Wl,-z,relro -Wl,-z,now -Wl,--as-needed -pie' --with-openssl=/usr/local/src/openssl \
    && make && make install \
    && mkdir -p /etc/nginx/conf.d

    RUN echo /usr/local/lib64 > /etc/ld.so.conf.d/openssl.conf

FROM debian:bookworm-slim

COPY --from=0 /etc/nginx /etc/nginx
COPY --from=0 /usr/sbin/nginx* /usr/sbin/
COPY --from=0 /usr/local/bin/openssl /usr/local/bin/openssl
COPY --from=0 /usr/local/bin/c_rehash /usr/local/bin/c_rehash
COPY --from=0 /usr/local/ssl /usr/local/ssl
COPY --from=0 /usr/local/lib64 /usr/local/lib64
COPY --from=0 /etc/ld.so.conf.d/openssl.conf /etc/ld.so.conf.d/openssl.conf

WORKDIR /root

RUN apt-get update && \
    apt-get install -y python3 ruby cron iproute2 apache2-utils logrotate wget inotify-tools libxml2 xz-utils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Need this already now, but cannot copy remainder of fs_overlay yet
COPY ./fs_overlay/bin/archname /bin/
COPY ./nginx /etc/init.d/

ENV S6_OVERLAY_VERSION 3.1.5.0
ENV DOCKER_GEN_VERSION 0.9.0
ENV ACME_TINY_VERSION 5.0.1
ENV S6_CMD_WAIT_FOR_SERVICES_MAXTIME 0

#RUN sh -c "wget -q https://github.com/just-containers/s6-overlay/releases/download/$S6_OVERLAY_VERSION/s6-overlay-`archname s6-overlay`.tar.gz -O /tmp/s6-overlay.tar.gz" && \
#    tar xzf /tmp/s6-overlay.tar.gz -C / && \
#    rm -rf /tmp/s6-overlay.tar.gz

RUN wget -q https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-noarch.tar.xz -O /tmp/s6-overlay-noarch.tar.xz && \
    wget -q https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-x86_64.tar.xz -O /tmp/s6-overlay-x86_64.tar.xz && \
    wget -q https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-symlinks-noarch.tar.xz -O /tmp/s6-overlay-symlinks-noarch.tar.xz && \
    wget -q https://github.com/just-containers/s6-overlay/releases/download/v3.1.5.0/s6-overlay-symlinks-arch.tar.xz -O /tmp/s6-overlay-symlinks-arch.tar.xz && \
    tar xJf /tmp/s6-overlay-noarch.tar.xz -C / && \
    tar xJf /tmp/s6-overlay-x86_64.tar.xz -C / && \
    tar xJf /tmp/s6-overlay-symlinks-noarch.tar.xz -C / && \
    tar xJf /tmp/s6-overlay-symlinks-arch.tar.xz -C / && \
    rm -rf /tmp/s6-overlay-noarch.tar.xz && \
    rm -rf /tmp/s6-overlay-x86_64.tar.xz && \
    rm -rf /tmp/s6-overlay-symlinks-noarch.tar.xz && \
    rm -rf /tmp/s6-overlay-symlinks-arch.tar.xz



RUN /bin/sh -c "wget -q https://github.com/jwilder/docker-gen/releases/download/$DOCKER_GEN_VERSION/docker-gen-linux-`archname docker-gen`-$DOCKER_GEN_VERSION.tar.gz -O /tmp/docker-gen.tar.gz" && \
    tar xzf /tmp/docker-gen.tar.gz -C /bin && \
    rm -rf /tmp/docker-gen.tar.gz

# Bring the container down if stage fails
ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2

RUN wget -q https://raw.githubusercontent.com/diafygi/acme-tiny/$ACME_TINY_VERSION/acme_tiny.py -O /bin/acme_tiny

COPY ./fs_overlay/var /var/
COPY ./fs_overlay/opt /opt/
COPY ./fs_overlay/bin /bin/
COPY ./fs_overlay/etc /etc/

RUN groupadd -r nginx \
  && useradd -r -g nginx -s /bin/false -M nginx \
  && mkdir -p /var/log/nginx \
  && ln -sf /dev/stdout /var/log/nginx/access.log \
  && ln -sf /dev/stderr /var/log/nginx/error.log \
  && mkdir -p /var/cache/nginx && \
    chmod a+x /bin/* && \
    chmod 0644 /etc/logrotate.d/nginx && \
    chmod 755 /etc/init.d/nginx

VOLUME /var/lib/https-portal
VOLUME /var/log/nginx

# HEALTHCHECK --interval=5s --timeout=1s --start-period=2s --retries=20 CMD   service nginx status || exit 1

ENTRYPOINT ["/init"]

