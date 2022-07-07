version 1.0

import "common.wdl" as common

workflow read_sample_sheet {
  meta {
    description: "Get all movies and movie info for a sample."
  }

  parameter_meta {
    # inputs
    sample_sheet: { help: "TSV (.txt or .tsv) with single line header including columns: sample_name, cohort_name, movie_path"}
    sample_name: { help: "Name of the sample."}

    # outputs
    movie_paths: { description: "Array of movie paths." }
  }

  input {
    File sample_sheet
    String sample_name
  }

  call get_sample_sheet_values as get_movie_paths {
    input:
      sample_sheet = sample_sheet,
      condition_column = "sample_name",
      condition_value = sample_name,
      column_out = "movie_path",
  }

  output {
    Array[File] movie_paths = get_movie_paths.values
  }
}


task get_sample_sheet_values {
  meta {
    description: "Get column values from a sample sheet based on condition of a different column."
  }

  parameter_meta {
    # inputs
    sample_sheet: { help: "TSV (.txt or .tsv) with single line header including columns: sample_name, cohort_name, movie_path" }
    condition_column: { 
      help: "Column name to use as condition.",
      choices: ["sample_name", "cohort_name", "movie_path"] 
      }
    condition_value: { help: "Value to use as condition." }
    column_out: { help: "Column values to output." }

    # outputs
    values: { description: "Column values." }
  }

  input {
    File sample_sheet
    String condition_column
    String condition_value
    String column_out
  }
  
  Int threads = 1
  Int memory = 4 * threads
  Int disk_size = ceil(1.5 * size(sample_sheet, "GB")) + 10

  command {
    set -o pipefail
    
    python3 << CODE
    import pandas as pd

    df = pd.read_csv('~{sample_sheet}', sep='\t', header=0)
    for value in df[df['~{condition_column}']=='~{condition_value}']['~{column_out}']:
      print (value)
    CODE
  }

  output {
    Array[String] values = read_lines(stdout())
  }

  runtime {
    cpu: threads
    memory: "~{memory}GB"
    disks: "local-disk ~{disk_size} HDD"
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pandas:1.1.0"
  }
}

