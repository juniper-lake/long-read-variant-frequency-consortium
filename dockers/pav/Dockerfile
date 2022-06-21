# This Dockerfile is only used for PAV

FROM continuumio/miniconda3

WORKDIR /src

ARG TOOL
ARG VERSION
ARG HASH

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY ./dockers/envs/${TOOL}_${VERSION}.yaml ./
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name ${TOOL}

# Clone PAV git repo and reset to specific commit hash
RUN git clone --recursive https://github.com/EichlerLab/pav.git /src/pav
WORKDIR /src/pav
RUN git reset --hard ${HASH}
WORKDIR /src

# Need to source ~/.bashrc in docker command
RUN echo "source activate ${TOOL}" >> ~/.bashrc
RUN echo "export PAV=/src/pav" >> ~/.bashrc
