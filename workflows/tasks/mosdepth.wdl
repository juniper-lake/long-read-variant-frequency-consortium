version 1.0

workflow run_mosdepth {
  meta {
    description: "Calculate coverage for a bam."
  }

  parameter_meta {
    # inputs
    bam: { help: "Aligned BAM file." }
    bai: { help: "BAM index file." }

    # outputs
    global_dist: { description: "Text file containing cumulative distribution indicating the proportion of total bases covered for at least a given coverage value." }
    summary: { description: "Text file containing summary of mean depths per chromosome and within specified regions per chromosome." }
    total_coverage: { description: "Mean coverage of entire genome." }
  }

  input {
    File bam
    File bai
  }

  # calculate coverage
  call mosdepth {
    input:
      bam = bam,
      bai = bai
  }

  output {
    File global_dist = mosdepth.global_dist
    File summary = mosdepth.summary
    Float total_coverage = mosdepth.total_coverage
  }
}


task mosdepth {
  meta {
    description: "Calculate depth-of-coverage for bam file."
  }

  parameter_meta {
    # inputs
    bam: { help: "BAM file of aligned reads." }
    bai: { help: "BAM index file." }
    threads: { help: "Number of threads to be used." }

    # outputs
    global_dist: { description: "Text file containing cumulative distribution indicating the proportion of total bases covered for at least a given coverage value." }
    summary: { description: "Text file containing summary of mean depths per chromosome and within specified regions per chromosome." }
    total_coverage: { description: "Mean coverage of entire genome as float." }
  }

  input {
    File bam
    File bai
    Int threads = 4
  }

  String output_prefix = basename(bam, ".bam")
  Int memory = 4 * threads
  Int disk_size = ceil(2 * (size(bam, "GB") + size(bai, "GB"))) + 20

  command <<<
    set -o pipefail
    mosdepth --threads ~{threads} "--no-per-base" ~{output_prefix} ~{bam}
    awk '$1=="total" { print $4 }' ~{output_prefix}.mosdepth.summary.txt > mean_coverage.txt
  >>>

  output {
    File global_dist = "~{output_prefix}.mosdepth.global.dist.txt"
    File summary = "~{output_prefix}.mosdepth.summary.txt"
    Float total_coverage = read_float("mean_coverage.txt")
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/mosdepth:0.2.9"
  }
}
