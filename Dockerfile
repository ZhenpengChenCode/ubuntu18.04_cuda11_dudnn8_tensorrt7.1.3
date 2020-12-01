# Copyright (c) 2020, NVIDIA CORPORATION. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

ARG CUDA_VERSION=11.0
ARG OS_VERSION=16.04
ARG NVCR_SUFFIX=
FROM nvidia/cuda:${CUDA_VERSION}-cudnn8-devel-ubuntu${OS_VERSION}${NVCR_SUFFIX}

LABEL maintainer="Chen Zhenpeng"

ARG uid=1000
ARG gid=1000
RUN groupadd -r -f -g ${gid} trtuser && useradd -r -u ${uid} -g ${gid} -ms /bin/bash trtuser
RUN usermod -aG sudo trtuser
RUN echo 'trtuser:nvidia' | chpasswd
RUN mkdir -p /workspace && chown trtuser /workspace

RUN mkdir -p /usr/local/src
COPY clean-layer.sh /usr/bin/clean-layer.sh
RUN chmod a+rwx /usr/bin/clean-layer.sh


# Install requried libraries
RUN apt-get update && apt-get install -y software-properties-common && clean-layer.sh
RUN add-apt-repository ppa:ubuntu-toolchain-r/test
RUN apt-get update && apt-get install -y --no-install-recommends \
    libcurl4-openssl-dev \
    wget \
    zlib1g-dev \
    git \
    pkg-config \
    sudo \
    ssh \
    libssl-dev \
    pbzip2 \
    pv \
    bzip2 \
    unzip \
    devscripts \
    lintian \
    fakeroot \
    dh-make \
    build-essential \
    gcc \
    make \
    unzip \
    zip \
    g++ \
    vim \
    openssh-server \
    libgoogle-glog-dev \
    && clean-layer.sh

RUN . /etc/os-release &&\
    if [ "$VERSION_ID" = "16.04" ]; then \
    add-apt-repository ppa:deadsnakes/ppa && apt-get update &&\
    apt-get remove -y python3 python && apt-get autoremove -y &&\
    apt-get install -y python3.6 python3.6-dev &&\
    cd /tmp && wget https://bootstrap.pypa.io/get-pip.py && python3.6 get-pip.py &&\
    python3.6 -m pip install wheel &&\
    ln -s /usr/bin/python3.6 /usr/bin/python3 &&\
    ln -s /usr/bin/python3.6 /usr/bin/python; \
    else \
    apt-get update &&\
    apt-get install -y --no-install-recommends \
      python3 \
      python3-pip \
      python3-dev \
      python3-wheel &&\
    cd /usr/local/bin &&\
    ln -s /usr/bin/python3 python &&\
    ln -s /usr/bin/pip3 pip; \
    fi

RUN pip3 install --upgrade pip
RUN pip3 install setuptools>=41.0.0

# Install Cmake
RUN cd /tmp && \
    wget https://github.com/Kitware/CMake/releases/download/v3.14.4/cmake-3.14.4-Linux-x86_64.sh && \
    chmod +x cmake-3.14.4-Linux-x86_64.sh && \
    ./cmake-3.14.4-Linux-x86_64.sh --prefix=/usr/local --exclude-subdir --skip-license && \
    rm ./cmake-3.14.4-Linux-x86_64.sh


# Ffmpeg, libavcodec libavformat libswscale
RUN \
    apt-get update \
    && apt-get install yasm -y \
    && cd /usr/local/src \ 
    && wget -q http://php-ice-1256261446.cos.ap-guangzhou.myqcloud.com/x264.tar.gz \
    && wget -q https://vas-1256261446.cos.ap-guangzhou.myqcloud.com/n3.1.11.tar.gz \
    && tar xf x264.tar.gz \
    && cd x264 \
    && ./configure --enable-shared \
    && make -j32 \
    && make install \
    && make clean \
    && cd /usr/local/src \
    && tar xf n3.1.11.tar.gz \
    && cd FFmpeg-n3.1.11 \
    && ./configure  --enable-shared  --enable-pthreads --enable-postproc  --enable-gpl --enable-libx264 \
    && make -j 32\
    && make install \
    && make clean \
    && clean-layer.sh

