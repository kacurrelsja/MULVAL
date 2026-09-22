  GNU nano 7.2                                                             Dockerfile
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
RUN pip3 install --no-cache-dir clingo pyyaml openai pandas

# 3. Build & Install XSB from Git (Bypasses dead SourceForge links)
WORKDIR /root
RUN git clone --depth 1 https://git.code.sf.net/p/xsb/code XSB_SRC \
    && BUILD_DIR=$(find /root/XSB_SRC -type d -name "build" | head -n 1) \
    && cd "$BUILD_DIR" \
    && ./configure \
