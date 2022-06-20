#!/usr/bin/env bash

# usage: run `bash dockers/build_dockers.sh` from the root directory of project

set -eo pipefail

function build_docker () {
  # using the tool/dir name
  local -r tool=$(echo $1 | cut -d"=" -f2)
  # get the version of the primary tool/docker
  local -r version=$(echo $2 | cut -d"=" -f2)
  # get the relative path to the docker
  local -r dockerfile_path="${@: -1}"
  # get the images name
  local -r image_name="juniperlake/${tool}:${version}"
  # get additional arguments with the "--build-arg" option
  local -a build_args=()
  for arg in "$@"; do
    if [[ "$arg" == *"="* ]]; then
      build_args=(--build-arg ${arg} ${build_args[@]})
    fi
  done

  # build and push the docker
  docker build ${build_args[@]} -t ${image_name} -f ${dockerfile_path} .
  docker push ${image_name}
}

# build dockers 
build_docker TOOL=bcftools VERSION=1.14 dockers/Dockerfile
build_docker TOOL=cutesv VERSION=1.0.13 dockers/Dockerfile
build_docker TOOL=gfatools VERSION=0.4 dockers/Dockerfile
build_docker TOOL=hifiasm VERSION=0.16.1 dockers/Dockerfile
build_docker TOOL=htslib VERSION=1.14 dockers/Dockerfile
build_docker TOOL=jasmine VERSION=1.1.5 dockers/Dockerfile
build_docker TOOL=minimap2 VERSION=2.24 dockers/Dockerfile
build_docker TOOL=pandas VERSION=1.1.0 dockers/Dockerfile
build_docker TOOL=pav VERSION=c2bfbe6 HASH=c2bfbe6a285484e56f8d97ee162b82c4e5cd4966 dockers/pav/Dockerfile
build_docker TOOL=pbmm2 VERSION=1.7.0 dockers/Dockerfile
build_docker TOOL=pbsv VERSION=2.8 dockers/Dockerfile
build_docker TOOL=samtools VERSION=1.14 dockers/Dockerfile
build_docker TOOL=sniffles VERSION=2.0 dockers/Dockerfile
build_docker TOOL=svim VERSION=1.4.2 dockers/Dockerfile
