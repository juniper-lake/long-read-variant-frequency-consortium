version 1.0

import "structs.wdl"

task pbsv_discover_signatures {
  input {
    String region
    IndexedData alignedBam
    String referenceName
    File trBed

    String extra = "--hifi"
    String logLevel = "INFO"
    String outFilename = "~{alignedBam.name}.~{referenceName}.~{region}.svsig.gz"
    
    Int threads = 4
    String condaImage
    }

  Float multiplier = 3.25
  Int diskSize = ceil(multiplier * (size(alignedBam.dataFile, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    conda info
    pbsv discover ~{extra} \
      --log-level ~{logLevel} \
      --region ~{region} \
      --tandem-repeats ~{trBed} \
      ~{alignedBam.dataFile} \
      ~{outFilename}
    }

  output {
    File svsig = outFilename
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
    description: "This task will discover SV signatures for a given region from an aligned BAM."
  }

  parameter_meta {
    # inputs
    region: "Region of the genome to search for SV signatures, e.g. chr1."
    alignedBam: "Dictionary of aligned HiFi reads containing 'name': STR , 'dataFile': STR, and 'indexFile': STR."
    referenceName: "Name of the reference genome, e.g. GRCh38."
    trBed: "BED file containing known tandem repeats."
    extra: "Extra parameters to pass to pbsv."
    logLevel: "Log level of pbsv."
    outFilename: "Name of the output svsig file."
    threads: "Number of threads to be used."
    condaImage: "Docker image with necessary conda environments installed."

    # outputs
    svsig: "SV signature file to be used for calling SVs"
  }
}


workflow pbsv_discover_signatures_across_bams {
  # This workflow will discover SV signatures for a given region from multiple aligned BAMs
  input {
    String region
    Array[IndexedData] alignedBams
    String referenceName
    File trBed
    String condaImage
  }

  # for each aligned BAM, call SV signatures
  scatter (alignedBam in alignedBams) {
    call pbsv_discover_signatures {
      input:
        region = region,
        alignedBam = alignedBam,
        referenceName = referenceName,
        trBed = trBed,
        condaImage = condaImage
    }
  }

  output {
    # SV signature files for each aligned BAM for a given region
    Array[File] svsigs = pbsv_discover_signatures.svsig
  }
}