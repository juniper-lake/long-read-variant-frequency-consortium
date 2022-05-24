version 1.0

workflow run_deepvariant {
  input {
    String sample_name
    Array[File] bams
    Array[File] bais
    String reference_name
    File reference_fasta
    File reference_index
    String deepvariant_image
  }

  call deepvariant {
    input: 
      sample_name = sample_name,
      bams = bams,
      bais = bais,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      deepvariant_image = deepvariant_image
  }

  output {
    File vcf = deepvariant.vcf
    File index = deepvariant.index
  }
}

task deepvariant {
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
    threads: { help: "Number of threads to be used." }
    deepvariant_image: { help: "Docker image for Google's DeepVariant." }

    # outputs
    vcf: { description: "Small variant calls output by DeepVariant." }
    index: { description: "VCF index for small variants called by DeepVariant." }
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
      --num_shards=~{threads}
  }

  output {
    File vcf = output_vcf
    File index = "~{vcf}.tbi"
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