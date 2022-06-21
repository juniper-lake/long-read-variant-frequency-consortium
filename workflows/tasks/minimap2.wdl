version 1.0

import "common.wdl" as common

workflow run_minimap2 {
  meta {
    description: "Aligns reads to a reference genome using minimap2."
  }

  parameter_meta {
    # inputs
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    movies: { help: "Array of FASTQ files to be aligned." }
    output_prefix: { help: "Prefix for output files." }

    # outputs
    bam: { description: "Output BAM filename." }
    bai: { description: "Output BAM index filename." }
  }

  input {
    String reference_name
    File reference_fasta
    File reference_index
    Array[File] movies
    String output_prefix
  }

  call minimap2 {
    input: 
    reference_name = reference_name,
    reference_fasta = reference_fasta,
    reference_index = reference_index,
    movies = movies,
    output_prefix = output_prefix,
  }

  output {
    File bam = minimap2.bam
    File bai = minimap2.bai
  }
}

task minimap2 {
  meta {
    description: "Aligns reads to a reference genome using minimap2."
  }

  parameter_meta {
    # inputs
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    movies: { help: "Array of FASTQ files to be aligned." }
    output_prefix: { help: "Prefix for output files." }
    output_bam: { help: "Output BAM filename." }
    samtools_threads: { help: "Number of threads to use for SAMtools in addition to main thread." }
    minimap_threads: { help: "Number of threads to use for minimap2." }

    # outputs
    bam: { description: "Output BAM filename." }
    bai: { description: "Output BAM index filename." }
  }
  
  input {
    String reference_name
    File reference_fasta
    File reference_index
    Array[File] movies
    String output_prefix
    String output_bam = "~{output_prefix}.~{reference_name}.bam"
    Int samtools_threads = 3
    Int minimap_threads = 24
  }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(reference_fasta, "GB") + size(reference_index, "GB") + size(movies, "GB"))) + 20

  command {
    set -o pipefail
    minimap2 -t ~{minimap_threads} -ax map-hifi ~{reference_fasta} ~{sep=" " movies} \
      | samtools sort -@ ~{samtools_threads} > ~{output_bam}
    samtools index ~{output_bam}
  }

  output {
    File bam = "~{output_bam}"
    File bai = "~{output_bam}.bai"
  }

  runtime {
    cpu: samtools_threads + minimap_threads + 1
    memory: "96GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/minimap2:2.24"
  }
}
