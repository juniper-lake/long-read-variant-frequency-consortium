version 1.0

import "structs.wdl"

task pbsv_discover_signatures {
  meta {
    description: "This task will discover SV signatures for a given region from an aligned BAM."
  }

  parameter_meta {
    # inputs
    region: "Region of the genome to search for SV signatures, e.g. chr1."
    aligned_bam: "Dictionary of aligned HiFi reads containing 'name': STR , 'data': STR, and 'index': STR."
    reference_name: "Name of the reference genome, e.g. GRCh38."
    tr_bed: "BED file containing known tandem repeats."
    extra: "Extra parameters to pass to pbsv."
    log_level: "Log level of pbsv."
    output_filename: "Name of the output svsig file."
    threads: "Number of threads to be used."
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    svsig: "SV signature file to be used for calling SVs"
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
    disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


workflow pbsv_discover_signatures_across_bams {
  meta {
    description: "This workflow will discover SV signatures for a given region from multiple aligned BAMs."
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
    # SV signature files for each aligned BAM for a given region
    Array[File] svsigs = pbsv_discover_signatures.svsig
  }
}
