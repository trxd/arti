# Source: https://github.com/chriswayg/tor-alpine/blob/master/Dockerfile
# Dockerfile for Tor Relay Server with obfs4proxy (Multi-Stage build)
FROM golang:1-alpine AS go-build

# Build /go/bin/lyrebird & /go/bin/meek-server
RUN apk add --update git \
 && git clone https://gitlab.torproject.org/tpo/anti-censorship/pluggable-transports/lyrebird.git \
 && cd lyrebird \
 && go build -trimpath --ldflags "-s -w -buildid=" -v -o /go/bin/lyrebird cmd/lyrebird/*.go \
 && go install -trimpath --ldflags "-s -w -buildid=" -v \
    git.torproject.org/pluggable-transports/meek.git/meek-server@latest \
 && cp -rv /go/bin /usr/local/

FROM thetorproject/snowflake-proxy AS snowflake-artifact

FROM rust:alpine3.17 AS builder

ENV RUSTFLAGS="-C target-feature=-crt-static"
ENV CARGO_UNSTABLE_SPARSE_REGISTRY=true

RUN rustup install nightly \
    && rustup default nightly \
    && apk add -U --no-cache \
       musl-dev \
       pkgconfig \
       openssl-dev \
       sqlite-dev \
       xz-dev \
    && cargo install arti

FROM alpine:3.17

COPY --from=builder /usr/local/cargo/bin/arti /usr/bin/arti
COPY --from=go-build /usr/local/bin/ /usr/local/bin/
COPY --from=snowflake-artifact /bin/proxy /usr/bin/snowflake

ARG USER=arti
ARG WORKDIR=/etc/arti
ARG CACHEDIR=/var/cache/arti

COPY arti.toml $WORKDIR/arti.toml

RUN apk add -U --no-cache \
    xz-libs \
    sqlite-libs \
    openssl \
    libgcc

RUN addgroup -S arti \
    && adduser -h $WORKDIR -S arti -G arti \
    && mkdir -p $CACHEDIR \
    && chown -R $USER:$USER $WORKDIR $CACHEDIR

USER $USER

WORKDIR $WORKDIR

VOLUME $WORKDIR

ENTRYPOINT ["arti"]

CMD ["proxy", "-c", "arti.toml"]
