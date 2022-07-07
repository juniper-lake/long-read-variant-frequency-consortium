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
  }

  # zip and index VCF
  call common.zip_and_index_vcf {
    input:
      input_vcf = cutesv.vcf,
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
    threads: { help: "Number of threads to be used." }

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
    Int threads = 16
  }

  Int disk_size = ceil(2.5 * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    cuteSV \
      --threads ~{threads} \
      --sample ~{sample_name}_cutesv \
      --genotype \
      --min_size 30 \
      --min_mapq 20 \
      --min_support 2 \
      --max_cluster_bias_INS 1000 \
      --diff_ratio_merging_INS 0.9 \
      --max_cluster_bias_DEL 1000 \
      --diff_ratio_merging_DEL 0.5 \
      ~{bam} ~{reference_fasta} ~{output_vcf} "./"
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
    docker: "juniperlake/cutesv:1.0.13"
  }
}
