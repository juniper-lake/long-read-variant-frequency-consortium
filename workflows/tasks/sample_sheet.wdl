version 1.0

import "structs.wdl"

task get_lines {
  meta {
    description: "This task finds all movies associated with a sample in the sample sheet."
  }

  parameter_meta {
    # inputs
    sample_name: "Name of the sample."
    sample_sheet: "TSV with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam"
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    lines: "Lines of the sample sheet associated with the sample."
  }

  input {
    String sample_name
    File sample_sheet
    String conda_image
    }
  
  command {
    grep -E -v '^(\s*#|$)' ~{sample_sheet} \
      | awk ' $1=="~{sample_name}" ' \
    }

  output {
    Array[Array[String]] lines = read_tsv(stdout())
  }

  runtime {
    # cpu: threads
    memory: "1GB"
    # disks: "~{disk_size} GB"
    maxRetries: 3
    preemptible: 1
    docker: conda_image
  }
}


task split_line {
  meta {
    description: "Converts a line from the sample sheet to variables."
  }

  parameter_meta {
    # inputs
    line: "Line from the sample sheet."
    conda_image: "Docker image with necessary conda environments installed."

    # outputs
    movie_path: "Path to the movie."
    movie_name: "Name of the movie."
    is_ubam: "Whether the movie is a ubam or not."
  }

  input {
    Array[String] line
    String conda_image
    }
  
  command {
    }

  output {
    String movie_path = line[2]
    String movie_name = line[3]
    Boolean is_ubam = if line[4]=="true" || line[4]=="TRUE" || line[4]=="True" then true else false
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


workflow get_sample_movies {
  meta {
    description: "Finds all movies associated with a sample in the sample sheet."
  }

  parameter_meta {
    sample_name: "Name of the sample."
    sample_sheet: "TSV with following columns (order matters), lines starting with # are ignored (e.g. header): [1] sample_name [2] cohort_name [3] movie_path [4] movie_name [5] is_ubam"
    conda_image: "Docker image with necessary conda environments installed."
  }

  input {
    String sample_name
    File sample_sheet
    String conda_image
  }
  
  # turn sample sheet TSV into array of lines
  call get_lines {
    input: 
      sample_name = sample_name,
      sample_sheet = sample_sheet,
      conda_image = conda_image
  }
  
  # turn each line into variables
  scatter (line in get_lines.lines) {
    call split_line {
      input:
        line = line,
        conda_image = conda_image
    }        
  }

  output {
    Array[String] movie_names = split_line.movie_name
    Array[File] movie_paths = split_line.movie_path
    Array[Boolean] is_ubams = split_line.is_ubam
  }
}
