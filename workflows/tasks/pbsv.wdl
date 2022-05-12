version 1.0

import "structs.wdl"
import "pbsv_discover.wdl" as pbsv_discover
import "common.wdl" as common


workflow run_pbsv {
  meta { 
    description: "Discovers SV signatures and calls SVs for either single samples or a sample set (joint calling)."
  }
  
  parameter_meta {
    # inputs
    name: { help: "Name of sample or sample set." }
    aligned_bams: { help: "Aligned BAM files." }
    reference: { help: "Dictionary describing reference genome containing 'name': STR, 'data': STR, and 'index': STR." }
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
    String name
    Array[IndexedData] aligned_bams
    IndexedData reference
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
        reference_name = reference.name,
        tr_bed = tr_bed,
        conda_image = conda_image
    }
  }
  
  # for each region, call SVs from svsig files for that region
  scatter (region_index in range(length(regions))) {
    call pbsv_call_variants {
      input: 
        entity_name = name,
        svsigs = pbsv_discover_signatures_across_bams.svsigs[region_index],
        reference = reference,
        region = regions[region_index],
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
      entity_name = name,
      reference_name = reference.name,
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
    entity_name: { help: "Name of sample (if singleton) or group (if set of samples)." }
    svsigs: { help: "SV signature files to be used for calling SVs." }
    reference: { help: "Dictionary describing reference genome containing 'name': STR, 'dataFile': STR, and 'indexFile': STR." }
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
    String entity_name
    Array[File] svsigs
    IndexedData reference
    String region

    String extra = "--hifi -m 20"
    String log_level = "INFO"
    String output_filename = "~{entity_name}.~{reference.name}.~{region}.pbsv.vcf"

    Int threads = 8
    String conda_image
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(svsigs, "GB") + size(reference.data, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    conda info
    pbsv call ~{extra} \
      --log-level ~{log_level} \
      --num-threads ~{threads} \
      ~{reference.data} \
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
    entity_name: { help: "Name of sample (if singleton) or group (if set of samples)." }
    reference_name: { help: "Name of the reference genome." }
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
    String entity_name
    String reference_name
    Array[File] input_vcfs
    Array[File] input_indexes

    String extra = "--allow-overlaps"
    String output_filename = "~{entity_name}.~{reference_name}.pbsv.vcf"

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
