version 1.0

workflow run_pbsv_discover {
  meta {
    description: "Discovers SV signatures from multiple aligned BAMs for all specified regions with pbsv."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    regions: { help: "Array of regions of the genome to search for SV signatures, e.g. chr1." }
    bams: { help: "Array of aligned BAM files." }
    bais: { help: "Array of bam BAI indexes."}
    tr_bed: { help: "BED file containing known tandem repeats." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

    # outputs
    svsigs: { description: "SV signature files for all regions." }
  }

  input {
    String sample_name
    Array[String] regions
    Array[File] bams
    Array[File] bais
    File tr_bed
    String conda_image
  }

  # for each aligned BAM, call SV signatures
  scatter (idx in range(length(regions))) {
    call pbsv_discover_by_region {
      input:
        sample_name = sample_name,
        region = regions[idx],
        bams = bams,
        bais = bais,
        tr_bed = tr_bed,
        conda_image = conda_image
    }
  }

  output {
    Array[File] svsigs = pbsv_discover_by_region.svsig
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
    output_filename: { help: "Name of the output svsig file." }
    threads: { help: "Number of threads to be used." }
    conda_image: { help: "Docker image with necessary conda environments installed." }

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
    String conda_image
    }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(bams, "GB"))) + 20

  command<<<
    set -o pipefail
    source ~/.bashrc
    conda activate pbsv
    
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
    docker: conda_image
  }
}
