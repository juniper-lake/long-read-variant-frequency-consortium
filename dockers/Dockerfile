# This Dockerfile is used for all environments except PAV

FROM continuumio/miniconda3

WORKDIR /src

ARG TOOL
ARG VERSION

# Create environment and add to path
COPY ./dockers/envs/${TOOL}_${VERSION}.yaml ./
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name ${TOOL}
ENV PATH /opt/conda/envs/${TOOL}/bin:$PATH

# Add to ~/.bashrc in case it needs to be sourced
RUN echo "source activate ${TOOL}" >> ~/.bashrc
