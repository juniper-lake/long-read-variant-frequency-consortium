version 1.0

import "common.wdl" as common

workflow run_pbmm2 {
  meta {
    description: "Align array of movies using pbmm2."
  }

  parameter_meta {
    # inputs
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    movies: { help: "Array of BAMs and/or FASTQs containing HiFi reads." }
    sample_name: { help: "Name of the sample." }

    # outputs
    bams: { description: "Array of aligned bam file." }
    bais: { description: "Array of aligned bam index." }
  }

  input {
    String reference_name
    File reference_fasta
    File reference_index
    Array[File] movies
    String sample_name
  }
  
  scatter (idx in range(length(movies))) { 
    # for each movie, get the movie name for file naming
    call common.get_movie_name {
      input:
        movie = movies[idx],
    }
    
    # align each movie with pbmm2
    call pbmm2_align {
        input: 
          reference_name = reference_name,
          reference_fasta = reference_fasta,
          reference_index = reference_index,
          movie = movies[idx],
          movie_name = get_movie_name.movie_name,
          sample_name = sample_name,
    }
  }

  output {
    Array[File] bams = pbmm2_align.bam
    Array[File] bais = pbmm2_align.bai
  }
}


task pbmm2_align {
  meta {
    description: "Aligns HiFi reads to reference genome from either a BAM or FASTQ file."
  }

  parameter_meta {
    # inputs
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    movie: { help: "An BAM or FASTQ file containing HiFi reads." }
    movie_name: { help: "Name of the HiFi reads movie, used for file labeling." }
    sample_name: { help: "Name of the sample." }
    preset_option: { help: "This option applies multiple options at the same time." }
    log_level: { help: "Log level of pbmm2." }
    extra: { help: "Additional pbmm2 options." }
    unmapped: { help: "If true, unmapped reads are added to the output BAM file." }
    sort: { help: "If true, will sort the output bam file." }
    output_bam: { help: "Name of the output bam file." }
    threads: { help: "Number of threads to be used." }

    # outputs
    bam: { description: "Aligned bam file." }
    bai: { description: "Aligned bam index." }
  }

  input {
    String reference_name
    File reference_fasta
    File reference_index
    File movie
    String movie_name
    String sample_name
    String preset_option = "CCS"
    String log_level = "INFO"
    String extra = "-c 0 -y 70"
    Boolean unmapped = true
    Boolean sort = true
    String output_bam = "~{movie_name}.~{reference_name}.bam"
    Int threads = 24
    }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(reference_fasta, "GB") + size(reference_index, "GB") + size(movie, "GB"))) + 20
  
  command {
    set -o pipefail
    source ~/.bashrc
    pbmm2 align \
      --sample ~{sample_name} \
      --log-level ~{log_level} \
      --preset ~{preset_option} \
      ~{true="--sort" false="" sort} \
      ~{true="--unmapped" false="" unmapped} \
      ~{extra} \
      -j ~{threads} \
      ~{reference_fasta} \
      ~{movie} \
      ~{output_bam}
    }

  output {
    File bam = output_bam
    File bai = "~{output_bam}.bai"
  }

  runtime {
    cpu: threads
    memory: "96GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pbmm2:1.7.0"
  }
}
