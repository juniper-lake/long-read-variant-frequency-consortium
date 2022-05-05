version 1.0

import "structs.wdl"

task align_ubam_or_fastq {
  input {
    IndexedData reference
    SmrtcellInfo smrtcell
    String sampleName

    String presetOption = "CCS"
    String logLevel = "INFO"
    String extra = "-c 0 -y 70"
    Boolean unmapped = true
    Boolean sort = true
    String outFilename = "~{smrtcell.name}.~{reference.name}.bam"
    
    Int threads = 24
    String condaImage
    }

  Float multiplier = 2.5
  Int diskSize = ceil(multiplier * (size(reference.dataFile, "GB") + size(reference.indexFile, "GB") + size(smrtcell.path, "GB"))) + 20
  
  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbmm2
    conda info
    pbmm2 align \
      --sample ~{sampleName} \
      --log-level ~{logLevel} \
      --preset ~{presetOption} \
      ~{true="--sort" false="" sort} \
      ~{true="--unmapped" false="" unmapped} \
      ~{extra} \
      -j ~{cores} \
      ~{reference.dataFile} \
      ~{smrtcell.path} \
      ~{outFilename}
    }

  output {
    IndexedData alignedBam = {
      "name": smrtcell.name, 
      "dataFile": outFilename, 
      "indexFile": "~{outFilename}.bai"
      }
  }

  runtime {
    cpu: threads
    memory: "96GB"
    disks: "~{diskSize} GB"
    maxRetries: 3
    preemptible: 1
    docker: condaImage
  }

  meta {
    description: "This task will align HiFi reads from either a BAM or FASTQ file."
    author: "Juniper Lake"
  }

  parameter_meta {
    # inputs
    reference: "Dictionary describing reference genome containing 'name': STR, 'dataFile': STR, and 'indexFile': STR."
    smrtcell: "Dictionary of unaligned HiFi reads containing 'name': STR , 'path': STR, and 'isUbam': BOOL."
    sampleName: "Name of the sample."
    presetOption: "This option applies multiple options at the same time."
    logLevel: "Log level of pbmm2."
    extra: "Additional pbmm2 options."
    unmapped: "If true, unmapped reads are added to the output BAM file."
    sort: "If true, will sort the output bam file."
    outFilename: "Name of the output bam file."
    threads: "Number of threads to be used."
    condaImage: "Docker image with necessary conda environments installed."

    # outputs
    alignedBam: "Dictionary containing 'name': STR, 'dataFile': STR, and 'indexFile': STR."
  }
}
