FROM amd64/ubuntu:20.04 as toolchain

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install --no-install-recommends -y \
    automake bison bzip2 ca-certificates cmake curl file flex g++ \
    gawk gdb git gperf help2man libncurses-dev libssl-dev libtool-bin \
    make ninja-build patch pkg-config python3 sudo texinfo unzip wget \
    xz-utils libssl-dev libffi-dev && \
    cd /tmp && \
    curl -O http://crosstool-ng.org/download/crosstool-ng/crosstool-ng-1.25.0.tar.bz2 && \
    tar xjf crosstool-ng-1.25.0.tar.bz2 && \
    cd crosstool-ng-1.25.0 && \
    ./bootstrap && \
    ./configure --prefix=/usr/local && \
    make -j4 && make install && \
    cd .. && \
    rm -rf crosstool-ng-1.25.0 && \
    rm crosstool-ng-1.25.0.tar.bz2

COPY .config /tmp/toolchain.config

RUN mkdir -p /tmp/build && \
    cp /tmp/toolchain.config /tmp/build/.config && \
    cd /tmp/build/ && \
    export CT_ALLOW_BUILD_AS_ROOT_SURE=1 && \
    ct-ng build.4 && \
    cd .. && \
    rm -rf build
    
FROM amd64/centos:7 as x86_64_cross_aarch64

COPY --from=toolchain /usr/aarch64-unknown-linux-gnu /usr/aarch64-unknown-linux-gnu

ENV PATH=$PATH:/usr/aarch64-unknown-linux-gnu/bin

ENV CC_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-gcc \
    AR_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-ar \
    CXX_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-g++

ENV TARGET_CC=aarch64-unknown-linux-gnu-gcc \
    TARGET_AR=aarch64-unknown-linux-gnu-ar \
    TARGET_RANLIB=aarch64-unknown-linux-gnu-ranlib \
    TARGET_CXX=aarch64-unknown-linux-gnu-g++ \
    TARGET_READELF=aarch64-unknown-linux-gnu-readelf \
    TARGET_SYSROOT=/usr/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/ \
    TARGET_C_INCLUDE_PATH=/usr/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/usr/include/

ENV CARGO_BUILD_TARGET=aarch64-unknown-linux-gnu
ENV CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=aarch64-unknown-linux-gnu-gcc
RUN echo "set(CMAKE_SYSTEM_NAME Linux)\nset(CMAKE_SYSTEM_PROCESSOR aarch64)\nset(CMAKE_SYSROOT /usr/aarch64-unknown-linux-gnu/aarch64-unknown-linux-gnu/sysroot/)\nset(CMAKE_C_COMPILER aarch64-unknown-linux-gnu-gcc)\nset(CMAKE_CXX_COMPILER aarch64-unknown-linux-gnu-g++)" > /usr/aarch64-unknown-linux-gnu/cmake-toolchain.cmake
ENV TARGET_CMAKE_TOOLCHAIN_FILE_PATH=/usr/aarch64-unknown-linux-gnu/cmake-toolchain.cmake

ENV RUSTUP_HOME=/usr/local/rustup \
    CARGO_HOME=/usr/local/cargo \
    PATH=/usr/local/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal \
    && rustup target add "aarch64-unknown-linux-gnu" \
    # Reduce memory consumption by avoiding cargo's libgit2
    && echo -e "[net]\ngit-fetch-with-cli = true" > $CARGO_HOME/config
