version 1.0

workflow run_jasmine {
  input {
    String sample_name
    Array[File] vcfs
    Array[File] bams
    Array[File] bais
    File reference_fasta
    File reference_index
    String reference_name
    Boolean merge_samples
  }

  if (!merge_samples) {
    call merge_callers {
      input: 
        sample_name = sample_name,
        vcfs = vcfs,
        bam = bams[0],
        bai = bais[0],
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        reference_name = reference_name
    }
  }

  if (merge_samples) {
    call merge_samples {
      input:
        cohort_name = sample_name,
        vcfs = vcfs,
        bams = bams,
        bais = bais,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        reference_name = reference_name
    }
  }

  output {
    File vcf = select_first([merge_callers.vcf, merge_samples.vcf])
  }
}

task merge_callers {
  meta {
    description: "Merge SVs called by multiple callers for a single sample."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    vcfs: { help: "Array of VCFs for a single sample from different SV callers." }
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    threads: { help: "Number of threads to be used." }

    # outputs
    vcf: { description: "VCF with structural variants merged by jasmineSV." }
  }

  input {
    String sample_name
    Array[File] vcfs
    File bam
    File bai
    File reference_fasta
    File reference_index
    String reference_name
    Int threads = 12
  }

  String output_vcf = "~{sample_name}.~{reference_name}.jasmine.vcf"
  Int n_vcfs = length(vcfs)
  Int memory = 3 * threads
  Int disk_size = ceil(1.5 * (size(vcfs, "GB") + size(bam, "GB") + size(reference_fasta, "GB"))) + 20

  command<<<
    set -o pipefail

    echo "~{sep="\n" vcfs}" > vcf_fofn
    printf '~{bam}\n%.0s' {1..~{n_vcfs}} > bam_fofn

    jasmine \
      threads=~{threads} \
      file_list=vcf_fofn \
      bam_list=bam_fofn \
      genome_file=~{reference_fasta} \
      out_file= ~{output_vcf} \
      min_support=2 \
      max_dist=200 \
      --run_iris \
      --pre_normalize \
      --dup_to_ins \
      --allow_intrasample \
      --nonlinear_dist
  >>>

  output {
    File vcf = output_vcf
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/jasmine:1.1.5"
  }
}

task merge_samples {
  meta {
    description: "Merge SVs across samples."
  }

  parameter_meta {
    # inputs
    cohort_name: { help: "Name of the cohort for file labeling." }
    vcfs: { help: "Array of VCFs for a single sample from different SV callers." }
    bams: { help: "BAM file of aligned reads." }
    bais: { help: "BAM index file." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    threads: { help: "Number of threads to be used." }

    # outputs
    vcf: { description: "VCF with structural variants merged by jasmineSV." }
  }

  input {
    String cohort_name
    Array[File] vcfs
    Array[File] bams
    Array[File] bais
    File reference_fasta
    File reference_index
    String reference_name
    Int threads = 12
  }

  String output_vcf = "~{cohort_name}.~{reference_name}.jasmine.vcf"
  Int memory = 4 * threads
  Int disk_size = ceil(1.5 * (size(vcfs, "GB") + size(bams, "GB") + size(reference_fasta, "GB"))) + 20

  command<<<
    set -o pipefail

    echo "~{sep="\n" vcfs}" > vcf_fofn
    echo "~{sep="\n" bams}" > bam_fofn

    jasmine \
      threads=~{threads} \
      file_list=vcf_fofn \
      bam_list=bam_fofn \
      genome_file=~{reference_fasta} \
      out_file= ~{output_vcf} \
      --output_genotypes \
      --dup_to_ins \
  >>>

  output {
    File vcf = output_vcf
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/jasmine:1.1.5"
  }
}


