ARG BUILDER_IMAGE
ARG RUNNER_IMAGE

FROM ${BUILDER_IMAGE} as builder

ARG VERSION
ARG BUILD_TARGET=docker_node

RUN apk add --no-cache --update \
    git tar build-base linux-headers autoconf automake libtool pkgconfig \
    dbus-dev bzip2 bison flex gmp-dev cmake lz4 libsodium-dev openssl-dev \
    sed curl cargo

# Install Rust toolchain
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

WORKDIR /usr/src/node

ENV CC=gcc CXX=g++ CFLAGS="-U__sun__" \
    ERLANG_ROCKSDB_OPTS="-DWITH_BUNDLE_SNAPPY=ON -DWITH_BUNDLE_LZ4=ON" \
    ERL_COMPILER_OPTIONS="[deterministic]" \
    PATH="/root/.cargo/bin:$PATH" \
    RUSTFLAGS="-C target-feature=-crt-static"

# Add our code
ADD . /usr/src/node/

RUN DIAGNOSTIC=1 ./rebar3 as ${BUILD_TARGET} tar -v ${VERSION} -n blockchain_node \
        && mkdir -p /opt/docker \
        && tar -zxvf _build/${BUILD_TARGET}/rel/*/*.tar.gz -C /opt/docker

FROM ${RUNNER_IMAGE} as runner

ARG VERSION

RUN apk add --no-cache --update ncurses dbus gmp libsodium gcc
RUN ulimit -n 64000

WORKDIR /opt/blockchain_node

ENV COOKIE=node \
    # Write files generated during startup to /tmp
    RELX_OUT_FILE_PATH=/tmp \
    # add miner to path, for easy interactions
    PATH=/sbin:/bin:/usr/bin:/usr/local/bin:/opt/blockchain_node/bin:$PATH

COPY --from=builder /opt/docker /opt/node

RUN ln -sf /config /opt/node/releases/$VERSION

ENTRYPOINT ["/opt/blockchain_node/bin/blockchain_node"]
CMD ["foreground"]
