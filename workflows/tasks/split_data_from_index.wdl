version 1.0

import "structs.wdl"


workflow split_data_from_index_array {
  meta {
    description: "Splits IndexedData objects into data and index for all items in an array."
  }

  parameter_meta {
    # inputs
    indexed_data_array: { help: "The array of IndexedData objects to split." }

    # outputs
    data_files: { description: "Array of data files." }
    index_files: { description: "Array of index files." }
  }
  
  input {
    Array[IndexedData] indexed_data_array
  }

  # for each IndexedData object in array, split data and index files
  scatter (indexed_data in indexed_data_array) {
    call split_data_from_index {
      input:
        indexed_data = indexed_data
    }
  }

  output {
    Array[File] data_files = split_data_from_index.data
    Array[File] index_files = split_data_from_index.index
  }
}


task split_data_from_index {
  meta {
    description: "This task will split the data and index files from an IndexedData object."
  }

  parameter_meta {
    # inputs
    indexedData: { help: "IndexedData object to split." }

    # outputs
    data: { description: "Data file." }
    index: { description: "Index file." }
  }

  input {
    IndexedData indexed_data
  }

  command {
  }

  output {
    File data = indexedData.data
    File index = indexedData.index
  }

  runtime {
    docker: "ubuntu:latest"
    preemptible: 1
    maxRetries: 3
  }
}


