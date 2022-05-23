version 1.0

import "tasks/pbmm2.wdl" as pbmm2
import "tasks/pbsv_discover.wdl" as pbsv_discover
import "tasks/pbsv_call.wdl" as pbsv_call
import "tasks/deepvariant.wdl" as deepvariant
import "tasks/fasta.wdl" as fasta
import "tasks/minimap2.wdl" as minimap2
import "tasks/common.wdl" as common
import "tasks/svim.wdl" as svim
import "tasks/sniffles.wdl" as sniffles
import "tasks/cutesv.wdl" as cutesv
import "tasks/hifiasm.wdl" as hifiasm
import "tasks/pav.wdl" as pav


workflow call_variants_solo {
  meta { 
    description: "Align HiFi reads to reference genome and call variants for a single sample."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample, for file naming. "}
    hifi_reads: { help: "Array of HiFi reads in BAM or zipped/unzipped FASTQ/FASTA." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats for reference genome." }
    regions: { help: "Array of regions to call variants in, used for parallel processing of genome." }
    conda_image: { help: "Docker image with necessary conda environments installed." }
    deepvariant_image: { help: "Docker image for Google's DeepVariant (single-pass optimized)." }
  }

  input {
    String sample_name
    Array[File] hifi_reads
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
    Array[String] regions
    String conda_image
    String deepvariant_image
  }

  # align all hifi reads associated with sample to reference with pbmm2
  call pbmm2.run_pbmm2 {
    input: 
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      movies = hifi_reads,
      sample_name = sample_name,
      conda_image = conda_image
  }

  # run pbsv discover
  call pbsv_discover.run_pbsv_discover {
    input: 
      sample_name = sample_name,
      bams = run_pbmm2.bams,
      bais = run_pbmm2.bais,
      tr_bed = tr_bed,
      regions = regions,
      conda_image = conda_image
  }

  # run pbsv call
  call pbsv_call.run_pbsv_call {
    input: 
      sample_name = sample_name,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      svsigs = run_pbsv_discover.svsigs,
      svsigs_nested = [],
      tr_bed = tr_bed,
      regions = regions,
      conda_image = conda_image
  }

  # run deepvariant
  call deepvariant.run_deepvariant {
    input: 
      sample_name = sample_name,
      bams = run_pbmm2.bams,
      bais = run_pbmm2.bais,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      deepvariant_image = deepvariant_image
  }

  # if movies includes bams, convert to fasta
  call fasta.convert_to_fasta {
    input: 
      movies = hifi_reads,
      conda_image = conda_image
  }

  # run minimap2
  call minimap2.run_minimap2 {
    input:
      output_prefix = sample_name,
      movies = convert_to_fasta.fastas,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      conda_image = conda_image
  }

  # run svim on minimap2 alignments
  call svim.run_svim {
    input:
      sample_name = sample_name,
      bam = run_minimap2.bam,
      bai = run_minimap2.bai,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      reference_name = reference_name,
      conda_image = conda_image
  }

  # run sniffles on minimap2 alignment
  call sniffles.run_sniffles {
    input: 
      sample_name = sample_name,
      bam = run_minimap2.bam,
      bai = run_minimap2.bai,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      reference_name = reference_name,
      tr_bed = tr_bed,
      conda_image = conda_image
  }

  # run cutesv on minimap2 alignment
  call cutesv.run_cutesv {
    input: 
      sample_name = sample_name,
      bam = run_minimap2.bam,
      bai = run_minimap2.bai,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      reference_name = reference_name,
      conda_image = conda_image
  }
  
  # assemble reads into phased assemblies with hifiasm
  call hifiasm.run_hifiasm {
    input:
      sample_name = sample_name,
      movies = convert_to_fasta.fastas,
      conda_image = conda_image
  }

  # call variants from phased assemblies with pav
  call pav.run_pav {
    input: 
      sample_name = sample_name,
      hap1_fasta = run_hifiasm.hap1_fasta,
      hap2_fasta = run_hifiasm.hap2_fasta,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      conda_image = conda_image
  }

  output {
    Array[File] pbmm2_bams = run_pbmm2.bams
    Array[File] pbmm2_bais = run_pbmm2.bais
    File pbsv_vcf = run_pbsv_call.pbsv_vcf
    Array[File] svsigs = run_pbsv_discover.svsigs
    File deepvariant_vcf = run_deepvariant.vcf
    File minimap2_bam = run_minimap2.bam
    File minimap2_bai = run_minimap2.bai
    File svim_vcf = run_svim.vcf
    File svim_index = run_svim.index
    File sniffles_vcf = run_sniffles.vcf
    File sniffles_index = run_sniffles.index
    File cutesv_vcf = run_cutesv.vcf
    File cutesv_index = run_cutesv.index
    File hap1_fasta = run_hifiasm.hap1_fasta
    File hap2_fasta = run_hifiasm.hap2_fasta
    File pav_vcf = run_pav.vcf
    File pav_index = run_pav.index
  }
}
