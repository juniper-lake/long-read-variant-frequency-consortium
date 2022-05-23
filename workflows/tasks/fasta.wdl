version 1.0

workflow convert_to_fasta {
  meta {
    description: "Given an array of movies, convert any BAMs to FASTA."
  }

  parameter_meta {
    # inputs
    movies: { help: "Array of movies." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    fastas: { help: "Array of FASTA/FASTQ files." }
  }

  input {
    Array[File] movies
    String conda_image
  }

  scatter (idx in range(length(movies))) {
    # check if movie is a ubam
    call check_if_ubam {
      input:
        movie = movies[idx],
        conda_image = conda_image
    }

    # if ubam, convert to fasta
    if (check_if_ubam.is_ubam) {
      call ubam_to_fasta {
        input:
        movie = movies[idx],
        conda_image = conda_image
      }
    }  

    # if not a ubam, do nothing
    if (!check_if_ubam.is_ubam) {
      call do_nothing {
        input:
          input_file = movies[idx],
          conda_image = conda_image
      }
    }
  }

  output {
    Array[File] fastas = flatten([select_all(ubam_to_fasta.fasta), select_all(do_nothing.output_file)])
  }
}


task check_if_ubam {
  meta {
    description: "Check if movie is a ubam."
  }

  parameter_meta {
    # inputs
    movie: { help: "Movie file." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    is_ubam: { help: "True if movie is a ubam." }
  }

  input {
    String movie
    String conda_image
  }

  command {
    if [[ ~{basename(movie)} == *.bam ]]; then
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
    docker: conda_image
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
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    fasta: { description: "FASTA file." }
  }
  
  input {
    File movie
    String movie_name = basename(basename(basename(movie, ".bam"), ".hifi_reads"), ".ccs")
    String output_fasta = "~{movie_name}.fasta"
    Int threads = 4
    Int threads_m1 = threads - 1
    String conda_image
  }
  
  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(movie, "GB")) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate samtools
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
    docker: conda_image
  }
}


task do_nothing {
  meta {
    description: "Passes input file and string to output file and string."
  }

  parameter_meta {
    # inputs
    input_file: { help: "File to be passed to output file." }
    input_string: { help: "String to be passed to output string." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    output_file: { description: "Output file." }
    output_string: { description: "Output string." }
  }

  input {
    File input_file = ""
    String input_string = ""
    String conda_image
  }

  command {
  }

  output {
    File output_file = input_file
    String output_string = input_string
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
