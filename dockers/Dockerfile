# This Dockerfile is used for all environments except PAV

FROM continuumio/miniconda3

WORKDIR /src

ARG TOOL
ARG VERSION

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY ./dockers/envs/${TOOL}_${VERSION}.yaml ./
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name ${TOOL}

# Need to source ~/.bashrc in docker command
RUN echo "source activate ${TOOL}" >> ~/.bashrc
