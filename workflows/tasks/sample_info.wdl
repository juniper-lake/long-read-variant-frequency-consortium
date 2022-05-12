version 1.0

import "structs.wdl"
import "sample_sheet.wdl" as sample_sheet


workflow get_sample_info {
  meta {
    description: "Builds SampleInfo object from a sample sheet."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    sample_sheet: { 
      help: "TSV (.txt or .tsv) with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam",
      patterns: ["*.txt", "*.tsv"]
    }

    # outputs
    sample: { description: "SampleInfo object." }
  }

  input {
    String sample_name
    File sample_sheet
  }

  # get input variables from sample sheet pertaining to specified sample
  call sample_sheet.get_sample_movies {
    input:
      sample_sheet = sample_sheet,
      sample_name = sample_name,
  }

  # build MovieInfo objects from sample sheet variables
  scatter (idx in range(length(get_sample_movies.movie_names))) {
    call build_movie_info {
      input:
        movie_name = get_sample_movies.movie_names[idx],
        movie_path = get_sample_movies.movie_paths[idx],
        is_ubam = get_sample_movies.is_ubams[idx],
    }
  }

  # build SampleInfo object from sample name and MovieInfo objects
  call build_sample_info {
    input:
      sample_name = sample_name,
      movies = build_movie_info.movie,
  }

  output {
    SampleInfo sample = build_sample_info.sample
  }
}


task build_movie_info {
  meta {
    description: "Builds a MovieInfo object from variables."
  }

  parameter_meta {
    # inputs
    movie_path: { 
      help: "Path to the movie.",
      patterns: ["*.bam", ".fastq.gz"] 
    }
    movie_name: { help: "Name of the movie." }
    is_ubam: { help: "Whether the movie is a ubam or not." }

    # outputs
    movie: { description: "A MovieInfo object." }
  }
  input {
    String movie_name
    File movie_path
    Boolean is_ubam
  }

  command {
  }

  output {
    MovieInfo movie = object {
      name: movie_name,
      path: movie_path,
      is_ubam: is_ubam
    }
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:latest"
  }
}


task build_sample_info {
  meta {
    description: "Builds a SampleInfo object from sample name and multiple MovieInfo objects."
  }

  parameter_meta {
    # inputs
    sample_name: {help: "Name of the sample." }
    movies: {help: "An array of MovieInfo objects." }

    # outputs
    sample: { description: "A SampleInfo object." }
  }

  input {
    String sample_name
    Array[MovieInfo] movies
  }

  command {
  }

  output {
    SampleInfo sample = object {
      name: sample_name,
      movies: movies,
    }
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:latest"
  }
}


