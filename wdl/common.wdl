version 1.0

import "structs.wdl"

task zip_and_index_vcf {
  input {
    String inVcf

    String tabixExtra = "--preset vcf"
    String outFilename = "~{basename(inVcf)}.gz"

    Int threads = 2
    String condaImage
  }

  Float multiplier = 3.25
  Int diskSize = ceil(multiplier * size(inVcf, "GB")) + 20

  command {
    source ~/.bashrc
    conda activate htslib
    conda info
    bgzip --threads ~{threads} ~{inVcf}
    tabix ~{tabixExtra} ~{outFilename}
  }

  output {
    File vcf = outFilename
    File index = "~{outFilename}.tbi"
    IndexedData indexedData = {
      "name": basename(inVcf, '.vcf'),
      "dataFile": vcf,
      "indexFile": index,
    }
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "~{diskSize} GB"
    maxRetries: 3
    preemptible: 1
    docker: condaImage
  }
  
  meta {
    description: "This task will zip and index a vcf file."
    author: "Juniper Lake"
  }

  parameter_meta {
    inVcf: "VCF file to be gzipped and indexed."
    tabixExtra: "Extra arguments for tabix."
    outFilename: "Output filename."
    threads: "Number of threads to use."
    condaImage: "Docker image with necessary conda environments installed."
  }
}
