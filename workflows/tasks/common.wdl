version 1.0

import "structs.wdl"

task zip_and_index_vcf {
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
    IndexedData indexedData = {
      "name": basename(input_vcf, '.vcf'),
      "data": vcf,
      "index": index,
    }
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
  
  meta {
    description: "This task will zip and index a vcf file."
  }

  parameter_meta {
    input_vcf: "VCF file to be gzipped and indexed."
    tabix_extra: "Extra arguments for tabix."
    output_filename: "Output filename."
    threads: "Number of threads to use."
    conda_image: "Docker image with necessary conda environments installed."
  }
}
