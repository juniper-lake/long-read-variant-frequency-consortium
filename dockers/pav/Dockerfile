# Set base image
FROM continuumio/miniconda3

WORKDIR /app

ARG TOOL
ARG VERSION
ARG HASH

# Update conda version
RUN conda update -n base -c defaults conda

# Create environment
COPY ./dockers/envs/${TOOL}_${VERSION}.yaml ./
RUN conda env create --file ${TOOL}_${VERSION}.yaml --name myenv

# Add environment to bashrc
RUN echo "conda activate myenv" >> ~/.bashrc

# Clone PAV git repo
RUN git clone --recursive https://github.com/EichlerLab/pav.git /app/pav

# Reset PAV git repo to specific commit hash
WORKDIR /app/pav
RUN git reset --hard ${HASH}

# Code to run when container is started
WORKDIR /app
COPY ./dockers/entrypoint.sh ./
ENTRYPOINT ["/bin/bash", "./entrypoint.sh"]
