version 1.0

import "utils.wdl" as utils

workflow convert_to_fasta {
  meta {
    description: "Given an array of movies, convert any BAMs to FASTA."
  }

  parameter_meta {
    # inputs
    movies: { help: "Array of movies." }

    # outputs
    fastxs: { help: "Array of FASTA/FASTQ files." }
  }

  input {
    Array[File] movies
  }

  scatter (idx in range(length(movies))) {
    # check if movie is a ubam
    call check_if_ubam {
      input:
        movie = movies[idx],
    }

    # if ubam, convert to fasta
    if (check_if_ubam.is_ubam) {
      call ubam_to_fasta {
        input:
          movie = movies[idx],
      }

      call utils.bgzip_fasta {
        input:
          fasta = ubam_to_fasta.fasta
      }
    }  

    # if not a ubam, do nothing
    if (!check_if_ubam.is_ubam) {
      call do_nothing {
        input:
          input_file = movies[idx],
      }
    }
  }

  output {
    Array[File] fastxs = flatten([select_all(bgzip_fasta.gzipped_fasta), select_all(do_nothing.output_file)])
  }
}


task check_if_ubam {
  meta {
    description: "Check if movie is a ubam."
  }

  parameter_meta {
    # inputs
    movie: { help: "Movie file." }

    # outputs
    is_ubam: { help: "True if movie is a ubam." }
  }

  input {
    File movie
  }

  Int threads = 1
  Int memory = 4 * threads
  Int disk_size = ceil(1.25 * size(movie, "GB")) + 20

  command {
    if [[ $(basename ~{movie}) == *.bam ]]; then
      echo "true"
    else
      echo "false"
    fi
  }

  output {
    Boolean is_ubam = read_boolean(stdout())
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:20.04"
  }
}


task ubam_to_fasta {
  meta {
    description: "Converts a ubam file to a fasta file."
  }

  parameter_meta {
    # inputs
    movie: { help: "UBAM file to be converted." }
    threads: { help: "Number of threads to be used." }

    # outputs
    fasta: { description: "FASTA file." }
  }
  
  input {
    File movie
    Int threads = 4
  }

  String movie_name = sub(basename(movie), "\\..*", "")
  String output_fasta = "~{movie_name}.fasta"
  Int threads_m1 = threads - 1
  Int memory = 4 * threads
  Int disk_size = ceil(3.25 * size(movie, "GB")) + 20

  command {
    set -o pipefail
    samtools fasta -@ ~{threads_m1} ~{movie} > ~{output_fasta}
  }

  output {
    File fasta = output_fasta
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/samtools:1.14"
  }
}


task do_nothing {
  meta {
    description: "Passes input file and string to output file and string."
  }

  parameter_meta {
    # inputs
    input_file: { help: "File to be passed to output file." }

    # outputs
    output_file: { description: "Output file." }
  }

  input {
    File input_file
  }

  Int threads = 1
  Int memory = 4 * threads
  Int disk_size = ceil(1.25 * size(input_file, "GB")) + 20

  command {
  }

  output {
    File output_file = input_file
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:20.04"
  }
}
