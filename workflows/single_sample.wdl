version 1.0

import "tasks/sample_sheet.wdl" as sample_sheet
import "tasks/pbmm2.wdl" as pbmm2
import "tasks/pbsv.wdl" as pbsv
import "tasks/deepvariant.wdl" as deepvariant
import "tasks/minimap2.wdl" as minimap2
import "tasks/common.wdl" as common
import "tasks/svim.wdl" as svim
import "tasks/sniffles.wdl" as sniffles
import "tasks/cutesv.wdl" as cutesv


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
        bams = run_pbmm2.bam,
        bais = run_pbmm2.bai,
        tr_bed = tr_bed,
        regions = regions,
        conda_image = conda_image
  }

  # run deepvariant
  call deepvariant.run_deepvariant {
      input: 
        sample_name = sample_name,
        bams = run_pbmm2.bam,
        bais = run_pbmm2.bai,
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        deepvariant_image = deepvariant_image
  }

  # if movie is uBAM, convert to fasta; if not, do nothing
  scatter (idx in range(length(get_sample_movies.movie_paths))) {
    if (get_sample_movies.is_ubams[idx]) {
      call common.ubam_to_fasta {
        input:
        movie = get_sample_movies.movie_paths[idx],
        movie_name = get_sample_movies.movie_names[idx],
        conda_image = conda_image
      }
    }  
    if (!get_sample_movies.is_ubams[idx]) {
      call common.do_nothing {
        input:
          input_file = get_sample_movies.movie_paths[idx],
          conda_image = conda_image
      }
    }
  }

  # run minimap2
  call minimap2.run_minimap2 {
    input:
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      movies = flatten([select_all(ubam_to_fasta.fasta), select_all(do_nothing.output_file)]),
      prefix = sample_name,
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


  output {
    Array[File] bams = run_pbmm2.bam
    Array[File] bais = run_pbmm2.bai
    File pbsv_vcf = run_pbsv.pbsv_vcf
    Array[File] pbsv_region_vcfs = run_pbsv.pbsv_region_vcfs
    Array[File] pbsv_region_indexes = run_pbsv.pbsv_region_indexes
    File deepvariant_vcf = run_deepvariant.vcf
    File minimap2_bam = run_minimap2.bam
    File minimap2_index = run_minimap2.bai
    File svim_vcf = run_svim.vcf
    File sniffles_vcf = run_sniffles.vcf
    File cutesv_vcf = run_cutesv.vcf
  }
}