# Opencv
RUN apt-get update \
    && apt-get install -y build-essential \
    && apt-get install -y git pkg-config opencl-headers \
    && apt-get install -y python3.6-dev python-numpy libtbb2 libtbb-dev libjpeg-dev libpng-dev libtiff-dev libjasper-dev libdc1394-22-dev libfreetype6-dev libharfbuzz-dev libopenblas-dev liblapacke-dev libeigen3-dev libprotobuf-dev libhdf5-dev libatlas-base-dev \
    # Fix lapack header error
    && cp /usr/include/lapacke*.h /usr/include/openblas \
    # Numpy
    && pip3 install -i https://mirrors.cloud.tencent.com/pypi/simple numpy \
    # Opencv
    && cd /usr/local/src \
    && wget -q https://vas-1256261446.cos.ap-guangzhou.myqcloud.com/opencv4.1.1.zip \
    && wget -q https://vas-1256261446.cos.ap-guangzhou.myqcloud.com/opencv_contrib-4.1.1.tar.gz \
    && tar xf opencv_contrib-4.1.1.tar.gz \
    && unzip -q opencv4.1.1.zip \
    # Pre-downloaded cache
    && wget -q https://vas-1256261446.cos.ap-guangzhou.myqcloud.com/opencv-cache.tgz \
    && tar zxf opencv-cache.tgz -C opencv-4.1.1/ \
    && cd opencv-4.1.1 \
    && mkdir release \
    && cd release \
    && cmake -D CMAKE_BUILD_TYPE=RELEASE -D OPENCV_EXTRA_MODULES_PATH=../../opencv_contrib-4.1.1/modules \
            -D WITH_TBB=ON -D WITH_V4L=ON -D WITH_GTK=OFF -D BUILD_EXAMPLES=OFF \
            -D BUILD_NEW_PYTHON_SUPPORT=ON \
            -D WITH_FFMPEG=ON -D WITH_GSTREAMER=OFF -D WITH_TIFF=ON \
            -D WITH_CUDA=OFF -D CMAKE_LIBRARY_PATH=/usr/local/cuda/lib64/stubs -D CUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda-${CUDA_MAJOR_VERSION}.${CUDA_MINOR_VERSION} -D CUDA_FAST_MATH=ON -D WITH_CUFFT=ON -D WITH_CUBLAS=ON -D CUDA_NVCC_FLAGS=--Wno-deprecated-gpu-targets \
            -D WITH_LIBV4L=ON -D OPENCV_GENERATE_PKGCONFIG=ON -D INSTALL_C_EXAMPLES=OFF .. \
    && make -j32 install \
    && clean-layer.sh

RUN \
    # Install opencv python
    pip3 install opencv-python -i https://mirrors.cloud.tencent.com/pypi/simple \
    clean-layer.sh

# 视频流服务依赖
RUN \
    apt-get update \
    && cd /usr/local/src \
    && wget -q https://vas-1256261446.cos.ap-guangzhou.myqcloud.com/v3.0.2.tar.gz \
    && cd /usr/local/src \
    && apt-get install curl autoconf libtool -y \
    && tar xf v3.0.2.tar.gz \
    && cd protobuf-3.0.2 \
    && ./autogen.sh \
    && ./configure \
    && make -j32 \
    && make check \
    && make install \
    && ldconfig \
    && clean-layer.sh

# ICE, Boost
RUN echo "deb http://zeroc.com/download/Ice/3.6/ubuntu16.04 stable main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --allow-unauthenticated zeroc-ice-all-runtime zeroc-ice-all-dev \
    && apt-get install --allow-downgrades libssl1.0.0=1.0.2g-1ubuntu4.16 -y \
    && apt-get install -y lshw libjsoncpp-dev dmidecode libcurl4-openssl-dev  sg3-utils uuid-dev nvme-cli libssl-dev libbz2-dev \
    && pip3 install -i https://mirrors.cloud.tencent.com/pypi/simple zeroc-ice==3.6.5 \
    && apt-get install -y openssh-server openssh-client \
    && apt-get install libboost-all-dev -y \
    && apt-get install cron -y \
    && sed -i '/zeroc/d' /etc/apt/sources.list \
    && clean-layer.sh

# Install PyPI packages
RUN pip3 install numpy \
    && pip3 install onnx==1.6.0 \
    && pip3 install onnxruntime==1.3.0 \
    && pip3 install pycuda==2019.1.2 \
    && pytest \
    && tensorflow-gpu>=1.15, <2.0

# Download NGC client
RUN cd /usr/local/bin && wget https://ngc.nvidia.com/downloads/ngccli_cat_linux.zip && unzip ngccli_cat_linux.zip && chmod u+x ngc && rm ngccli_cat_linux.zip ngc.md5 && echo "no-apikey\nascii\n" | ngc config set

# Set environment and working directory
ENV TRT_RELEASE /tensorrt
ENV TRT_SOURCE /workspace/TensorRT
WORKDIR /workspace

USER trtuser
RUN ["/bin/bash"]
