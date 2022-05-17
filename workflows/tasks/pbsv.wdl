version 1.0

import "pbsv_discover.wdl" as pbsv_discover
import "common.wdl" as common


workflow run_pbsv {
  meta { 
    description: "Discovers SV signatures and calls SVs for either single samples or a sample set (joint calling)."
  }
  
  parameter_meta {
    # inputs
    name: { help: "Name of sample or sample set." }
    aligned_bams: { help: "Array of aligned BAM files." }
    aligned_bam_indexes: { help: "Array of aligned BAM index files." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    regions: { help: "List of chromosomes or other genomic regions in which to search for SVs." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsigs: { description: "Array of SV signature files for each region for each provided BAM." }
    pbsv_vcf: { description: "Genome-wide VCF with SVs called from all provided BAMs (singleton or joint)." }
    pbsv_region_vcfs: { description: "Region-specific VCFs with SVs called from all provided BAMs (singleton or joint)." }
    pbsv_region_indexes: { description: "Region-specific VCF indexes." }
  }

  input {
    String sample_name
    Array[File] aligned_bams
    Array[File] aligned_bam_indexes
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
    Array[String] regions
    String conda_image
  }

  # for each region, discover SV signatures in all aligned_bams
  scatter (region in regions) {
    call pbsv_discover.pbsv_discover_signatures_across_bams {
      input: 
        region = region,
        aligned_bams = aligned_bams,
        aligned_bam_indexes = aligned_bam_indexes,
        reference_name = reference_name,
        tr_bed = tr_bed,
        conda_image = conda_image
    }
  }
  
  # for each region, call SVs from svsig files for that region
  scatter (region_idx in range(length(regions))) {
    call pbsv_call_variants {
      input: 
        sample_name = sample_name,
        svsigs = pbsv_discover_signatures_across_bams.svsigs[region_idx],
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        region = regions[region_idx],
        conda_image = conda_image
    }    

    call common.zip_and_index_vcf {
      input: 
        input_vcf = pbsv_call_variants.vcf,
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
    Array[Array[File]] svsigs = pbsv_discover_signatures_across_bams.svsigs
    File pbsv_vcf = zip_and_index_final_vcf.vcf
    Array[File] pbsv_region_vcfs = zip_and_index_vcf.vcf
    Array[File] pbsv_region_indexes = zip_and_index_vcf.index
  }
}


task pbsv_call_variants {
  meta {
    description: "Calls SVs for a given region from SV signatures. It can be used to call SVs in single samples or jointly call in sample set."
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

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    conda info
    pbsv call ~{extra} \
      --log-level ~{log_level} \
      --num-threads ~{threads} \
      ~{reference_fasta} \
      ~{sep=" " svsigs} \
      ~{output_filename}
  }

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
