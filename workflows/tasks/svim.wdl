version 1.0

task run_svim {
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
    output_dir: { help: "Output directory." }
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
    String output_dir = "~{sample_name}_~{reference_name}"
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate svim
    svim alignment ~{output_dir} ~{bam} ~{reference_fasta}
  }

  output {
    File vcf = "~{output_dir}/variants.vcf"
  }

  runtime {
    memory: "8GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
