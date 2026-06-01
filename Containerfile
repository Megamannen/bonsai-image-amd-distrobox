FROM docker.io/library/ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG SDCPP_REF=be65ac7511b30379b003626c15224798929e33d4

RUN apt-get update && apt-get install -y --no-install-recommends \
        build-essential \
        cmake \
        ninja-build \
        git \
        ca-certificates \
        curl \
        libvulkan-dev \
        mesa-vulkan-drivers \
        vulkan-tools \
        glslc \
        glslang-tools \
        spirv-headers \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/leejet/stable-diffusion.cpp.git /opt/sd.cpp \
    && cd /opt/sd.cpp \
    && git checkout "${SDCPP_REF}" \
    && git submodule update --init --recursive

RUN cmake -S /opt/sd.cpp -B /opt/sd.cpp/build \
        -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DSD_VULKAN=ON \
        -DSD_BUILD_SERVER=ON \
    && cmake --build /opt/sd.cpp/build --parallel "$(nproc)" \
    && cmake --install /opt/sd.cpp/build --prefix=/usr/local \
    && rm -rf /opt/sd.cpp/build

CMD ["/bin/bash"]
