version 1.0

import "tasks/structs.wdl"
import "tasks/pbmm2.wdl" as pbmm2
import "tasks/pbsv.wdl" as pbsv

workflow do_all_the_things {
  input {
    SampleInfo sample
    IndexedData reference
    File tr_bed
    Array[String] regions
    String conda_image
  }

  # align all hifi reads associated with sample to reference
  scatter (smrtcell in sample.smrtcells) { 
    call pbmm2.align_ubam_or_fastq {
        input: 
          reference = reference,
          smrtcell = smrtcell,
          sample_name = sample.name,
          conda_image = conda_image
    }
  }

  # run pbsv on single sample
  call pbsv.run_pbsv {
      input: 
        name = sample.name,
        reference = reference,
        aligned_bams = align_ubam_or_fastq.aligned_bam,
        tr_bed = tr_bed,
        regions = regions,
        conda_image = conda_image
  }

  output {
    Array[IndexedData] aligned_bams = align_ubam_or_fastq.aligned_bam
    Array[Array[File]] svsigs = run_pbsv.svsigs
    File pbsv_vcf = run_pbsv.pbsv_vcf
    Array[File] pbsv_region_vcfs = run_pbsv.pbsv_region_vcfs
    Array[File] pbsv_region_indexes = run_pbsv.pbsv_region_indexes
  }


}