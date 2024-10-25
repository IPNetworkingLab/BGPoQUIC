FROM alpine:3.20 AS base
RUN apk update && \
    apk upgrade --no-cache --available && \
    apk add --no-cache bash

FROM base AS builder
RUN apk add --no-cache bison flex ncurses-dev readline-dev \
            linux-headers libssh-dev ninja cmake make gcc g++ \
            doxygen graphviz git libevent-dev cunit-dev python3-dev \
            bsd-compat-headers libffi-dev perl openssl gcompat curl \
            autoconf && \
    git clone https://github.com/IPNetworkingLab/BGPoQUIC.git /opt/bgpoquic && \
    curl -L https://go.dev/dl/go1.20.14.linux-amd64.tar.gz -o /opt/go1.20.14.tar.gz && \
    cd /opt && \
    tar xf go1.20.14.tar.gz && \
    cd /opt/bgpoquic && \
    git submodule update --init --recursive && \
    cd quic_socket_api && \
    mkdir -p build/include && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=lib -G Ninja .. && \
    PATH="/opt/go/bin:$PATH" GOROOT="/opt/go" ninja && \
    ninja install && \
    ln -sf /opt/bgpoquic/quic_socket_api/build/_deps/picotls-build/*.a /opt/bgpoquic/quic_socket_api/build/lib/lib && \
    cd /opt/bgpoquic && \
    autoreconf -sif && \
    ./configure \
      --prefix=/usr \
      --sysconfdir=/etc/bird \
      --mandir=/usr/share/man \
      --localstatedir=/var \
      --runstatedir=/run \
      PICOQUIC_LIB=quic_socket_api/build/lib/lib \
      PICOQUIC_SOCK_API_LIB=quic_socket_api/build/lib/lib \
      PICOQUIC_SOCK_API_HDR=quic_socket_api/include/ && \
    make

FROM base
RUN mkdir /etc/bird
COPY --from=builder /opt/bgpoquic/bird /opt/bgpoquic/birdc /opt/bgpoquic/birdcl /usr/sbin
COPY --from=builder /opt/bgpoquic/doc/bird.conf.example /etc/bird/bird.conf
RUN apk add --no-cache readline libssh openssl libevent zlib tini

ENTRYPOINT [ "/sbin/tini", "--" ]
CMD [ "/usr/sbin/bird", "-f", "/etc/bird/bird.conf" ]


