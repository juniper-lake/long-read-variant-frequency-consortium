version 1.0

task run_pbmm2 {
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
    conda_image: { help: "Docker image with necessary conda environments installed." }

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
    String conda_image
    }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(reference_fasta, "GB") + size(reference_index, "GB") + size(movie, "GB"))) + 20
  
  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbmm2
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
    docker: conda_image
  }
}

