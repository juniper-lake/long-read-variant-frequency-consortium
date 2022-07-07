version 1.0

import "common.wdl" as common

workflow run_hifiasm {
  meta {
    description: "Assemble HiFi reads and convert to zipped FASTA."
  }

  parameter_meta {
    sample_name: { help: "Name of sample, used for file naming." }
    movie_fastxs: { help: "Array of HiFi movie files in FASTA/FASTQ format." }
  }

  input {
    String sample_name
    Array[File] movie_fastxs
  }
  
  # assemble HiFi reads
  call hifiasm_assemble {
    input:
      sample_name = sample_name,
      movie_fastxs = movie_fastxs,
  }
  
  # convert hap1 from gfa to fasta
  call gfa2fa as gfa2fa_hap1 {
    input:
      gfa = hifiasm_assemble.hap1,
  }

  # convert hap2 from gfa to fasta
  call gfa2fa as gfa2fa_hap2 {
    input:
      gfa = hifiasm_assemble.hap2,
  }

  # zip hap1 fasta
  call common.bgzip_fasta as bgzip_hap1 {
    input:
      fasta = gfa2fa_hap1.fasta,
  }

  # zip hap2 fasta
  call common.bgzip_fasta as bgzip_hap2 {
    input:
      fasta = gfa2fa_hap2.fasta,
  }
  
  output {
    File hap1_fasta = bgzip_hap1.gzipped_fasta
    File hap2_fasta = bgzip_hap2.gzipped_fasta
  }
}


task hifiasm_assemble {
  meta {
    description: "Assemble HiFi reads with hifiasm."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of sample, used for file naming." }
    movie_fastxs: { help: "Array of HiFi movie files in FASTA/FASTQ format." }
    output_prefix: { help: "Prefix for output files." }
    threads: { help: "Number of threads to use." }

    # outputs
    hap1: { description: "GFA file of hap1 assembly." }
    hap2: { description: "GFA file of hap2 assembly." }
  }

  input {
    String sample_name
    Array[File] movie_fastxs
    String output_prefix = "~{sample_name}.asm"
    Int threads = 48
  }

  Int disk_size = ceil(3.25 * size(movie_fastxs, "GB")) + 20
  Int memory = 3 * threads
  
  command {
    set -o pipefail
    hifiasm -o ~{output_prefix} -t ~{threads} ~{sep=" " movie_fastxs}
  }

  output {
    File hap1 = "~{output_prefix}.bp.hap1.p_ctg.gfa"
    File hap2 = "~{output_prefix}.bp.hap2.p_ctg.gfa"
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/hifiasm:0.16.1"
  }
}


task gfa2fa {
  meta {
    description: "Convert GFA file to FASTA file."
  }

  parameter_meta {
    # inputs
    gfa: { help: "GFA file to convert." }
    threads: { help: "Number of threads to use." }
    
    # outputs
    fasta: { description: "FASTA file." }
  }
  input {
    File gfa
    Int threads = 4
  }

  String output_filename = "~{basename(gfa, '.gfa')}.fasta"
  Int memory = 3 * threads
  Int disk_size = ceil(3.25 * size(gfa, "GB")) + 20

  command {
    set -o pipefail
    gfatools gfa2fa ~{gfa} > ~{output_filename}
  }

  output {
    File fasta = output_filename
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/gfatools:0.4"
  }
}
