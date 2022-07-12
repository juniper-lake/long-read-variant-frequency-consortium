version 1.0

import "tasks/cutesv.wdl" as cutesv
import "tasks/deepvariant.wdl" as deepvariant
import "tasks/fasta.wdl" as fasta
import "tasks/hifiasm.wdl" as hifiasm
import "tasks/jasmine.wdl" as jasmine
import "tasks/minimap2.wdl" as minimap2
import "tasks/mosdepth.wdl" as mosdepth
import "tasks/pav.wdl" as pav
import "tasks/pbmm2.wdl" as pbmm2
import "tasks/pbsv.wdl" as pbsv
import "tasks/sample_sheet.wdl" as sample_sheet
import "tasks/sniffles.wdl" as sniffles
import "tasks/somalier.wdl" as somalier
import "tasks/svim.wdl" as svim


workflow call_variants {
  meta { 
    description: "Align HiFi reads to reference genome and call variants for a single sample."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample, for file naming. "}
    sample_sheet: { help: "TSV (.txt or .tsv) with single line header including columns: sample_name, cohort_name, movie_path"}
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    tr_bed: { help: "BED file containing known tandem repeats for reference genome." }
    sites_vcf: { help: "List of known polymorphic sites provided by somalier." }
    regions: { help: "Array of regions to call variants in, used for parallel processing of genome." }
    min_relatedness_sample_swap: { help: "Minimum pairwise relatedness among all movies for sample to pass quality control." }
    min_coverage_assembly: { help: "Minimum average coverage across genome for reads to be assembled." }
  }

  input {
    String sample_name
    File sample_sheet
    String reference_name
    File reference_fasta
    File reference_index
    Array[String] regions
    File tr_bed
    File sites_vcf
    Float min_relatedness_sample_swap = 0.85
    Int min_coverage_assembly = 10
  }

  call sample_sheet.read_sample_sheet {
    input:
      sample_name = sample_name,
      sample_sheet = sample_sheet
  }

  # align all hifi reads associated with sample to reference with pbmm2
  call pbmm2.run_pbmm2 {
    input: 
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      movies = read_sample_sheet.movie_paths,
      sample_name = sample_name,
  }

  # check sample swaps
  call somalier.run_somalier {
    input:
      sample_name = sample_name,
      bams = run_pbmm2.bams,
      bais = run_pbmm2.bais,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      sites_vcf = sites_vcf
  }
  
  if (run_somalier.min_relatedness >= min_relatedness_sample_swap) {
    # run pbsv 
    call pbsv.run_pbsv {
      input: 
        sample_name = sample_name,
        bams = run_pbmm2.bams,
        bais = run_pbmm2.bais,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        tr_bed = tr_bed,
        regions = regions,
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
    }

    # if movies includes bams, convert to fasta
    call fasta.convert_to_fasta {
      input: 
        movies = read_sample_sheet.movie_paths,
    }

    # run minimap2
    call minimap2.run_minimap2 {
      input:
        sample_name = sample_name,
        movies = convert_to_fasta.fastxs,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
    }

    # check coverage
    call mosdepth.run_mosdepth {
      input:
        bam = run_minimap2.bam,
        bai = run_minimap2.bai,
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
    }
    

    if (run_mosdepth.total_coverage >= min_coverage_assembly) {
      # assemble reads into phased assemblies with hifiasm
      call hifiasm.run_hifiasm {
        input:
          sample_name = sample_name,
          movie_fastxs = convert_to_fasta.fastxs,
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
      }

      call jasmine.run_jasmine as merge_callers_with_pav {
        input:
          sample_name = sample_name,
          vcfs = [run_cutesv.vcf,run_pav.filtered_vcf,run_pbsv.vcf,run_sniffles.vcf,run_svim.vcf],
          bams = [run_minimap2.bam],
          bais = [run_minimap2.bai],
          reference_fasta = reference_fasta,
          reference_index = reference_index,
          reference_name = reference_name,
          merge_samples = false
      }
    }

    if (run_mosdepth.total_coverage < min_coverage_assembly) {
      call jasmine.run_jasmine as merge_callers_no_pav {
        input:
          sample_name = sample_name,
          vcfs = [run_cutesv.vcf,run_pbsv.vcf,run_sniffles.vcf,run_svim.vcf],
          bams = [run_minimap2.bam],
          bais = [run_minimap2.bai],
          reference_fasta = reference_fasta,
          reference_index = reference_index,
          reference_name = reference_name,
          merge_samples = false
      }
    }
  }

  output {
    Array[File] hifi_reads = read_sample_sheet.movie_paths
    Array[File] pbmm2_bams = run_pbmm2.bams
    Array[File] pbmm2_bais = run_pbmm2.bais
    File somalier_pairs = run_somalier.pairs
    Float somalier_min_relatedness = run_somalier.min_relatedness
    String somalier_inferred_sex = run_somalier.inferred_sex
    Float? mosdepth_total_coverage = run_mosdepth.total_coverage
    File? pbsv_vcf = run_pbsv.vcf
    File? deepvariant_vcf = run_deepvariant.vcf
    File? deepvariant_index = run_deepvariant.index
    File? minimap2_bam = run_minimap2.bam
    File? minimap2_bai = run_minimap2.bai
    File? svim_vcf = run_svim.vcf
    File? sniffles_vcf = run_sniffles.vcf
    File? cutesv_vcf = run_cutesv.vcf
    File? hifiasm_hap1_fasta = run_hifiasm.hap1_fasta
    File? hifiasm_hap2_fasta = run_hifiasm.hap2_fasta
    File? pav_filtered_vcf = run_pav.filtered_vcf
    File? pav_vcf = run_pav.unfiltered_vcf
    File? pav_index = run_pav.unfiltered_index
    File? jasmine_vcf = select_first([merge_callers_with_pav.vcf,merge_callers_no_pav.vcf])
  }
}
