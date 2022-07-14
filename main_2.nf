// nextflow.preview.recursion=true

// The optional parameters
params.result_name_file_name = "simulatr_result.rds"
params.B = 0
params.chunk_size = 2

// Define processes
// First, obtain basic info, including method names and grid IDs
process obtain_basic_info {
  input:
  path simulatr_specifier_fp
  path current_results_fp

  output:
  path "method_names.txt", emit: method_names_raw_ch
  path "grid_ids.txt", emit: grid_ids_raw_ch

  """
  get_info_for_nextflow.R $simulatr_specifier_fp $current_results_fp $params.chunk_size
  """
}


process generate_data {
  input:
  val i
  path simulatr_specifier_fp

  output:
  tuple val(i), path('data_list_*'), emit: data_ch

  """
  generate_data.R $simulatr_specifier_fp $i $params.B
  """
}


def my_spread(l) {
  key = l[0]
  vals = l[1]
  return vals.collect {[ key, it ]}
}


process run_method {
  input:
  tuple val(grid_row), path('data_list_'), val(method)
  path simulatr_specifier_fp

  output:
  path "raw_result.rds", emit: raw_results_ch

  """
  run_method.R $simulatr_specifier_fp data_list_ $method $params.B
  """
}


process combine_results {
  publishDir params.result_dir, mode: "copy"

  input:
  path current_results_fp
  path "raw_result"

  output:
  path "$params.result_file_name", emit: collected_results_ch
  val "flag", emit: flag_ch

  """
  collect_results.R $params.result_file_name $current_results_fp raw_result*
  """
}


// Sixth, delete the data lists
process delete_work_files {
  input:
  val "flag"

  """
  find $workflow.workDir -name "data_list_*" -delete
  """
}


workflow run_simulation_on_chunk {
  take:
    current_results

  main:
    // 1. Obtain the basic info
    obtain_basic_info(params.simulatr_specifier_fp, current_results)
    method_names_ch = obtain_basic_info.out.method_names_raw_ch.splitText().map{it.trim()}
    grid_ids_ch = obtain_basic_info.out.grid_ids_raw_ch.splitText().splitText().map{it.trim()}

    // 2. Generate data across different processors
    generate_data(grid_ids_ch, params.simulatr_specifier_fp)

    // 3. Create the channel to pass to the methods process
    method_cross_data_ch = generate_data.out.data_ch.transpose().combine(method_names_ch)


    // 4. Run the methods on the data
    run_method(method_cross_data_ch, params.simulatr_specifier_fp)

    // 5. Combine results
    combine_results(current_results, run_method.out.raw_results_ch.collect())

    // 6. Delete data lists to clear up disk space
    delete_work_files(combine_results.out.flag_ch)

  emit:
    combine_results.out.collected_results_ch
}


workflow {
  //run_simulation_on_chunk
  //.recurse(file("/Users/timbarry/simulatr_dir/results_sub.rds"))
  //.times(2)
  run_simulation_on_chunk(file("/Users/timbarry/simulatr_dir/null_file.rds"))
}
