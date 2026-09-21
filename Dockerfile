# Multi-stage/monolithic environment for Neuro-Symbolic OT Attack Graph Pipeline
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV MULVALROOT=/opt/mulval
ENV PATH="${MULVALROOT}/bin:${MULVALROOT}/utils:${PATH}"

# Install native dependencies: build tools, Java runtime, Graphviz, XSB prerequisites
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    gcc \
    g++ \
    make \
    flex \
    bison \
    graphviz \
    default-jre \
    python3 \
    python3-pip \
    python3-venv \
    git \
    curl \
    bc \
    bsdmainutils \
    wget \
    ca-certificates \
    texlive-latex-base \
    texlive-latex-extra \
    texlive-fonts-recommended \
    && rm -rf /var/lib/apt/lists/*

# Compile and install XSB Prolog
WORKDIR /tmp
RUN curl -fsSL https://downloads.sourceforge.net/project/xsb/xsb/5.0.0/XSB-5.0.0.tar.gz -o XSB.tar.gz \
    && tar -xzf XSB.tar.gz \
    && cd XSB/build \
    && ./configure --prefix=/usr/local \
    && ./makexsb \
    && ./makexsb install \
    && rm -rf /tmp/XSB*

# Copy project tree into container
WORKDIR /opt/mulval
COPY . /opt/mulval

# Build MulVAL analyzers
RUN make clean || true && make

# Set up Python virtual environment with clingo and openai
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir \
    pyyaml \
    requests \
    pandas \
    clingo \
    openai

# Set executable permissions for all execution scripts
RUN chmod +x /opt/mulval/utils/*.sh \
             /opt/mulval/ot_pipeline/scripts/*.sh \
             /opt/mulval/ot_pipeline/counterfactual/*.sh || true

# Default entrypoint executes the entire end-to-end benchmark
ENTRYPOINT ["/bin/bash", "./run_pipeline.sh"]