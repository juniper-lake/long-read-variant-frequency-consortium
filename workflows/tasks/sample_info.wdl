version 1.0

import "structs.wdl"
import "sample_sheet.wdl" as sample_sheet

task build_movie_info {
  meta {
    description: "Builds a MovieInfo object from variables."
  }

  parameter_meta {
    # inputs
    movie_path: "Path to the movie."
    movie_name: "Name of the movie."
    is_ubam: "Whether the movie is a ubam or not."
    conda_image: "Docker image with necessary conda environments installed."

    #outputs
    movie: "A MovieInfo object."
  }
  input {
    String movie_name
    File movie_path
    Boolean is_ubam
    String conda_image
  }

  command {
  }

  output {
    MovieInfo movie = object {
      "name": movie_name,
      "path": movie_path,
      "is_ubam": is_ubam
    }
  }

  runtime {
    # cpu: threads
    # memory: "GB"
    # disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


task build_sample_info {
  meta {
    description: "Builds a SampleInfo object from sample name and multiple MovieInfo objects."
  }

  parameter_meta {
    # inputs
    sample_name: "Name of the sample."
    movies: "An array of MovieInfo objects."
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    sample: "A SampleInfo object."
  }

  input {
    String sample_name
    Array[MovieInfo] movies
    String conda_image
  }

  command {
  }

  output {
    SampleInfo sample = object {
      "name": sample_name,
      "movies": movies,
    }
  }

  runtime {
    # cpu: threads
    # memory: "GB"
    # disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


workflow get_sample_info {
  meta {
    description: "Builds SampleInfo object from a sample sheet."
  }

  parameter_meta {
    sample_name: "Name of the sample."
    sample_sheet: "TSV with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam"
    conda_image: "Docker image with necessary conda environments installed."
  }

  input {
    String sample_name
    File sample_sheet
    String conda_image
  }

  # get input variables from sample sheet pertaining to specified sample
  call sample_sheet.get_sample_movies {
    input:
      sample_sheet = sample_sheet,
      sample_name = sample_name,
      conda_image = conda_image
  }

  # build MovieInfo objects from sample sheet variables
  scatter (idx in range(length(get_sample_movies.movie_names))) {
    call build_movie_info {
      input:
        movie_name = get_sample_movies.movie_names[idx],
        movie_path = get_sample_movies.movie_paths[idx],
        is_ubam = get_sample_movies.is_ubams[idx],
        conda_image = conda_image
    }
  }

  # build SampleInfo object from sample name and MovieInfo objects
  call build_sample_info {
    input:
      sample_name = sample_name,
      movies = build_movie_info.movie,
      conda_image = conda_image
  }

  output {
    SampleInfo sample = build_sample_info.sample
  }
}