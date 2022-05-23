version 1.0

workflow run_sniffles {
  input {
    String sample_name
    File bam
    File bai
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed 
    String conda_image
  }

  call sniffles {
    input: 
      sample_name = sample_name,
      bam = bam,
      bai = bai,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      tr_bed = tr_bed,
      conda_image = conda_image
  }

  output {
    File vcf = sniffles.vcf
    File index = sniffles.index
  }
}


task sniffles {
  meta {
    description: "Call structural variants from aligned reads with Sniffles2."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    output_vcf: { help: "Filename for output VCF." }
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
    File tr_bed
    String output_vcf = "~{sample_name}.~{reference_name}.sniffles.vcf.gz"
    Int threads = 8
    String conda_image
  }

  Float multiplier = 2.5
  Int disk_size = ceil(multiplier * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate sniffles
    sniffles \
      --threads ~{threads} \
      --reference ~{reference_fasta} \
      --tandem-repeats ~{tr_bed} \
      --input ~{bam} \
      --vcf ~{output_vcf}
  }

  output {
    File vcf = output_vcf
    File index = "~{output_vcf}.tbi"
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
