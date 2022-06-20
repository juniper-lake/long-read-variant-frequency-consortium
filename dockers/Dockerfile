# Set base image
FROM continuumio/miniconda3

WORKDIR /app

ARG TOOL
ARG VERSION

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY dockers/envs/${TOOL}_${VERSION}.yaml .
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name ${TOOL}

# Make run commands use new environment
SHELL ["conda", "run", "--name", "${TOOL}", "/bin/bash", "-c"]

# Code to run when container is started
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "${TOOL}"]
