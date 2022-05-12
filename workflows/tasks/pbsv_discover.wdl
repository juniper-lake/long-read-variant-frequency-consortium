version 1.0

import "structs.wdl"


workflow pbsv_discover_signatures_across_bams {
  meta {
    description: "Discovers SV signatures for a given region from multiple aligned BAMs."
  }

  parameter_meta {
    # inputs
    region: { help: "Region of the genome to search for SV signatures, e.g. chr1." }
    aligned_bams: { help: "Array of IndexedData objects containing aligned HiFi reads." }
    reference_name: { help: "Name of the reference genome, e.g. GRCh38." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsigs: { description: "Array of SV signature files for the region." }
  }

  input {
    String region
    Array[IndexedData] aligned_bams
    String reference_name
    File tr_bed
    String conda_image
  }

  # for each aligned BAM, call SV signatures
  scatter (aligned_bam in aligned_bams) {
    call pbsv_discover_signatures {
      input:
        region = region,
        aligned_bam = aligned_bam,
        reference_name = reference_name,
        tr_bed = tr_bed,
        conda_image = conda_image
    }
  }

  output {
    Array[File] svsigs = pbsv_discover_signatures.svsig
  }
}


task pbsv_discover_signatures {
  meta {
    description: "Discovers SV signatures for a given region from an aligned BAM."
  }

  parameter_meta {
    # inputs
    region: { help: "Region of the genome to search for SV signatures, e.g. chr1." }
    aligned_bam: { help: "Dictionary of aligned HiFi reads containing 'name': STR , 'data': STR, and 'index': STR." }
    reference_name: { help: "Name of the reference genome, e.g. GRCh38." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    extra: { help: "Extra parameters to pass to pbsv." }
    log_level: { help: "Log level of pbsv." }
    output_filename: { help: "Name of the output svsig file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsig: { description: "SV signature file to be used for calling SVs" }
  }

  input {
    String region
    IndexedData aligned_bam
    String reference_name
    File tr_bed

    String extra = "--hifi"
    String log_level = "INFO"
    String output_filename = "~{aligned_bam.name}.~{reference_name}.~{region}.svsig.gz"
    
    Int threads = 4
    String conda_image
    }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(aligned_bam.data, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    conda info
    pbsv discover ~{extra} \
      --log-level ~{log_level} \
      --region ~{region} \
      --tandem-repeats ~{tr_bed} \
      ~{aligned_bam.data} \
      ~{output_filename}
    }

  output {
    File svsig = output_filename
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
