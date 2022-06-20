version 1.0

import "common.wdl" as common

workflow get_sample_movies {
  meta {
    description: "Get all movies and movie info for a sample."
  }

  parameter_meta {
    # inputs
    sample_sheet: { help: "TSV (.txt or .tsv) with single line header including columns: sample_name, cohort_name, movie_path"}
    sample_name: { help: "Name of the sample."}

    # outpus
    movie_paths: { description: "Array of movie paths." }
    movie_names: { description: "Array of movie names." }
    is_ubams: { description: "Array of strings indicating if the movie is a ubam." }
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
    maxRetries: 3
    preemptible: 1
    docker: "juniperlake/pandas:1.1.0"
  }
}

