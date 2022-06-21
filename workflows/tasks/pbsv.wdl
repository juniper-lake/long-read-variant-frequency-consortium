version 1.0

import "common.wdl" as common

workflow run_pbsv {
  meta {
    description: "Discovers SV signatures and calls SVs."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    regions: { help: "Array of regions of the genome to search for SV signatures, e.g. chr1." }
    bams: { help: "Array of aligned BAM files." }
    bais: { help: "Array of bam BAI indexes."}
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats." }

    # outputs
    svsigs: { description: "SV signature files for all regions." }
  }

  input {
    String sample_name
    Array[String] regions
    Array[File] bams
    Array[File] bais
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
  }

  scatter (idx in range(length(regions))) {
    # for each region, discover SV signatures
    call pbsv_discover_by_region {
      input:
        sample_name = sample_name,
        region = regions[idx],
        bams = bams,
        bais = bais,
        tr_bed = tr_bed,
    }
    
    # for each region, call SVs
    call pbsv_call_by_region {
      input:
        sample_name = sample_name,
        svsigs = [pbsv_discover_by_region.svsig],
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        region = regions[idx],
    }
    
    # zip and index region-specific VCFs
    call common.zip_and_index_vcf {
      input: 
        input_vcf = pbsv_call_by_region.vcf,
    }
  }

  # concatenate all region-specific VCFs into a single genome-wide VCF
  call concat_pbsv_vcfs {
    input: 
      sample_name = sample_name,
      reference_name = reference_name,
      input_vcfs = zip_and_index_vcf.vcf,
      input_indexes = zip_and_index_vcf.index,
  }

  # gzip and index the genome-wide VCF
  call common.zip_and_index_vcf as zip_and_index_final_vcf {
    input: 
      input_vcf = concat_pbsv_vcfs.vcf,
  }

  output {
    Array[File] svsigs = pbsv_discover_by_region.svsig
    File vcf = zip_and_index_final_vcf.vcf
    File index = zip_and_index_final_vcf.index
    Array[File] region_vcfs = zip_and_index_vcf.vcf
    Array[File] region_indexes = zip_and_index_vcf.index
  }
}


task pbsv_discover_by_region {
  meta {
    description: "Discovers SV signatures for a given region from multiple BAMs."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    region: { help: "Region of the genome to search for SV signatures, e.g. chr1." }
    bams: { help: "Array of aligned BAM file." }
    bais: { help: "Array of aligned BAM index (BAI) file." }
    tr_bed: { help: "BED file containing known tandem repeats." }
    svsig_filename: { help: "Filename for the SV signature file." }
    extra: { help: "Extra parameters to pass to pbsv." }
    log_level: { help: "Log level of pbsv." }
    threads: { help: "Number of threads to be used." }

    # outputs
    svsig: { description: "SV signature file to be used for calling SVs." }
  }

  input {
    String sample_name
    String region
    Array[File] bams
    Array[File] bais
    File tr_bed
    String svsig_filename = "~{sample_name}.~{region}.svsig.gz"
    String extra = "--hifi"
    String log_level = "INFO"
    Int threads = 4
    }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(bams, "GB"))) + 20

  command<<<
    set -o pipefail
    source ~/.bashrc
    
    # symlink bams and bais to a single folder so indexes can be found
    mkdir bams_and_bais
    for file in $(ls ~{sep=" " bams} ~{sep=" " bais}); do 
      ln -s $(readlink -f $file) bams_and_bais
    done
    
    # make XML dataset so all bams can be processed with one pbsv command
    dataset create --type AlignmentSet --novalidate --force ~{region}.xml bams_and_bais/*.bam

    pbsv discover ~{extra} \
      --log-level ~{log_level} \
      --region ~{region} \
      --tandem-repeats ~{tr_bed} \
      ~{region}.xml \
      ~{svsig_filename}
    >>>

  output {
    File svsig = svsig_filename
  }

  runtime {
    cpu: threads
    memory: "16GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pbsv:2.8"
  }
}


task pbsv_call_by_region {
  meta {
    description: "Calls SVs for a given region from SV signatures in single samples or jointly call in sample set."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of sample (if singleton) or group (if set of samples)." }
    svsigs: { help: "SV signature files for region specified to be used for calling SVs." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    region: { help: "Region of the genome to call structural variants, e.g. chr1." }
    extra: { help: "Extra parameters to pass to pbsv." }
    log_level: { help: "Log level." }
    output_filename: { help: "Name of the output VCF file." }
    threads: { help: "Number of threads to be used." }

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
  }

  Int disk_size = 200

  command<<<
    set -o pipefail
    source ~/.bashrc

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
    memory: "48GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pbsv:2.8"
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
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(input_vcfs, "GB") + size(input_indexes, "GB"))) + 20

  command {
    set -o pipefail
    source ~/.bashrc
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
    docker: "juniperlake/bcftools:1.14"
  }
}
