version 1.0

import "structs.wdl"


workflow get_sample_movies {
  meta {
    description: "Finds all movies associated with a sample in the sample sheet."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    sample_sheet: { 
      help: "TSV (.txt or .tsv) with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam",
      patterns: ["*.txt", "*.tsv"]
    }

    # outputs
    movie_names: { description: "Array of movie names." }
    movie_paths: { description: "Array of movie paths." }
    is_ubam: { description: "Array of boolean values indicating if the movie is a ubam." }
  }

  input {
    String sample_name
    File sample_sheet
  }
  
  # turn sample sheet TSV into array of lines
  call get_lines {
    input: 
      sample_name = sample_name,
      sample_sheet = sample_sheet,
  }
  
  # turn each line into variables
  scatter (line in get_lines.lines) {
    call split_line {
      input:
        line = line,
    }        
  }

  output {
    Array[String] movie_names = split_line.movie_name
    Array[File] movie_paths = split_line.movie_path
    Array[Boolean] is_ubams = split_line.is_ubam
  }
}


task get_lines {
  meta {
    description: "Finds all movies associated with a sample in the sample sheet."
  }

  parameter_meta {
    # inputs
    sample_name: { help: "Name of the sample." }
    sample_sheet: { 
      help: "TSV (.txt or .tsv) with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam",
      patterns: ["*.txt", "*.tsv"]
    }

    # outputs
    lines: "Lines of the sample sheet associated with the sample."
  }

  input {
    String sample_name
    File sample_sheet
    }
  
  command {
    grep -E -v '^(\s*#|$)' ~{sample_sheet} \
      | awk ' $1=="~{sample_name}" ' \
    }

  output {
    Array[Array[String]] lines = read_tsv(stdout())
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:latest"
  }
}


task split_line {
  meta {
    description: "Converts a line from the sample sheet to variables."
  }

  parameter_meta {
    # inputs
    line: { help: "Line from the sample sheet." }

    # outputs
    movie_path: "Path to the movie."
    movie_name: "Name of the movie."
    is_ubam: "Whether the movie is a ubam or not."
  }

  input {
    Array[String] line
    }
  
  command {
    }

  output {
    String movie_path = line[2]
    String movie_name = line[3]
    Boolean is_ubam = if line[4]=="true" || line[4]=="TRUE" || line[4]=="True" then true else false
  }

  runtime {
    maxRetries: 3
    preemptible: 1
    docker: "ubuntu:latest"
  }
}


