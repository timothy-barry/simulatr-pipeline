// The optional parameters
params.result_name_file_name = "simulatr_result.rds"
params.B = 0

println params.simulatr_specifier_fp

// First, obtain basic info, including method names and grid IDs
process obtain_basic_info {
  input:
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  path "method_names.txt" into method_names_raw_ch
  path "grid_ids.txt" into grid_ids_raw_ch

  """
  get_info_for_nextflow.R $simulatr_specifier_fp
  """
}
method_names_ch = method_names_raw_ch.splitText().map{it.trim()}
grid_ids_ch = grid_ids_raw_ch.splitText().splitText().map{it.trim()}

// Second, generate the data across different processors
process generate_data {
  input:
  val i from grid_ids_ch
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  tuple val(i), path('data_list_*') into data_ch

  """
  generate_data.R $simulatr_specifier_fp $i $params.B
  """
}


// Third, create the channel to pass to the methods process
def my_spread(l) {
  key = l[0]
  vals = l[1]
  return vals.collect {[ key, it ]}
}
flat_data_ch = data_ch.flatMap{my_spread(it)}
method_cross_data_ch = flat_data_ch.combine(method_names_ch)


// Fourth, run invoke the methods on the data
process run_method {
  input:
  tuple val(grid_row), path('data_list.rds'), val(method) from method_cross_data_ch
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  file 'raw_result.rds' into raw_results_ch

  """
  run_method.R $simulatr_specifier_fp data_list.rds $method $params.B
  """
}


// Fifth combine results
process combine_results {
  publishDir params.result_dir, mode: "copy"

  output:
  file "$params.result_file_name" into collected_results_ch
  val "flag" into flag_ch

  input:
  file 'raw_result' from raw_results_ch.collect()

  """
  collect_results.R $params.result_file_name raw_result*
  """
}


/*
// Fifth, delete the data lists
process delete_work_files {
  echo true

  input:
  val "flag" from flag_ch

  """
  find $workflow.workDir -name "data_list_*" -delete
  """
}
*/
