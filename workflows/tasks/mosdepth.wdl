version 1.0

workflow run_mosdepth {
  meta {
    description: "Calculate coverage for each bam in array and sum."
  }

  parameter_meta {
    # inputs
    bams: { help: "Array of aligned BAM files." }
    bais: { help: "Array of BAM index files." }

    # outputs
    global_dists: { description: "Text files containing cumulative distribution indicating the proportion of total bases covered for at least a given coverage value." }
    summaries: { description: "Text files containing summary of mean depths per chromosome and within specified regions per chromosome." }
    coverages: { description: "Mean coverages of each bam file. "}
    total_coverage: { description: "Mean coverage of entire genome." }
  }

  input {
    Array[File] bams
    Array[File] bais
  }

  scatter (idx in range(length(bams))) { 
    # for each bam, calculate coverage
    call mosdepth {
      input:
        bam = bams[idx],
        bai = bais[idx],
    }
  }

  # sum coverages from each individual bam
  call sum_floats {
    input: 
      floats = mosdepth.coverage
  }

  output {
    Array[File] global_dists = mosdepth.global_dist
    Array[File] summaries = mosdepth.summary
    Array[Float] coverages = mosdepth.coverage
    Float total_coverage = sum_floats.sum
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
    output_prefix: { help: "Prefix for output files." }

    # outputs
    global_dist: { description: "Text file containing cumulative distribution indicating the proportion of total bases covered for at least a given coverage value." }
    summary: { description: "Text file containing summary of mean depths per chromosome and within specified regions per chromosome." }
    coverage: { description: "Mean coverage of entire genome as float." }
  }

  input {
    File bam
    File bai
    String output_prefix = basename(bam, ".bam")
    Int threads = 4
  }

  command <<<
    set -o pipefail
    mosdepth --threads ~{threads} "--no-per-base" ~{output_prefix} ~{bam}
    awk '$1=="total_region" { print $4 }' ~{output_prefix}.mosdepth.summary.txt > mean_coverage.txt
  >>>

  output {
    File global_dist = "~{output_prefix}.mosdepth.global.dist.txt"
    File summary = "~{output_prefix}.mosdepth.summary.txt"
    Float coverage = read_float("mean_coverage.txt")
  }

  runtime {
    cpu: threads
    memory: "16GB"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/mosdepth:0.2.9"
  }
}


task sum_floats {
  meta {
    description: "Sum floats in an array of floats."
  }
  
  parameter_meta {
    # inputs
    floats: { help: "An array of floats." }

    # outputs
    sum: {description: "The sum of all numbers in input array."}
  }

  input {
    Array[Float] floats
  }

  command <<<
    awk 'BEGIN{ print ~{sep="+" floats} }'
  >>>

  output {
    Float sum = read_float(stdout())
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:20.04"
  }
}
