version 1.0

workflow run_sniffles {
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
  }

  output {
    File vcf = sniffles.vcf
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
    File tr_bed
    Int threads = 8
  }

  String output_vcf = "~{sample_name}.~{reference_name}.sniffles.vcf"
  Int memory = 4 * threads
  Int disk_size = ceil(2.5 * (size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command {
    set -o pipefail
    sniffles \
      --threads ~{threads} \
      --sample-id ~{sample_name}_sniffles \
      --minsvlen 20 \
      --mapq 20 \
      --minsupport 2 \
      --reference ~{reference_fasta} \
      --tandem-repeats ~{tr_bed} \
      --input ~{bam} \
      --vcf ~{output_vcf}
  }

  output {
    File vcf = output_vcf
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/sniffles:2.0"
  }
}
