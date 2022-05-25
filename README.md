# Long Read Variant Frequency Consortium

**UNDER ACTIVE DEVELOPMENT**

Sample-, batch-, and cohort-level workflows to create long read variant frequency callsets.

## Workflow Details

### 1. Call Variants (single sample)

This top-level workflow aligns reads, assembles reads, and calls variants from a single sample using the following tools.

- [pbmm2](https://github.com/PacificBiosciences/pbmm2)
  - [pbsv](https://github.com/PacificBiosciences/pbsv)
  - [DeepVariant](https://github.com/google/deepvariant)
- [minimap2](https://github.com/lh3/minimap2)
  - [cuteSV](https://github.com/tjiangHIT/cuteSV)
  - [Sniffles2](https://github.com/fritzsedlazeck/Sniffles)
  - [SVIM](https://github.com/eldariont/svim)
- [hifiasm](https://github.com/chhylp123/hifiasm)
  - [PAV](https://github.com/EichlerLab/pav)

#### Inputs

```text
{
    "sample_name": "HG002",
    "hifi_reads": ["movie1.ccs.bam", "movie2.fastq.gz", ...],
    "reference_name": "GRCh38_no_alt", 
    "reference_fasta": "human_GRCh38_no_alt_analysis_set.fasta", 
    "reference_index": "human_GRCh38_no_alt_analysis_set.fasta.fai",
    "regions": [ "chr1", "chr2", "chr3", "chr4", "chr5", "chr6", "chr7", "chr8", "chr9", "chr10", "chr11", "chr12", "chr13", "chr14", "chr15", "chr16", "chr17", "chr18", "chr19", "chr20", "chr21", "chr22", "chrX", "chrY", "chrM" ],
    "tr_bed": "human_GRCh38_no_alt_analysis_set.trf.bed",
    "conda_image": "juniperlake/lrvfc_testing:latest",
    "deepvariant_image": "google/deepvariant:pichuan-cl445842347-10"
}
```

#### Outputs

- Indexed BAMs from **pbmm2** and **minimap2**
- Indexed VCFs from **cuteSV**, **DeepVariant**, **PAV**, **pbsv**, **Sniffles2**, and **SVIM**
- SVSIG files from **pbsv** for each region specified in `regions` input (can be used for joint calling)
- Gzipped hap1 and hap2 FASTAs from **hifiasm**

### 2. Variant Merging