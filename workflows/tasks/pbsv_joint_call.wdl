version 1.0

import "common.wdl" as common
import "pbsv.wdl" as pbsv


workflow run_pbsv_joint_call {
  meta { 
    description: "Calls SVs from nested array of SVSIGs for joint analysis."
  }
  
  parameter_meta {
    # inputs
    sample_name: { help: "Name of sample or sample set." }
    svsigs: { help: "Nested array of SV signature files in same order as regions array." }
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
    Array[Array[File]] svsigs
    Array[String] regions
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
    String conda_image
  }
    
  scatter (idx in range(length(regions))) {
    # call variants by region
    call pbsv.pbsv_call_by_region {
      input: 
        sample_name = sample_name,
        svsigs = svsigs[idx],
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
  call pbsv.concat_pbsv_vcfs {
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


