// The optional parameters
params.result_file_name = "simulatr_result.rds"
params.B = 0
params.B_check = 5
params.max_gb = 8
params.max_hours = 4

// println params.simulatr_specifier_fp

// First, obtain basic info, including method names and grid IDs
process obtain_basic_info {
  memory '2GB'
  time '15m'

  input:
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  path "method_names.txt" into method_names_raw_ch
  path "grid_rows.txt" into grid_rows_raw_ch

  """
  get_info_for_nextflow.R $simulatr_specifier_fp
  """
}

method_names_raw_ch.splitText().map{it.trim()}.into{ method_names_benchmark_ch; method_names_ch }
grid_rows_raw_ch.splitText().map{it.trim()}.into{ grid_rows_benchmark_ch; grid_rows_ch }

process generate_data_benchmark {
  memory '4GB'
  time '1h'

  input:
  val grid_row from grid_rows_benchmark_ch
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  tuple val(grid_row), path('data_benchmark.rds') into data_benchmark_ch
  path 'data_benchmarking_info.rds' into data_req_raw_ch

  """
  generate_data_benchmark.R $simulatr_specifier_fp $grid_row $params.B_check
  """
}

data_req_ch = data_req_raw_ch.collect()
method_cross_data_benchmark_ch = data_benchmark_ch.transpose().combine(method_names_benchmark_ch)

process run_method_benchmark {
  memory '4GB'
  time '1h'

  tag "method: $method; grid row: $grid_row"

  input:
  tuple val(grid_row), path('data_benchmark.rds'), val(method) from method_cross_data_benchmark_ch
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  path 'method_benchmarking_info.rds' into method_req_raw_ch

  """
  run_method_benchmark.R $simulatr_specifier_fp data_benchmark.rds $method $params.B_check
  """
}

method_req_ch = method_req_raw_ch.collect()

process add_n_processors {
  memory '2GB'
  time '15m'

  publishDir params.result_dir, mode: "copy", pattern: '*_benchmarking.rds'

  input:
  path 'data_req' from data_req_ch
  path 'method_req' from method_req_ch
  val max_gb from params.max_gb
  val max_hours from params.max_hours
  path simulatr_specifier_fp from params.simulatr_specifier_fp

  output:
  path "new_simspec_obj.rds" into new_simspec_ch
  path "*_benchmarking.rds" into benchmarking_output_ch

  """
  add_n_processors.R data_req* method_req* $max_gb $max_hours $params.B $simulatr_specifier_fp
  """
}

// Second, generate the data across different processors
process generate_data {
  memory "$params.max_gb GB"
  time "$params.max_hours h"
  tag "grid row: $grid_row"

  input:
  val grid_row from grid_rows_ch
  path simulatr_specifier_fp from new_simspec_ch

  output:
  tuple val(grid_row), path('data_list_*') into data_ch

  """
  generate_data.R $simulatr_specifier_fp $i $params.B
  """
}

// Third, create the channel to pass to the methods process
method_cross_data_ch = data_ch.transpose().combine(method_names_ch)

// Fourth, run invoke the methods on the data
process run_method {
  memory "$params.max_gb GB"
  time "$params.max_hours h"

  tag "method: $method; grid row: $grid_row"

  input:
  tuple val(grid_row), path('data_list.rds'), val(method) from method_cross_data_ch
  path simulatr_specifier_fp from new_simspec_ch

  output:
  file 'raw_result.rds' into raw_results_ch

  """
  run_method.R $simulatr_specifier_fp data_list.rds $method $params.B
  """
}

// Fifth combine results
process combine_results {
  memory '2GB'
  time '15m'

  publishDir params.result_dir, mode: "copy"

  output:
  file "$params.result_file_name" into collected_results_ch

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
