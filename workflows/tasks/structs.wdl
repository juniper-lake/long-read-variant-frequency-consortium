version 1.0

struct IndexedData {
  String name
  File data
  File index
}

struct SmrtcellInfo {
  String name
  File path
  Boolean isUbam
}

struct SampleInfo {
  String name
  Array[SmrtcellInfo] smrtcells
}
