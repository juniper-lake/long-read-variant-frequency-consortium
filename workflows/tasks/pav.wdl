version 1.0

workflow run_pav {
  meta {
    description: "Finds variants from phased assembly using PAV."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    hap1_fasta: { help: "Fasta file for haplotype 1." }
    hap2_fasta: { help: "Fasta file for haplotype 2." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }

    # outputs
    vcf: { description: "VCF containing variants called using PAV." }
  }

  input {
    String sample_name
    File hap1_fasta
    File hap2_fasta
    String reference_name
    File reference_fasta
    File reference_index
  }

  call pav {
    input:
      sample_name = sample_name,
      hap1_fasta = hap1_fasta,
      hap2_fasta = hap2_fasta,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
  }
  
  call filter_pav {
    input: 
      sample_name = sample_name,
      reference_name = reference_name,
      pav_vcf = pav.vcf,
      pav_index = pav.index
  }

  output {
    File vcf = filter_pav.vcf
  }
}

task pav {
  meta {
    description: "Finds variants from phased assembly using PAV."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    hap1_fasta: { help: "Fasta file for haplotype 1." }
    hap2_fasta: { help: "Fasta file for haplotype 2." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    threads: { help: "Number of threads to use." }

    # outputs
    vcf: { description: "VCF containing variants called using PAV." }
    index: { description: "Index file for the VCF." }
  }

  input {
    String sample_name
    File hap1_fasta
    File hap2_fasta
    String reference_name
    File reference_fasta
    File reference_index
    Int threads = 48
  }

  String output_infix = "~{sample_name}_~{reference_name}"
  Int memory = 4 * threads
  Int disk_size = ceil(3.25 * (size(hap1_fasta, "GB") + size(hap2_fasta, "GB") + size(reference_fasta, "GB"))) + 20
  
  command<<<
    set -o pipefail
    echo '{"reference": "~{reference_fasta}"}' > config.json
    echo -e "NAME\tHAP1\tHAP2" > assemblies.tsv
    echo -e "~{output_infix}\t~{hap1_fasta}\t~{hap2_fasta}" >> assemblies.tsv
    snakemake -s /src/pav/Snakefile --cores ~{threads}
  >>>

  output {
    File vcf = "pav_~{output_infix}.vcf.gz"
    File index = "pav_~{output_infix}.vcf.gz.tbi"
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pav:c2bfbe6"
  }
}

task filter_pav {
  meta {
    description: "Filter SNVs and SVs<|20|bp from PAV output."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    pav_vcf: { help: "Output VCF from PAV." }
    pav_index: { help: "Output VCF index from PAV." }

    # outputs
    vcf: { description: "Filtered VCF." }
  }

  input {
    String sample_name
    String reference_name
    File pav_vcf
    File pav_index
  }

  String output_vcf = "~{sample_name}.~{reference_name}.pav.vcf"
  Int threads = 1
  Int memory = 4 * threads
  Int disk_size = ceil(3.25 * size(pav_vcf, "GB")) + 20

  command<<<
  bcftools query -e 'SVTYPE="SNV"' -f '%ID\t%SVLEN\n' ~{pav_vcf} | awk '$2>19 || $2<-19 {print $1}' > vcf_ids.txt
  bcftools filter -i 'ID=@vcf_ids.txt' ~{pav_vcf} > ~{output_vcf}
  >>>

  output {
    File vcf = output_vcf
  }
  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/bcftools:1.14"
  }
}