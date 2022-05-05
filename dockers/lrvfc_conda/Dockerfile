FROM continuumio/miniconda3
WORKDIR /opt/lrvfc

RUN conda update -n base -c defaults conda

ADD "scripts" /opt/lrvfc/scripts
ADD "envs" /opt/lrvfc/envs
ADD "dockers/lrvfc_conda/create_conda_envs.sh" /opt/lrvfc/setup/create_conda_envs.sh

WORKDIR /opt/lrvfc/setup
RUN chmod +x create_conda_envs.sh
RUN ./create_conda_envs.sh
