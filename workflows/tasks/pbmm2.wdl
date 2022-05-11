version 1.0

import "structs.wdl"

task align_ubam_or_fastq {
  meta {
    description: "This task will align HiFi reads from either a BAM or FASTQ file."
  }

  parameter_meta {
    # inputs
    reference: "Dictionary describing reference genome containing 'name': STR, 'data': STR, and 'index': STR."
    movie: "Dictionary of unaligned HiFi reads containing 'name': STR , 'path': STR, and 'isUbam': BOOL."
    sample_name: "Name of the sample."
    preset_option: "This option applies multiple options at the same time."
    log_level: "Log level of pbmm2."
    extra: "Additional pbmm2 options."
    unmapped: "If true, unmapped reads are added to the output BAM file."
    sort: "If true, will sort the output bam file."
    output_filename: "Name of the output bam file."
    threads: "Number of threads to be used."
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    aligned_bam: "Dictionary containing 'name': STR, 'data': STR, and 'index': STR."
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
  }

  runtime {
    cpu: threads
    memory: "96GB"
    disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}

