FROM nvcr.io/nvidia/tensorrt:24.10-py3
# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND noninteractive
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.8/lib64:/usr/local/cuda-12.5/lib64
ENV NVM_DIR /home/docker/nvm
ENV MAMBA_DIR /pkgz/mamba
ENV PATH=/home/docker/.local/bin:/pkgz/mamba/bin:$PATH
# APT DEPENDENCIES
RUN apt update && apt install -y tcl software-properties-common vim sudo 
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt install -y python3.12 python3-pip

# ADD USERS
RUN echo 'root:root' | chpasswd
RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

RUN mkdir -p /pkgz
RUN chown -R docker:docker /pkgz
USER docker

#Install NVM
RUN mkdir /home/docker/nvm
RUN curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts
# Install CONDA

RUN wget -O /home/docker/mamba_installer.sh https://github.com/conda-forge/miniforge/releases/download/24.7.1-0/Mambaforge-Linux-x86_64.sh 
RUN bash /home/docker/mamba_installer.sh -b -p ${MAMBA_DIR} 
RUN mamba init && mamba update mamba



# Upgrade PIP
RUN python -m pip install -q --upgrade pip
# JupyterLAB
RUN pip install --user -q jupyterlab==4.3.4
# Build Jupyterlab

