version 1.0

import "structs.wdl"

task split_data_from_index {
  meta {
    description: "This task will split the data and index files from an IndexedData object."
  }

  parameter_meta {
    indexedData: "IndexedData object to split."
    threads: "Number of threads to use."
  }

  input {
    IndexedData indexedData

    Int threads = 1
    String conda_image
  }

  command {
  }

  output {
    File dataFile = indexedData.dataFile
    File indexFile = indexedData.indexFile
  }

  runtime {
    docker: conda_image
    preemptible: 1
    maxRetries: 3
    memory: "4GB"
    cpu: threads
  }
}


workflow split_data_from_index_array {
  input {
    Array[IndexedData] indexedDataArray
  }

  # for each IndexedData object in array, split data and index files
  scatter (indexedData in indexedDataArray) {
    call split_data_from_index {
      input:
        indexedData = indexedData
    }
  }

  output {
    Array[File] dataFiles = split_data_from_index.dataFile
    Array[File] indexFiles = split_data_from_index.indexFile
  }
}