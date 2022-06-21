# Set base image
FROM continuumio/miniconda3

WORKDIR /app

ARG TOOL
ARG VERSION

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY ./dockers/envs/${TOOL}_${VERSION}.yaml ./
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name myenv

# Add environment to bashrc
RUN echo "conda activate myenv" >> ~/.bashrc

# Code to run when container is started
COPY ./dockers/entrypoint.sh ./
ENTRYPOINT ["/bin/bash", "./entrypoint.sh"]
