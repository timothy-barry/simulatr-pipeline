// The optional parameters
params.result_dir = "."
params.result_file_name = "simulatr_result.rds"
params.B = 0
params.B_check = 5
params.max_gb = 8
params.max_hours = 4

// First, obtain basic info, including method names and grid IDs
process obtain_basic_info {
  memory '2GB'
  time '15m'

  output:
  path "method_names.txt" into method_names_raw_ch
  path "grid_rows.txt" into grid_rows_raw_ch
  
  """
  get_info_for_nextflow.R $params.simulatr_specifier_fp
  """
}

method_names_ch = method_names_raw_ch.splitText().map{it.trim()}
grid_rows_ch = grid_rows_raw_ch.splitText().map{it.trim()}
method_cross_grid_row_ch = method_names_ch.combine(grid_rows_ch)

// Second, benchmark time and memory for each method on each grid row
process run_benchmark {
  memory '4GB'
  time '2h'
  
  tag "method: $method; grid row: $grid_row"

  input:
  tuple val(method), val(grid_row) from method_cross_grid_row_ch

  output:
  path 'proc_id_info.csv' into proc_id_info_ch
  path 'benchmarking_info.rds' into benchmarking_info_ch

  """
  run_benchmark.R $params.simulatr_specifier_fp $method $grid_row $params.B_check $params.B $params.max_gb $params.max_hours
  """
}

// Third, run each chunk of the simulation (apply a method to some number of realizations from a grid row)
process run_simulation_chunk {
  memory "$params.max_gb GB"
  time "$params.max_hours h"

  tag "method: $method; grid row: $grid_row; processor: $proc_id"

  input:
  tuple val(method), val(grid_row), val(proc_id), val(n_processors) from proc_id_info_ch.splitCsv()

  output:
  path 'chunk_result.rds' into results_ch

  """
  run_simulation_chunk.R $params.simulatr_specifier_fp $method $grid_row $proc_id $n_processors $params.B
  """
}

// Fourth, collect the results and evaluate metrics
process evaluate_methods {
  memory '12GB'
  time '15m'

  publishDir params.result_dir, mode: "copy"

  input:
  path 'chunk_result' from results_ch.collect()
  path 'benchmarking_info' from benchmarking_info_ch.collect()

  output:
  path "$params.result_file_name" into final_results_ch

  """
  run_evaluation.R $params.simulatr_specifier_fp $params.result_file_name chunk_result* benchmarking_info*
  """
}