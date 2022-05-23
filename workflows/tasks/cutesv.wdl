version 1.0

import "common.wdl" as common

workflow run_cutesv {
  meta {
    description: "Call structural variants from aligned reads with cuteSV, then zip and index VCF."
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
    vcf: { description: "VCF with structural variants called by Sniffles2." }
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
  
  # call structural variants with cuteSV
  call cutesv {
    input:
      sample_name = sample_name,
      bam = bam,
      bai = bai,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      conda_image = conda_image
  }

  # zip and index VCF
  call common.zip_and_index_vcf {
    input:
      input_vcf = cutesv.vcf,
      conda_image = conda_image
  }

  output {
    File vcf = zip_and_index_vcf.vcf
    File index = zip_and_index_vcf.index
  }

}


task cutesv {
  meta {
    description: "Call structural variants from aligned reads with cuteSV."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    output_vcf: { help: "Filename for output VCF." }
    work_dir: { help: "Workign directory for the job." }
    max_cluster_bias_INS: { help: "Maximum distance to cluster read together for insertion." }
    max_cluster_bias_DEL: { help: "Maximum distance to cluster read together for deletion." }
    diff_ratio_merging_INS: { help: "Do not merge breakpoints with basepair identity more than the ratio of default for insertion." }
    diff_ratio_merging_DEL: { help: "Do not merge breakpoints with basepair identity more than the ratio of default for deletion." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "VCF with structural variants called by Sniffles2." }
  }

  input {
    String sample_name
    File bam
    File bai
    String reference_name
    File reference_fasta
    File reference_index
    String output_vcf = "~{sample_name}.~{reference_name}.vcf"
    String work_dir = "."
    Int max_cluster_bias_INS = 1000
    Float diff_ratio_merging_INS = 0.9
    Int max_cluster_bias_DEL = 1000
    Float diff_ratio_merging_DEL = 0.5
    Int threads = 16
    String conda_image
  }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate cutesv
    cuteSV \
      --threads ~{threads} \
      --max_cluster_bias_INS ~{max_cluster_bias_INS} \
      --diff_ratio_merging_INS ~{diff_ratio_merging_INS} \
      --max_cluster_bias_DEL ~{max_cluster_bias_DEL} \
      --diff_ratio_merging_DEL ~{diff_ratio_merging_DEL} \
      ~{bam} ~{reference_fasta} ~{output_vcf} ~{work_dir}
  }

  output {
    File vcf = output_vcf
  }

  runtime {
    cpu: threads
    memory: "32GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
