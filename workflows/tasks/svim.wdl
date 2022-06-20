version 1.0

import "common.wdl" as common

workflow run_svim {
  meta {
    description: "Call structural variants with SVIM, then zip and index VCF."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "Gzipped VCF with structural variants called by SVIM." }
    index: { description: "VCF index file." }
  }

  input {
    String sample_name
    File bam
    File bai
    String reference_name
    File reference_fasta
    File reference_index
    String conda_image
  }

  # call structural variants from aligned bam file with SVIM
  call svim_alignment {
    input:
      sample_name = sample_name,
      bam = bam,
      bai = bai,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      conda_image = conda_image
  }

  # sort VCF
  call common.sort_vcf {
    input:
      input_vcf = svim_alignment.vcf,
      output_filename = "~{sample_name}.~{reference_name}.svim.vcf"
  }

  # zip and index VCF
  call common.zip_and_index_vcf {
    input:
      input_vcf = sort_vcf.vcf,
      conda_image = conda_image
  }

  output {
    File vcf = zip_and_index_vcf.vcf
    File index = zip_and_index_vcf.index
  }
}


task svim_alignment {
  meta {
    description: "Call structural variants from aligned reads with SVIM."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    output_directory: { help: "Name of output VCF." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "VCF with structural variants called by SVIM." }
  }
  
  input {
    String sample_name
    File bam
    File bai
    String reference_name
    File reference_fasta
    File reference_index
    String output_directory = "~{sample_name}_~{reference_name}"
    String conda_image
  }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate svim
    svim alignment ~{output_directory} ~{bam} ~{reference_fasta}
  }

  output {
    File vcf = "~{output_filename}/variants.vcf"
  }

  runtime {
    memory: "8GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
