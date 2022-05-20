version 1.0

task run_deepvariant {
  meta {
    description: "Calls small variants from aligned BAMs with DeepVariant."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bams: { help: "Array of aligned BAM files." }
    bais: { help: "Array of aligned BAM index files." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    model_type: { help: "One of the following [WGS,WES,PACBIO,HYBRID_PACBIO_ILLUMINA]." }
    output_vcf: { help: "Filename for the output VCF file." }
    output_gvcf: { help: "Filename for the output GVCF file." }
    output_report: { help: "Filename for the output visual report file." }
    threads: { help: "Number of threads to be used." }
    deepvariant_image: { help: "Docker image for Google's DeepVariant." }

    # outputs
    vcf: { description: "Small variant calls output by DeepVariant." }
    vcf_index: { description: "VCF index for small variants called by DeepVariant." }
    gvcf: { description: "Global VCF of small variant calls output by DeepVariant." }
    gvcf_index: { description: "GVCF index for small variants called by DeepVariant." }
    report: { description: "Visual report of the small variant calls output by DeepVariant." }

  }
  
  input {
    String sample_name
    Array[File] bams
    Array[File] bais
    String reference_name
    File reference_fasta
    File reference_index
    String model_type = "PACBIO"
    String output_vcf = "~{sample_name}.~{reference_name}.deepvariant.vcf.gz"
    String output_gvcf = "~{sample_name}.~{reference_name}.deepvariant.g.vcf.gz"
    String output_report = "~{sample_name}.~{reference_name}.deepvariant.visual_report.html"
    Int threads = 64
    String deepvariant_image
  }
  
  Float memory_multiplier = 15
  Int memory = ceil(memory_multiplier * size(bams, "GB"))
  Float disk_multiplier = 3.25
  Int disk_size = ceil(disk_multiplier * (size(reference_fasta, "GB") + size(bams, "GB"))) + 20

  command {
    set -o pipefail
    /opt/deepvariant/bin/run_deepvariant \
      --model_type=~{model_type} \
      --ref=~{reference_fasta} \
      --reads=~{sep="," bams} \
      --output_vcf=~{output_vcf} \
      --output_gvcf=~{output_gvcf} \
      --num_shards=~{threads}
  }

  output {
    File vcf = output_vcf
    File vcf_index = "~{vcf}.tbi"
    File gvcf = output_gvcf
    File gvcf_index = "~{gvcf}.tbi"
    File report = output_report
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: deepvariant_image
  }
}
