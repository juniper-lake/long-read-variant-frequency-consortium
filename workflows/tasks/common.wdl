version 1.0

import "structs.wdl"

task zip_and_index_vcf {
  meta {
    description: "Zips and indexes a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: {
      help: "VCF file to be gzipped and indexed.",
      patterns: ["*.vcf"]
    }
    tabix_extra: { help: "Extra arguments for tabix." }
    output_filename: { help: "Output filename." }
    threads: { help: "Number of threads to use." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
    index: { description: "Tabix index file." }
    indexed_vcf: { description: "Gzipped and VCF index in form of IndexedData object." }
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
    source ~/.bashrc
    conda activate htslib
    conda info
    bgzip --threads ~{threads} ~{input_vcf} -c > ~{output_filename}
    tabix ~{tabix_extra} ~{output_filename}
  }

  output {
    File vcf = output_filename
    File index = "~{output_filename}.tbi"
    IndexedData indexed_vcf = {
      "name": basename(input_vcf, '.vcf'),
      "data": vcf,
      "index": index,
    }
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
