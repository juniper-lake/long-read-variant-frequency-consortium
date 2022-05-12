version 1.0

import "structs.wdl"

task align_ubam_or_fastq {
  meta {
    description: "Aligns HiFi reads to reference genome from either a BAM or FASTQ file."
  }

  parameter_meta {
    # inputs
    reference: { help: "An IndexedData object with information about the reference." }
    movie: { help: "A MovieInfo object with information about the HiFi reads movie." }
    sample_name: { help: "Name of the sample." }
    preset_option: { help: "This option applies multiple options at the same time." }
    log_level: { help: "Log level of pbmm2." }
    extra: { help: "Additional pbmm2 options." }
    unmapped: { help: "If true, unmapped reads are added to the output BAM file." }
    sort: { help: "If true, will sort the output bam file." }
    output_filename: { help: "Name of the output bam file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    aligned_bam: { description: "An IndexedData object with aligned HiFi reads and index." }
    aligned_bam_file: { description: "Aligned bam file." }
    aligned_bam_index: { description: "Aligned bam index." }
  }

  input {
    IndexedData reference
    MovieInfo movie
    String sample_name

    String preset_option = "CCS"
    String log_level = "INFO"
    String extra = "-c 0 -y 70"
    Boolean unmapped = true
    Boolean sort = true
    String output_filename = "~{movie.name}.~{reference.name}.bam"
    
    Int threads = 24
    String conda_image
    }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(reference.data, "GB") + size(reference.index, "GB") + size(movie.path, "GB"))) + 20
  
  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbmm2
    conda info
    pbmm2 align \
      --sample ~{sample_name} \
      --log-level ~{log_level} \
      --preset ~{preset_option} \
      ~{true="--sort" false="" sort} \
      ~{true="--unmapped" false="" unmapped} \
      ~{extra} \
      -j ~{threads} \
      ~{reference.data} \
      ~{movie.path} \
      ~{output_filename}
    }

  output {
    IndexedData aligned_bam = {
      "name": movie.name, 
      "data": output_filename, 
      "index": "~{output_filename}.bai"
      }
    File aligned_bam_file = output_filename
    File aligned_bam_index = "~{output_filename}.bai"
  }

  runtime {
    cpu: threads
    memory: "96GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}

