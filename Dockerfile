FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# 1. Install system toolchain, Java, Graphviz, and build tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    autoconf \
    bison \
    flex \
    gcc \
    g++ \
    make \
    graphviz \
    default-jdk \
    git \
    curl \
    bc \
    bsdmainutils \
    ca-certificates \
    python3 \
    python3-pip \
    && rm -rf /var/lib/apt/lists/*

# Fix OpenJDK jni_md.h path for XSB Java interfacing
RUN JNI_DIR=$(find /usr/lib/jvm -name "jni.h" | head -n 1 | xargs dirname) && \
    if [ -f "$JNI_DIR/linux/jni_md.h" ]; then cp "$JNI_DIR/linux/jni_md.h" "$JNI_DIR/"; fi

# 2. Install Python dependencies (ASP Clingo solver, PyYAML, OpenAI SDK)
RUN pip3 install --no-cache-dir clingo==5.7.0 pyyaml openai pandas

# 3. Build & Install XSB from Git (Bypasses dead SourceForge links)
WORKDIR /root
RUN git clone --depth 1 https://git.code.sf.net/p/xsb/code XSB_SRC \
    && BUILD_DIR=$(find /root/XSB_SRC -type d -name "build" | head -n 1) \
    && cd "$BUILD_DIR" \
    && ./configure \
    && ./makexsb \
    && mkdir -p /root/XSB/bin \
    && cp -r "$BUILD_DIR"/../* /root/XSB/ \
    && rm -rf /root/XSB_SRC

ENV XSB_DIR=/root/XSB
ENV PATH="${PATH}:/root/XSB/bin/"

# 4. Copy and build your local MulVAL project inside the image
WORKDIR /root/mulval
COPY . /root/mulval

ENV MULVALROOT=/root/mulval
ENV PATH="${PATH}:${MULVALROOT}/bin:${MULVALROOT}/utils"

#Fix legacy MulVAL C++ issues on GCC 11 / Ubuntu 22.04

RUN cd src/attack_graph && \
    sed -i 's/\bdata\b/g_graph_data/g' attack_graph.cpp && \
    sed -i 's/\bdata\b/g_graph_data/g' graphit.y && \
    sed -i 's/fa >0/fa != NULL/g' attack_graph.cpp && \
    sed -i 's/fa > 0/fa != NULL/g' attack_graph.cpp && \
    sed -i 's/mv graphit.tab.h y.tab.cpp.h/cp graphit.tab.h y.tab.cpp.h/g' Makefile && \
    sed -i 's/gcc -g/gcc -g -fcommon/g' Makefile && \
    sed -i 's/g++ -g/g++ -g -std=c++14/g -fcommon/g' Makefile || true

# Compile MulVAL adapters
RUN make clean || true && make

# Ensure execution scripts have executable permissions
RUN chmod +x /root/mulval/utils/*.sh /root/mulval/ot_pipeline/scripts/*.sh /root/mulval/run_pipeline.sh || true

# Default working directory
WORKDIR /root/mulval

CMD ["/bin/bash"]
