version 1.0

import "common.wdl" as common


workflow run_pbsv_call {
  meta { 
    description: "Discovers SV signatures and calls SVs for either single samples or a sample set (joint calling)."
  }
  
  parameter_meta {
    # inputs
    sample_name: { help: "Name of sample or sample set." }
    svsigs: { help: "Array of SV signature files." }
    svsigs_nested: { help: "Nested array of SV signature files." }
    regions: { help: "Array of chromosomes or other genomic regions in which to search for SVs." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    pbsv_vcf: { description: "Genome-wide VCF with SVs called from all provided BAMs (singleton or joint)." }
    pbsv_index: { description: "Index file for the VCF." }
    pbsv_region_vcfs: { description: "Region-specific VCFs with SVs called from all provided BAMs (singleton or joint)." }
    pbsv_region_indexes: { description: "Region-specific VCF indexes." }
  }

  input {
    String sample_name
    Array[File] svsigs
    Array[Array[File]] svsigs_nested = []
    Array[String] regions
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
    String conda_image
  }
  
  # since workflow is used for single and joint calling, input can be an array of files (for singleton) or a nested array of files (for joint)
  Array[File] svsigs_flattened = flatten([svsigs, flatten(svsigs_nested)])
  
  scatter (idx in range(length(regions))) {
    # using filenames to parse region names, gather all svsigs for a region
    call subset_svsigs_by_region {
      input: 
        input_svsigs = svsigs_flattened,
        region = regions[idx],
        conda_image = conda_image
    }

    # call variants by region
    call pbsv_call_by_region {
      input: 
        sample_name = sample_name,
        svsigs = subset_svsigs_by_region.svsigs,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        region = regions[idx],
        conda_image = conda_image
    }    

    # zip and index region-specific VCFs
    call common.zip_and_index_vcf {
      input: 
        input_vcf = pbsv_call_by_region.vcf,
        conda_image = conda_image
    }
  }

  # concatenate all region-specific VCFs into a single genome-wide VCF
  call concat_pbsv_vcfs {
    input: 
      sample_name = sample_name,
      reference_name = reference_name,
      input_vcfs = zip_and_index_vcf.vcf,
      input_indexes = zip_and_index_vcf.index,
      conda_image = conda_image
  }

  # gzip and index the genome-wide VCF
  call common.zip_and_index_vcf as zip_and_index_final_vcf {
    input: 
      input_vcf = concat_pbsv_vcfs.vcf,
      conda_image = conda_image
  }

  output {
    File pbsv_vcf = zip_and_index_final_vcf.vcf
    File pbsv_index = zip_and_index_final_vcf.index
    Array[File] pbsv_region_vcfs = zip_and_index_vcf.vcf
    Array[File] pbsv_region_indexes = zip_and_index_vcf.index
  }
}


task subset_svsigs_by_region {
  meta {
    description: "Given an array of svsigs, parse filenames to determine which svsigs are for the given region."
  }

  parameter_meta {
    # inputs
    input_svsigs: { help: "Array of SV signature files." }
    region: { help: "Region of the genome to use for subsetting input_svsigs." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsigs: { description: "Array of SV signature files for the given region." }
  }

  input {
    Array[File] input_svsigs
    String region
    String conda_image
  }

  command {
    ls ~{sep=" " input_svsigs} | grep -F ".~{region}.svsig.gz"
  }

  output {
    Array[File] svsigs = read_lines(stdout())
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


task pbsv_call_by_region {
  meta {
    description: "Calls SVs for a given region from SV signatures in single samples or jointly call in sample set."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of sample (if singleton) or group (if set of samples)." }
    svsigs: { help: "SV signature files to be used for calling SVs." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    region: { help: "Region of the genome to call structural variants, e.g. chr1." }
    extra: { help: "Extra parameters to pass to pbsv." }
    log_level: { help: "Log level." }
    output_filename: { help: "Name of the output VCF file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    vcf: { description: "VCF file containing the called SVs." }
  }

  input {
    String sample_name
    Array[File] svsigs
    String reference_name
    File reference_fasta
    File reference_index
    String region
    String extra = "--hifi -m 20"
    String log_level = "INFO"
    String output_filename = "~{sample_name}.~{reference_name}.~{region}.pbsv.vcf"
    Int threads = 8
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(svsigs, "GB") + size(reference_fasta, "GB"))) + 20

  command<<<
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv

    for svsig in ~{sep=" " svsigs}; do
      if [[ $svsig != *~{region}.svsig.gz ]]; then
        printf '%s\n' "Region does not match svsig filename." >&2
        exit 1
      fi
    done

    pbsv call ~{extra} \
      --log-level ~{log_level} \
      --num-threads ~{threads} \
      ~{reference_fasta} \
      ~{sep=" " svsigs} \
      ~{output_filename}
  >>>

  output {
    File vcf = output_filename
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


task concat_pbsv_vcfs {
  meta {
    description: "Concatenates all the region-specific VCFs for a given sample or sample set into a single genome-wide VCF."
  }

  parameter_meta {
    #inputs
    sample_name: { help: "Name of sample (if singleton) or group (if set of samples)." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    input_vcfs: { help: "VCF files to be concatenated." }
    input_indexes: { help: "Index files for VCFs." }
    extra: { help: "Extra parameters to pass to bcftools." }
    output_filename: { help: "Name of the output VCF file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    #outputs
    vcf: { description: "VCF file containing the concatenated SV calls." }
  }

  input {
    String sample_name
    String reference_name
    Array[File] input_vcfs
    Array[File] input_indexes
    String extra = "--allow-overlaps"
    String output_filename = "~{sample_name}.~{reference_name}.pbsv.vcf"
    Int threads = 4
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(input_vcfs, "GB") + size(input_indexes, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate bcftools
    conda info
    bcftools concat ~{extra} \
      --output ~{output_filename} \
      ~{sep=" " input_vcfs} \
  }

  output {
    File vcf = output_filename
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}
