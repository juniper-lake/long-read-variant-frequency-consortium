version 1.0

workflow run_hifiasm {
  meta {
    description: "Assemble HiFi reads and convert to zipped FASTA."
  }

  parameter_meta {
    sample_name: { help: "Name of sample, used for file naming." }
    movies: { help: "Array of HiFi movie files in FASTA/FASTQ format." }
    conda_image: { help: "Docker image with necessary conda environments installed." }
  }

  input {
    String sample_name
    Array[File] movies
    String conda_image
  }
  
  # assemble HiFi reads
  call hifiasm_assemble {
    input:
      sample_name = sample_name,
      movies = movies,
      conda_image = conda_image
  }
  
  # convert hap1 from gfa to fasta
  call gfa2fa as gfa2fa_hap1 {
    input:
      gfa = hifiasm_assemble.hap1,
      conda_image = conda_image
  }

  # convert hap2 from gfa to fasta
  call gfa2fa as gfa2fa_hap2 {
    input:
      gfa = hifiasm_assemble.hap2,
      conda_image = conda_image
  }

  # zip hap1 fasta
  call bgzip_fasta as bgzip_hap1 {
    input:
      fasta = gfa2fa_hap1.fasta,
      conda_image = conda_image
  }

  # zip hap2 fasta
  call bgzip_fasta as bgzip_hap2 {
    input:
      fasta = gfa2fa_hap2.fasta,
      conda_image = conda_image
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
    movies: { help: "Array of HiFi movie files in FASTA/FASTQ format." }
    output_prefix: { help: "Prefix for output files." }
    threads: { help: "Number of threads to use." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    hap1: { description: "GFA file of hap1 assembly." }
    hap2: { description: "GFA file of hap2 assembly." }
  }

  input {
    String sample_name
    Array[File] movies
    String output_prefix = "~{sample_name}.asm"
    Int threads = 48
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(movies, "GB")) + 20
  Int memory = threads * 3
  
  command {
    set -o pipefail
    source ~/.bashrc
    conda info --envs
    conda activate hifiasm
    hifiasm -o ~{output_prefix} -t ~{threads} ~{sep=" " movies}
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
    docker: conda_image
  }
}


task gfa2fa {
  meta {
    description: "Convert GFA file to FASTA file."
  }

  parameter_meta {
    # inputs
    gfa: { help: "GFA file to convert." }
    output_filename: { help: "Filename for output FASTA." }
    threads: { help: "Number of threads to use." }
    conda_image: { help: "Docker image with necessary conda environments installed." }
    
    # outputs
    fasta: { description: "FASTA file." }
  }
  input {
    File gfa
    String output_filename = "~{basename(gfa, '.bam')}.fasta"
    Int threads = 4
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(gfa, "GB")) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate gfatools
    gfatools gfa2fa ~{gfa} > ~{output_filename}
  }

  output {
    File fasta = output_filename
  }

  runtime {
    cpu: threads
    memory: "14GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


task bgzip_fasta {
  meta {
    description: "Zip FASTA file."
  }

  parameter_meta {
    # inputs
    fasta: { help: "FASTA file to zip." }
    output_filename: { help: "Filename for output zipped FASTA." }
    threads: { help: "Number of threads to use." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    gzipped_fasta: { description: "Zipped FASTA file." }
  }
  
  input {
    File fasta
    String output_filename = "~{basename(fasta)}.gz"
    Int threads = 4
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(fasta, "GB")) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate htslib
    bgzip --threads ~{threads} ~{fasta} -c > ~{output_filename}
  }

  output {
    File gzipped_fasta = output_filename
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}