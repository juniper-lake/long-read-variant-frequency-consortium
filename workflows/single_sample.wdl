version 1.0

import "tasks/sample_sheet.wdl" as sample_sheet
import "tasks/pbmm2.wdl" as pbmm2
import "tasks/pbsv.wdl" as pbsv
import "tasks/deepvariant.wdl" as deepvariant


workflow do_all_the_things {
  input {
    String sample_name
    File sample_sheet
    String reference_name
    File reference_fasta
    File reference_index
    File tr_bed
    Array[String] regions
    String conda_image
    String deepvariant_image
  }

  # get sample info, such as hifi reads files, from sample sheet
  call sample_sheet.get_sample_movies {
    input:
      sample_name = sample_name,
      sample_sheet = sample_sheet,
      conda_image = conda_image
  }

  # align all hifi reads associated with sample to reference with pbmm2
  scatter (idx in range(length(get_sample_movies.movie_paths))) { 
    call pbmm2.run_pbmm2 {
        input: 
          reference_name = reference_name,
          reference_fasta = reference_fasta,
          reference_index = reference_index,
          movie = get_sample_movies.movie_paths[idx],
          movie_name = get_sample_movies.movie_names[idx],
          sample_name = sample_name,
          conda_image = conda_image
    }
  }

  # run pbsv
  call pbsv.run_pbsv {
      input: 
        sample_name = sample_name,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        aligned_bams = run_pbmm2.aligned_bam,
        aligned_bam_indexes = run_pbmm2.aligned_bam_index,
        tr_bed = tr_bed,
        regions = regions,
        conda_image = conda_image
  }

  # run deepvariant
  call deepvariant.run_deepvariant {
      input: 
        sample_name = sample_name,
        aligned_bam_files = run_pbmm2.aligned_bam,
        aligned_bam_indexes = run_pbmm2.aligned_bam_index,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        deepvariant_image = deepvariant_image
  }

  output {
    Array[File] aligned_bam_files = run_pbmm2.aligned_bam
    Array[File] aligned_bam_indexes = run_pbmm2.aligned_bam_index
    File pbsv_vcf = run_pbsv.pbsv_vcf
    Array[File] pbsv_region_vcfs = run_pbsv.pbsv_region_vcfs
    Array[File] pbsv_region_indexes = run_pbsv.pbsv_region_indexes
    File deepvariant_vcf = run_deepvariant.vcf
  }
}
