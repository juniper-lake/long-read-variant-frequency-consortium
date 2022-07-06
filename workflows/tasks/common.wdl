version 1.0

task sort_vcf {
  meta {
    description: "Sorts a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "VCF file to be sorted." }
    output_filename: { help: "Output filename." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
  }

  input {
    File input_vcf
    String output_filename
  }

  Int disk_size = ceil(3.25 * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bcftools sort ~{input_vcf} -Ov -o ~{output_filename}
  }

  output {
    File vcf = output_filename
  }

  runtime {
    memory: "16GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/bcftools:1.14"
  }
}


task zip_and_index_vcf {
  meta {
    description: "Zips and indexes a vcf file."
  }

  parameter_meta {
    # inputs
    input_vcf: { help: "VCF file to be gzipped and indexed." }
    output_filename: { help: "Output filename." }
    threads: { help: "Number of threads to use." }

    # outputs
    vcf: { description: "Gzipped and indexed VCF file." }
    index: { description: "Tabix index file." }
  }

  input {
    File input_vcf
    String output_filename = "~{basename(input_vcf)}.gz"
    Int threads = 2
  }

  Int disk_size = ceil(3.25 * size(input_vcf, "GB")) + 20

  command {
    set -o pipefail
    bgzip --threads ~{threads} ~{input_vcf} -c > ~{output_filename}
    tabix --preset vcf ~{output_filename}
  }

  output {
    File vcf = output_filename
    File index = "~{output_filename}.tbi"
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/htslib:1.14"
  }
}
