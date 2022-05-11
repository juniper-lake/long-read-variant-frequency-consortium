version 1.0

import "structs.wdl"

task get_reference{
  meta {
    description: "Builds a IndexedData object from reference name, fasta, and index."
  }

  parameter_meta {
    # inputs
    reference_name: "Name of the reference."
    reference_fasta: "Reference genome in FASTA format."
    reference_index: "Reference genome index in FAI (.fasta.fai) format."
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    reference: "A IndexedData object."
  }

  input {
    String reference_name
    File reference_fasta
    File reference_index
    String conda_image
  }
  command {
  }

  output {
    IndexedData reference = object {
      name: reference_name,
      data: reference_fasta,
      index: reference_index
    }
  }

  runtime {
    # cpu: threads
    # memory: "GB"
    # disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}