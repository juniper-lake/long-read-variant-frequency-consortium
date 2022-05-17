version 1.0

workflow pbsv_discover_signatures_across_bams {
  meta {
    description: "Discovers SV signatures for a given region from multiple aligned BAMs."
  }

  parameter_meta {
    # inputs
    region: { help: "Region of the genome to search for SV signatures, e.g. chr1." }
    aligned_bams: { help: "Array of aligned BAM files." }
    aligned_bam_indexes: { help: "Array of bam BAI indexes."}
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsigs: { description: "Array of SV signature files for the region." }
  }

  input {
    String region
    Array[File] aligned_bams
    Array[File] aligned_bam_indexes
    String reference_name
    File tr_bed
    String conda_image
  }

  # for each aligned BAM, call SV signatures
  scatter (idx in range(length(aligned_bams))) {
    call pbsv_discover_signatures {
      input:
        region = region,
        aligned_bam = aligned_bams[idx],
        aligned_bam_index = aligned_bam_indexes[idx],
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
    aligned_bam: { help: "Aligned BAM file." }
    aligned_bam_indexe: { help: "Aligned BAM index (BAI) file." }
    reference_name: { help: "Name of the reference genome, e.g. GRCh38." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    extra: { help: "Extra parameters to pass to pbsv." }
    log_level: { help: "Log level of pbsv." }
    prefix: { help: "Prefix for output files consisting of movie and reference names." }
    output_filename: { help: "Name of the output svsig file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsig: { description: "SV signature file to be used for calling SVs" }
  }

  input {
    String region
    File aligned_bam
    File aligned_bam_index
    String reference_name
    File tr_bed
    String extra = "--hifi"
    String log_level = "INFO"
    String prefix = basename(aligned_bam, ".bam")
    String output_filename = "~{prefix}.~{region}.svsig.gz"
    Int threads = 4
    String conda_image
    }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(aligned_bam, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    pbsv discover ~{extra} \
      --log-level ~{log_level} \
      --region ~{region} \
      --tandem-repeats ~{tr_bed} \
      ~{aligned_bam} \
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
