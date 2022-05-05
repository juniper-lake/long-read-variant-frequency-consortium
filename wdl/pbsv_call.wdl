version 1.0

import "structs.wdl"
import "pbsv_discover.wdl" as pbsv_discover
import "common.wdl" as common


task pbsv_call_variants {
  input {
    String name
    Array[File] svsigs
    IndexedData reference
    String region

    String extra = "--hifi -m 20"
    String logLevel = "INFO"
    String outFilename = "~{name}.~{reference.name}.~{region}.pbsv.vcf"

    Int threads = 8
    String condaImage
  }

  Float multiplier = 3.25
  Int diskSize = ceil(multiplier * (size(svsigs, "GB") + size(reference.dataFile, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    conda info
    pbsv call ~{extra} \
      --log-level ~{logLevel} \
      --num-threads ~{threads} \
      ~{reference.dataFile} \
      ~{sep=" " svsigs} \
      ~{outFilename}
  }

  output {
    File vcf = outFilename
  }
  
  runtime {
    cpu: threads
    memory: "32GB"
    disks: "~{diskSize} GB"
    maxRetries: 3
    preemptible: 1
    docker: condaImage
  }

  meta {
    description: "This task will call SVs for a given region from SV signatures. It can be used to call SVs in single samples or jointly call in sample set."
    author: "Juniper Lake"
  }

  parameter_meta {
    # inputs
    name: "Name of sample (if singleton) or group (if set of samples)."
    svsigs: "SV signature files to be used for calling SVs"
    reference: "Dictionary describing reference genome containing 'name': STR, 'dataFile': STR, and 'indexFile': STR."
    region: "Region of the genome to call structural variants, e.g. chr1."
    extra: "Extra parameters to pass to pbsv."
    logLevel: "Log level."
    outFilename: "Name of the output VCF file."
    threads: "Number of threads to be used."
    condaImage: "Docker image with necessary conda environments installed."

    # outputs
    vcf: "VCF file containing the called SVs."
  }
}


task concat_pbsv_vcfs {
  input {
    String name
    String referenceName
    Array[File] inVcfs
    Array[File] indices

    String extra = "--allow-overlaps"
    String outFilename = "~{name}.~{referenceName}.pbsv.vcf"

    Int threads = 4
    String condaImage
  }

  Float multiplier = 3.25
  Int diskSize = ceil(multiplier * (size(inVcfs, "GB") + size(indices, "GB"))) + 20

  command {
    source ~/.bashrc
    conda activate bcftools
    conda info
    bcftools concat ~{extra} \
      --output ~{outFilename} \
      ~{sep=" " inVcfs} \
  }

  output {
    File vcf = outFilename
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "~{diskSize} GB"
    maxRetries: 3
    preemptible: 1
    docker: condaImage
  }

  meta {
    description: "This task will concatenate all the region-specific VCFs for a given sample or sample set into a single genome-wide VCF."
    author: "Juniper Lake"
  }

  parameter_meta {
    name: "Name of sample (if singleton) or group (if set of samples)."
    referenceName: "Name of the reference genome."
    inVcfs: "VCF files to be concatenated."
    indices: "Index files for VCFs."
    extra: "Extra parameters to pass to bcftools."
    outFilename: "Name of the output VCF file."
    threads: "Number of threads to be used."
    condaImage: "Docker image with necessary conda environments installed."
  }
}


workflow pbsv {
  # this workflow will discover SV signatures and call SVs in single samples or in a sample set (joint called).
  input {
    String name
    Array[IndexedData] alignedBams
    IndexedData reference
    File trBed
    Array[String] regions
    String condaImage
  }

  # for each region, discover SV signatures in all alignedBams
  scatter (region in regions) {
    call pbsv_discover.pbsv_discover_signatures_across_bams {
      input: 
        region = region,
        alignedBams = alignedBams,
        referenceName = reference.name,
        trBed = trBed,
        condaImage = condaImage
    }
  }
  
  # for each region, call SVs from svsig files for that region
  scatter (regionIndex in range(length(regions))) {
    call pbsv_call_variants {
      input: 
        name = name,
        svsigs = pbsv_discover_signatures_across_bams.svsigs[regionIndex],
        reference = reference,
        region = regions[regionIndex],
        condaImage = condaImage
    }    
  }

  # gzip and index each region-specific VCF
  scatter (vcf in pbsv_call_variants.vcf) {
    call common.zip_and_index_vcf {
      input: 
        inVcf = vcf,
        condaImage = condaImage
    }
  }

  # concatenate all region-specific VCFs into a single genome-wide VCF
  call concat_pbsv_vcfs {
    input: 
      name = name,
      referenceName = reference.name,
      inVcfs = zip_and_index_vcf.vcf,
      indices = zip_and_index_vcf.index,
      condaImage = condaImage
  }

  # gzip and index the genome-wide VCF
  call common.zip_and_index_vcf as zip_and_index_final_vcf {
    input: 
      inVcf = concat_pbsv_vcfs.vcf,
      condaImage = condaImage
  }

  output {
    # SV signature files for each region for each provided BAM
    Array[Array[File]] svsigs = pbsv_discover_signatures_across_bams.svsigs
    # genome-wide VCF with SVs called from all provided BAMs (singleton or joint)
    File pbsvVcf = zip_and_index_final_vcf.vcf
    # region-specific VCFs with SVs called from all provided BAMs (singleton or joint)
    Array[File] pbsvRegionVcfs = zip_and_index_vcf.vcf
    # region-specific VCF indices
    Array[File] pbsvRegionIndexes = zip_and_index_vcf.index
  }
}