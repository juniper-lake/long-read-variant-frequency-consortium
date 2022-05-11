version 1.0

struct IndexedData {
  String name
  File data
  File index
}

struct MovieInfo {
  String name
  File path
  Boolean is_ubam
}

struct SampleInfo {
  String name
  Array[MovieInfo] movies
}

struct CohortInfo {
  String name
  Array[SampleInfo] samples
}