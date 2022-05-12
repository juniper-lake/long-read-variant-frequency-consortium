version 1.0

import "structs.wdl"

task get_reference{
  meta {
    description: "Builds a IndexedData object from reference name, fasta, and index."
  }

  parameter_meta {
    # inputs
    reference_name: { help: "Name of the reference." }
    reference_fasta: { 
      help: "Reference genome in FASTA format.",
      patterns: ["*.fa", "*.fasta"] 
    }
    reference_index: { 
      help: "Reference genome index in FAI (.fasta.fai) format.",
      paterns: ["*.fa.fai", "*.fasta.fai"]
    }

    # outputs
    reference: "A IndexedData object."
  }

  input {
    String reference_name
    File reference_fasta
    File reference_index
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
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:latest"
  }
}