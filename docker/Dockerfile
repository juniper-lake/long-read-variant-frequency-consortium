FROM continuumio/miniconda3
WORKDIR /opt/lrvfc

RUN conda update -n base -c defaults conda

ADD "scripts" /opt/lrvfc/scripts
ADD "envs" /opt/lrvfc/envs
ADD "docker/create_conda_envs.sh" /opt/lrvfc/setup/create_conda_envs.sh

RUN git clone --recursive https://github.com/EichlerLab/pav.git pav

WORKDIR /opt/lrvfc/pav
RUN git reset --hard c2bfbe6a285484e56f8d97ee162b82c4e5cd4966
RUN echo "export PAV=/opt/lrvfc/pav" >> ~/.bashrc

WORKDIR /opt/lrvfc/setup
RUN chmod +x create_conda_envs.sh
RUN ./create_conda_envs.sh
