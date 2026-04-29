FROM nvcr.io/nvidia/rapidsai/notebooks:25.06-cuda12.8-py3.10

# Build arguments for reproducible, configurable versions
ARG NVM_VERSION=0.39.7
ARG CUDA_KEYRING_VERSION=1.1-1

LABEL maintainer="Juan Carlos Araya Correa" \
      description="ML JupyterLab environment with CUDA 12.8, PyTorch, TensorFlow" \
      version="1.0"

# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND=noninteractive \
    CUDA_HOME=/usr/local/cuda-12.8 \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-12.8/lib64 \
    NVM_DIR=/home/docker/nvm \
    CONDA_DIR=/home/docker/conda \
    PATH=/usr/local/cuda-12.8/bin:/home/docker/.local/bin:/home/docker/conda/bin:$PATH

# APT DEPENDENCIES AND USER SETUP
RUN apt-get update && apt-get install -y --no-install-recommends \
    tcl \
    software-properties-common \
    vim \
    sudo \
    xvfb \
    swig3.0 \
    graphviz \
    wget \
    ca-certificates \
    curl \
    && add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y --no-install-recommends \
    python3.10 \
    python3-pip \
    && ln -s /usr/bin/swig3.0 /usr/bin/swig \
    && echo 'root:root' | chpasswd \
    && useradd -m -s /bin/bash docker \
    && echo "docker:docker" | chpasswd \
    && adduser docker sudo \
    && echo "docker ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && rm -rf /var/lib/apt/lists/*

# CUDA 12.8 TOOLKIT INSTALLATION
RUN wget -q -P /tmp \
        https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_${CUDA_KEYRING_VERSION}_all.deb \
    && dpkg -i /tmp/cuda-keyring_${CUDA_KEYRING_VERSION}_all.deb \
    && apt-get update \
    && apt-get install -y --no-install-recommends cuda-toolkit-12-8 \
    && rm /tmp/cuda-keyring_${CUDA_KEYRING_VERSION}_all.deb \
    && rm -rf /var/lib/apt/lists/*

# Copy conda environment files
COPY --chown=docker:docker environment.yml environment-old.yml /home/docker/

USER docker
WORKDIR /home/docker

# Install NVM and Node.js LTS
RUN mkdir -p $NVM_DIR \
    && curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts



# Create conda environments from environment files
RUN . ${CONDA_DIR}/etc/profile.d/conda.sh \
    && conda env create -f /home/docker/environment.yml \
    && conda env create -f /home/docker/environment-old.yml \
    && conda clean -afy

# Register both environments as Jupyter kernels
RUN . ${CONDA_DIR}/etc/profile.d/conda.sh \
    && conda run -n ml-env python -m ipykernel install --user \
        --name ml-env --display-name "ML Env (Python 3.12 / CUDA 12.8)" \
    && conda run -n ml-env-old python -m ipykernel install --user \
        --name ml-env-old --display-name "ML Env Old (Python 3.11 / CUDA 11.8)"

EXPOSE 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8888/api || exit 1

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--ServerApp.token=", "--ServerApp.password="]
