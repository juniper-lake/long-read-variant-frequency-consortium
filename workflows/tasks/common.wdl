version 1.0


task get_movie_name {
  meta {
    description: "Gets the name of a movie from the filename, i.e. everything before the first '.'"
  }

  parameter_meta {
    movie: { help: "The movie file path to get the name of." }
  }

  input {
    File movie
  }

  command<<<
    FILE="~{basename(movie)}"
    echo "${FILE%%.*}"
  >>>

  output {
    String movie_name = read_string(stdout())
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:20.04"
  }
}


task sort_vcf {
  meta {
    description: "Sorts a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "VCF file to be sorted." }
    output_filename: { help: "Output filename." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
  }

  input {
    File input_vcf
    String output_filename = "~{basename(input_vcf)}_sorted.vcf"
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bcftools sort ~{input_vcf} -Ov -o ~{output_filename}
  }

  output {
    File vcf = output_filename
  }

  runtime {
    memory: "16GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/bcftools:1.14"
  }
}


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

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
    index: { description: "Tabix index file." }
  }

  input {
    File input_vcf
    String tabix_extra = "--preset vcf"
    String output_filename = "~{basename(input_vcf)}.gz"
    Int threads = 2
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
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
    docker: "juniperlake/htslib:1.14"
  }
}
