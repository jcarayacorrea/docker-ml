FROM nvcr.io/nvidia/tensorrt:24.10-py3

# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND=noninteractive \
    LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.8/lib64:/usr/local/cuda-12.5/lib64 \
    NVM_DIR=/home/docker/nvm \
    CONDA_DIR=/home/docker/conda \
    PATH=/home/docker/.local/bin:/home/docker/conda/bin:$PATH

# APT DEPENDENCIES AND USERS
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

# CUDA INSTALLATION (from cuda11.4.sh script)
# Note: The script installs CUDA 11.8 despite its name.
# Executing the steps from the script directly in the Dockerfile for better layer management.
RUN cd /tmp \
    && wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin \
    && mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600 \
    && wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && dpkg -i /tmp/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && cp /var/cuda-repo-ubuntu2204-11-8-local/cuda-*-keyring.gpg /usr/share/keyrings/ \
    && apt-get update \
    && apt-get -y install cuda-11-8 \
    && rm /tmp/cuda-repo-ubuntu2204-11-8-local_11.8.0-520.61.05-1_amd64.deb \
    && rm -rf /var/lib/apt/lists/*

# Copy conda environment files
COPY --chown=docker:docker environment.yml environment-old.yml /home/docker/

USER docker
WORKDIR /home/docker

# Install NVM
RUN mkdir -p $NVM_DIR \
    && curl --silent -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts

# Install CONDA and JupyterLab
RUN curl --silent -L https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh -o /home/docker/conda_installer.sh \
    && bash /home/docker/conda_installer.sh -b -p ${CONDA_DIR} \
    && rm /home/docker/conda_installer.sh \
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

CMD ["jupyter", "lab", "--ip=0.0.0.0", "--NotebookApp.token=''", "--NotebookApp.password=''"]
