version 1.0

workflow run_minimap2 {
  meta {
    description: "Aligns reads to a reference genome using minimap2."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Prefix for output files." }
    movies: { help: "Array of FASTQ files to be aligned." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }

    # outputs
    bam: { description: "Output BAM filename." }
    bai: { description: "Output BAM index filename." }
  }

  input {
    String sample_name
    Array[File] movies
    String reference_name
    File reference_fasta
    File reference_index
  }

  call minimap2 {
    input: 
    sample_name = sample_name,
    movies = movies,
    reference_name = reference_name,
    reference_fasta = reference_fasta,
    reference_index = reference_index,
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
    sample_name: { help: "Name of the sample." }
    movies: { help: "Array of FASTQ files to be aligned." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    output_bam: { help: "Output BAM filename." }
    samtools_threads: { help: "Number of threads to use for SAMtools in addition to main thread." }
    minimap_threads: { help: "Number of threads to use for minimap2." }

    # outputs
    bam: { description: "Output BAM filename." }
    bai: { description: "Output BAM index filename." }
  }
  
  input {
    String sample_name
    Array[File] movies
    String reference_name
    File reference_fasta
    File reference_index
    String output_bam = "~{sample_name}.~{reference_name}.bam"
    Int samtools_threads = 3
    Int minimap_threads = 24
  }

  Int disk_size = ceil(2.5 * (size(reference_fasta, "GB") + size(reference_index, "GB") + size(movies, "GB"))) + 20

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
