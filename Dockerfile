#3rd time that i change of os.
FROM alpine:latest

RUN apk update && apk add --no-cache \
    build-base \
    g++ \
    curl-dev \
    libidn2-dev \
    libpsl-dev \
    zstd-dev \
    curl-static \
    openssl-libs-static \
    zlib-static \
    brotli-static \
    nghttp2-static \
    libpsl-static \
    libidn2-static \
    libunistring-static \
    zstd-static

WORKDIR /app