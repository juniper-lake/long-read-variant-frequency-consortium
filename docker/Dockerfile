################################################################
# Dockerfile for Long Read Variant Frequency Consortium Workflow
################################################################

# Set base image
FROM continuumio/miniconda3

# Change working directory
WORKDIR /opt/lrvfc

# Update conda version
RUN conda update -n base -c defaults conda

# Add files to the container
ADD "scripts" /opt/lrvfc/scripts
ADD "envs" /opt/lrvfc/envs
ADD "docker/create_conda_envs.sh" /opt/lrvfc/setup/create_conda_envs.sh

# Clone PAV git repo
RUN git clone --recursive https://github.com/EichlerLab/pav.git pav

# Reset PAV git repo to specific commit hash
WORKDIR /opt/lrvfc/pav
RUN git reset --hard c2bfbe6a285484e56f8d97ee162b82c4e5cd4966

# Add PAV location as a variable so it can be called from workflow
RUN echo "export PAV=/opt/lrvfc/pav" >> ~/.bashrc

# Create conda environments for each of the tools
WORKDIR /opt/lrvfc/setup
RUN chmod +x create_conda_envs.sh
RUN ./create_conda_envs.sh
