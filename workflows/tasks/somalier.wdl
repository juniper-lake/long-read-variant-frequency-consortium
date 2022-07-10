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

  scatter (idx in range(length(bams))) {
    # extract genotypes at known sites
    call somalier_extract {
      input: 
        sample_name = sample_name,
        bam = bams[idx],
        bai = bais[idx],
        reference_name = reference_name,
        reference_fasta = reference_fasta,
        reference_index = reference_index,
        sites_vcf = sites_vcf
    }
  }

  call somalier_relate {
    input:
      sample_name = sample_name,
      somalier_files = somalier_extract.somalier
  }

  output {
    File groups = somalier_relate.groups
    File html = somalier_relate.html
    File pairs = somalier_relate.pairs
    File samples = somalier_relate.samples
    Float min_relatedness = somalier_relate.min_relatedness
    Int inferred_sex = somalier_relate.inferred_sex
  }
}

task somalier_extract {
  meta {
    description: "Extract informative sites from BAM."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    bam: { help: "Aligned bam file." }
    bai: { help: "Aligned bam index." }
    reference_name: { help: "Name of the the reference genome, used for file labeling." }
    reference_fasta: { help: "Path to the reference genome FASTA file." }
    reference_index: { help: "Path to the reference genome FAI index file." }
    sites_vcf: { help: "List of known polymorphic sites provided by somalier." }

    # outputs
    somalier: { description: "Somalier file containing extract read information at known sites." }
  }

  input {
    String sample_name
    File bam
    File bai
    String reference_name
    File reference_fasta
    File reference_index
    File sites_vcf
  }

  String movie_name = basename(bam, ".~{reference_name}.bam")
  Int disk_size = ceil(1.5 * (size(bam, "GB") + size(reference_fasta, "GB"))) + 10
  Int threads = 1
  Int memory = 4 * threads

  command<<<
    set -o pipefail
    
    # symlink bam and bai to same location so they can be found together
    ln -s "$(readlink -f "~{bam}")" .
    ln -s "$(readlink -f "~{bai}")" .

    # extract genotype-like information for a single-sample at selected sites 
    somalier extract \
      --fasta=~{reference_fasta} \
      --sites=~{sites_vcf} \
      --out-dir=~{movie_name} \
      --sample-prefix=~{movie_name} \
      ~{bam}
  >>>

  output {
    File somalier = "~{movie_name}/~{sample_name}.somalier"
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

task somalier_relate {
  meta {
    description: "Calculate relatedness to detect sample swaps with somalier."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    somalier_files: { help: "Array of somalier files produce by the extract function." }

    # outputs
    groups: { description: "Multi-sample group relatedness." }
    html: { description: "Interactive plots." }
    pairs: { description: "Pairwise relatedness, concordance, etc." }
    samples: { description: "Sample variant statistics." }
    min_relatedness: { description: "The minimum pairwise relatedness among the bam files, to test for sample swaps." }
    inferred_sex: { description: "1 is male, 2 is female." }
  }

  input {
    String sample_name
    Array[File] somalier_files
  }

  Int disk_size = 20
  Int threads = 1
  Int memory = 4 * threads

  command<<<
    set -o pipefail

    # calculate relatedness among samples from extracted, genotype-like information
    somalier relate \
      --min-depth=4 \
      --infer \
      --output-prefix=~{sample_name}.somalier \
      ~{sep=" " somalier_files}
    
    # get minimum pairwise relatedness
    awk 'NR>1 {print $3}' ~{sample_name}.somalier.pairs.tsv | sort -n | head -1 > min_relatedness.txt
    # get inferred sex
    LOW=$(awk 'NR>1 {print $5}' ~{sample_name}.somalier.samples.tsv | sort -n | head -1)
    HIGH=$(awk 'NR>1 {print $5}' ~{sample_name}.somalier.samples.tsv | sort -n | tail -1)
    if [ $HIGH -eq $LOW ]; then
      if [ $HIGH -eq 1 ]; then
        echo "M" > inferred_sex.txt
      elif [ $HIGH -eq 2 ]; then
        echo "F" > inferred_sex.txt
      fi
    else
      echo "U" > inferred_sex.txt
    fi
  >>>

  output {
    File groups = "~{sample_name}.somalier.groups.tsv"
    File html = "~{sample_name}.somalier.html"
    File pairs = "~{sample_name}.somalier.pairs.tsv"
    File samples = "~{sample_name}.somalier.samples.tsv"
    Float min_relatedness = read_float("min_relatedness.txt")
    String inferred_sex = read_string("inferred_sex.txt")
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
