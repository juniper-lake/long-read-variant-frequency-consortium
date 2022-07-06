version 1.0

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
    Array[File] fastxs = flatten([select_all(ubam_to_fasta.fasta), select_all(do_nothing.output_file)])
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
    movie_name: { help: "Name of the movie, used for file naming." }
    threads: { help: "Number of threads to be used." }
    threads_m1: { help: "Total number of threads minus 1, because samtools is silly." }

    # outputs
    fasta: { description: "FASTA file." }
  }
  
  input {
    File movie
    String movie_name = sub(basename(movie), "\..*", "")
    String output_fasta = "~{movie_name}.fasta"
    Int threads = 4
    Int threads_m1 = threads - 1
  }
  
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
    memory: "16GB"
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

  command {
  }

  output {
    File output_file = input_file
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:20.04"
  }
}
