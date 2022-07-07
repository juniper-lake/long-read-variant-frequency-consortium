version 1.0

workflow run_somalier {
  meta {
    description: "Extract informative sites from BAM and check for sample swaps with somalier."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bams: { help: "Array of aligned bam file." }
    bais: { help: "Array of aligned bam index." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    sites_vcf: { help: "List of known polymorphic sites provided by somalier." }

    # outputs
    groups: { description: "Multi-sample group relatedness." }
    html: { description: "Interactive plots." }
    pairs: { description: "Pairwise relatedness, concordance, etc." }
    samples: { description: "Sample variant statistics." }
    min_relatedness: { description: "The minimum pairwise relatedness among the bam files, to test for sample swaps." }
  }

  input {
    String sample_name
    Array[File] bams
    Array[File] bais
    String reference_name
    File reference_fasta
    File reference_index
    File sites_vcf
  }

  call somalier {
    input:
      sample_name = sample_name,
      bams = bams,
      bais = bais,
      reference_name = reference_name,
      reference_fasta = reference_fasta,
      reference_index = reference_index,
      sites_vcf = sites_vcf
  }

  output {
    File groups = somalier.groups
    File html = somalier.html
    File pairs = somalier.pairs
    File samples = somalier.samples
    Int min_relatedness = somalier.min_relatedness
  }
}


task somalier {
  meta {
    description: "Extract informative sites from BAM and check for sample swaps with somalier."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bams: { help: "Array of aligned bam file." }
    bais: { help: "Array of aligned bam index." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    sites_vcf: { help: "List of known polymorphic sites provided by somalier." }
    threads: { help: "Number of threads to be used." }

    # outputs
    groups: { description: "Multi-sample group relatedness." }
    html: { description: "Interactive plots." }
    pairs: { description: "Pairwise relatedness, concordance, etc." }
    samples: { description: "Sample variant statistics." }
    min_relatedness: { description: "The minimum pairwise relatedness among the bam files, to test for sample swaps." }
  }

  input {
    String sample_name
    Array[File] bams
    Array[File] bais
    String reference_name
    File reference_fasta
    File reference_index
    File sites_vcf
  }

  Int disk_size = ceil(1.5 * (size(bams, "GB") + size(reference_fasta, "GB"))) + 20
  Int threads = length(bams)
  Int memory = 2 * threads

  command<<<
    set -o pipefail
    
    # symlink bams and bais to a single folder so indexes can be found
    mkdir bams_and_bais
    for file in ~{sep=" " bams} ~{sep=" " bais}; do 
      ln -s "$(readlink -f $file)" bams_and_bais
    done

    # extract genotype-like information for a single-sample at selected sites 
    for bam in bams_and_bais/*.bam; do
      somalier extract \
        --fasta=~{reference_fasta} \
        --sites=~{sites_vcf} \
        --out-dir="$(basename "$bam" .~{reference_name}.bam)" \
        --sample-prefix="$(basename "$bam" .~{reference_name}.bam)" \
        "$bam" &
    done

    # calculate relatedness among samples from extracted, genotype-like information
    somalier relate \
      --min-depth=4 \
      --output-prefix=~{sample_name}.somalier \
      ./*/*.somalier
    
    # get minimum pairwise relatedness
    awk 'NR>1 {print $3}' ~{sample_name}.somalier.pairs.tsv | sort -n | head -1 > min_relatedness.txt
  >>>

  output {
    File groups = "~{sample_name}.somalier.groups.tsv"
    File html = "~{sample_name}.somalier.html"
    File pairs = "~{sample_name}.somalier.pairs.tsv"
    File samples = "~{sample_name}.somalier.samples.tsv"
    Int min_relatedness = read_int("min_relatedness.txt")
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} SSD"
    maxRetries: 3
    preemptible: 1
    docker: "brentp/somalier:v0.2.15"
  }
}
