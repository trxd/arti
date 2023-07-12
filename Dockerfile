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

COPY --from=builder /usr/local/cargo/bin/arti /bin/

ARG USER=arti
ARG WORKDIR=/arti

COPY arti.toml $WORKDIR/.config/arti.toml

RUN apk add -U --no-cache \
    xz-libs \
    sqlite-libs \
    openssl \
    libgcc

RUN addgroup -S arti \
    && adduser -h $WORKDIR -S arti -G arti \
    && chown -R $USER:$USER $WORKDIR

USER $USER

WORKDIR $WORKDIR

VOLUME $WORKDIR

ENTRYPOINT ["arti"]

CMD ["proxy"]
