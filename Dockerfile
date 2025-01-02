FROM nvcr.io/nvidia/tensorrt:24.10-py3
# ENVIRONMENT VARIABLES
ENV DEBIAN_FRONTEND noninteractive
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda-11.8/lib64:/usr/local/cuda-12.5/lib64
ENV NVM_DIR /home/docker/nvm
ENV CONDA_DIR /home/docker/conda
ENV PATH=/home/docker/.local/bin:/home/docker/conda/bin:$PATH
# APT DEPENDENCIES
RUN apt update && apt install -y tcl software-properties-common vim sudo xvfb
RUN add-apt-repository ppa:deadsnakes/ppa
RUN apt install -y python3.10 python3-pip

# ADD USERS
RUN echo 'root:root' | chpasswd
RUN useradd -m docker && echo "docker:docker" | chpasswd && adduser docker sudo

USER docker

#Install NVM
RUN mkdir /home/docker/nvm
RUN curl --silent -o- https://raw.githubusercontent.com/creationix/nvm/master/install.sh | bash \
    && . $NVM_DIR/nvm.sh \
    && nvm install --lts
# Install CONDA

RUN curl --silent https://repo.anaconda.com/archive/Anaconda3-2024.10-1-Linux-x86_64.sh -o /home/docker/conda_installer.sh
RUN bash /home/docker/conda_installer.sh -b -p ${CONDA_DIR}
RUN conda init && conda update -n base conda
# ADD libmamba
RUN conda install -n base conda-libmamba-solver && conda config --set solver libmamba
# Install Jupyterlab
RUN conda install -n base jupyterlab




