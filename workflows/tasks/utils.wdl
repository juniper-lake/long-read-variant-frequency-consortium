version 1.0

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
    String output_filename
  }
  
  Int threads = 1
  Int memory = 4 * threads
  Int disk_size = ceil(3.25 * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bcftools sort ~{input_vcf} -Ov -o ~{output_filename}
  }

  output {
    File vcf = output_filename
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/bcftools:1.14"
  }
}


task unzip_vcf {
  meta {
    description: "Unzips a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "Gzipped VCF file." }

    # outputs
    vcf: { description: "Unzipped VCF file." }
  }

  input {
    File input_vcf
  }

  Int threads = 1
  Int memory = 4 * threads
  String output_filename = basename(input_vcf, ".gz")
  Int disk_size = ceil(3.25 * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bgzip -d -c ~{input_vcf} > ~{output_filename}
  }

  output {
    File vcf = output_filename
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/htslib:1.14"
  }
}

task bgzip_fasta {
  meta {
    description: "Zip FASTA file."
  }

  parameter_meta {
    # inputs
    fasta: { help: "FASTA file to zip." }
    threads: { help: "Number of threads to use." }

    # outputs
    gzipped_fasta: { description: "Zipped FASTA file." }
  }
  
  input {
    File fasta
    Int threads = 4
  }

  String output_filename = "~{basename(fasta)}.gz"
  Int memory = 4 * threads
  Int disk_size = ceil(3.25 * size(fasta, "GB")) + 20

  command {
    set -o pipefail
    bgzip --threads ~{threads} ~{fasta} -c > ~{output_filename}
  }

  output {
    File gzipped_fasta = output_filename
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/htslib:1.14"
  }
}

task zip_and_index_vcf {
  meta {
    description: "Zips and indexes a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "VCF file to be gzipped and indexed." }
    threads: { help: "Number of threads to use." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
    index: { description: "Tabix index file." }
  }

  input {
    File input_vcf
    Int threads = 2
  }

  Int memory = 4 * threads
  String output_filename = "~{basename(input_vcf)}.gz"
  Int disk_size = ceil(3.25 * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bgzip --threads ~{threads} ~{input_vcf} -c > ~{output_filename}
    tabix --preset vcf ~{output_filename}
  }

  output {
    File vcf = output_filename
    File index = "~{output_filename}.tbi"
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/htslib:1.14"
  }
}