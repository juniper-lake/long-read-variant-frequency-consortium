version 1.0

task zip_and_index_vcf {
  meta {
    description: "Zips and indexes a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "VCF file to be gzipped and indexed." }
    tabix_extra: { help: "Extra arguments for tabix." }
    output_filename: { help: "Output filename." }
    threads: { help: "Number of threads to use." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
    index: { description: "Tabix index file." }
  }

  input {
    File input_vcf
    String tabix_extra = "--preset vcf"
    String output_filename = "~{basename(input_vcf)}.gz"
    Int threads = 2
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate htslib
    bgzip --threads ~{threads} ~{input_vcf} -c > ~{output_filename}
    tabix ~{tabix_extra} ~{output_filename}
  }

  output {
    File vcf = output_filename
    File index = "~{output_filename}.tbi"
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
    String movie_name
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
    File fasta = "~{movie_name}.fasta"
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
