# Set base image
FROM continuumio/miniconda3

WORKDIR /app

ARG TOOL
ARG VERSION
ARG HASH

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY dockers/envs/${TOOL}_${VERSION}.yaml .
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name myenv

# Make run commands use new environment
SHELL ["conda", "run", "--name", "myenv", "/bin/bash", "-c"]

# Code to run when container is started
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "myenv"]

# Clone PAV git repo
RUN git clone --recursive https://github.com/EichlerLab/pav.git pav

# Reset PAV git repo to specific commit hash
WORKDIR /app/pav
RUN git reset --hard ${HASH}

# Add PAV location as a variable so it can be called from workflow
RUN echo "export PAV=/app/pav" >> ~/.bashrc
