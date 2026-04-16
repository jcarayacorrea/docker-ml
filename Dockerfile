FROM nvcr.io/nvidia/tensorrt:24.10-py3

# Build arguments for reproducible, configurable versions
ARG NVM_VERSION=0.39.7
ARG ANACONDA_VERSION=2024.10-1

LABEL maintainer="Juan Carlos Araya Correa" \
      description="ML JupyterLab environment with CUDA 11.8/12.x, PyTorch, TensorFlow" \
      version="1.0"

# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.8/lib64:/usr/local/cuda-12.5/lib64 \
    NVM_DIR=/home/docker/nvm \
    CONDA_DIR=/home/docker/conda \
    PATH=/home/docker/.local/bin:/home/docker/conda/bin:$PATH

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

# CUDA 11.8 INSTALLATION
RUN wget -q -P /tmp \
        https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin \
    && mv /tmp/cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 \
    && wget -q -P /tmp \
        https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && dpkg -i /tmp/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && cp /var/cuda-repo-ubuntu2204-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/ \
    && apt-get update \
    && apt-get install -y --no-install-recommends cuda-11-8 \
    && rm /tmp/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && rm -rf /var/cuda-repo-ubuntu2204-11-8-local \
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

# Install Conda and JupyterLab
RUN curl --silent -L \
        https://repo.anaconda.com/archive/Anaconda3-${ANACONDA_VERSION}-Linux-x86_64.sh \
        -o /tmp/conda_installer.sh \
    && bash /tmp/conda_installer.sh -b -p ${CONDA_DIR} \
    && rm /tmp/conda_installer.sh \
    && . ${CONDA_DIR}/etc/profile.d/conda.sh \
    && conda init bash \
    && conda update -n base -c defaults conda -y \
    && conda install -n base -c conda-forge conda-libmamba-solver -y \
    && conda config --set solver libmamba \
    && conda install -n base -c conda-forge jupyterlab -y \
    && conda clean -afy

# Create conda environments from environment files
RUN . ${CONDA_DIR}/etc/profile.d/conda.sh \
    && conda env create -f /home/docker/environment.yml \
    && conda env create -f /home/docker/environment-old.yml \
    && conda clean -afy

# Register both environments as Jupyter kernels
RUN . ${CONDA_DIR}/etc/profile.d/conda.sh \
    && conda run -n ml-env python -m ipykernel install --user \
        --name ml-env --display-name "ML Env (Python 3.12 / CUDA 12.4)" \
    && conda run -n ml-env-old python -m ipykernel install --user \
        --name ml-env-old --display-name "ML Env Old (Python 3.11 / CUDA 11.8)"

EXPOSE 8888

HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8888/api || exit 1

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--ServerApp.token=", "--ServerApp.password="]
