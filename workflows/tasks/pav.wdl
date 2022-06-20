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
    index: { description: "Index file for the VCF." }
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
  
  output {
    File vcf = pav.vcf
    File index = pav.index
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
    output_infix: { help: "Infix to add to the output file names." }
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
    String output_infix = "~{sample_name}_~{reference_name}"
    Int threads = 48
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(hap1_fasta, "GB") + size(hap2_fasta, "GB") + size(reference_fasta, "GB"))) + 20
  
  command<<<
    set -o pipefail
    
    echo '{"reference": "~{reference_fasta}"}' > config.json
    echo -e "NAME\tHAP1\tHAP2" > assemblies.tsv
    echo -e "~{output_infix}\t~{hap1_fasta}\t~{hap2_fasta}" >> assemblies.tsv
    snakemake -s $PAV/Snakefile --cores ~{threads}
  >>>

  output {
    File vcf = "pav_~{output_infix}.vcf.gz"
    File index = "pav_~{output_infix}.vcf.gz.tbi"
  }

  runtime {
    cpu: threads
    memory: "32GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pav:c2bfbe6"
  }
}
