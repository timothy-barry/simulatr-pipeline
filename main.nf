// Define parameters
params.result_dir = "."
params.result_file_name = "simulatr_result.rds"
params.B = 0
params.B_check = 5
params.max_gb = 8
params.max_hours = 4

// Define processes

process obtain_basic_info {
    tag "get_info"
    memory '2GB'
    time '15m'

    output:
    path "method_names.txt", emit: method_names_raw
    path "grid_rows.txt", emit: grid_rows_raw

    script:
    """
    get_info_for_nextflow.R $params.simulatr_specifier_fp
    """
}

process run_benchmark {
    tag "method: $method; grid row: $grid_row"
    errorStrategy 'retry'

    memory { 
        def mem = 12 * Math.pow(2, task.attempt - 1)
        return "${mem} GB"
    }

    time { 
        def hours = 8 * Math.pow(2, task.attempt - 1)
        return "${hours} h"
    }

    input:
    tuple val(method), val(grid_row)

    output:
    path "proc_id_info_${method}_${grid_row}.csv", emit: proc_id_info
    path "benchmarking_info_${method}_${grid_row}.rds", emit: benchmarking_info

    script:
    """
    run_benchmark.R $params.simulatr_specifier_fp $method $grid_row $params.B_check $params.B $params.max_gb $params.max_hours
    """
}

process run_simulation_chunk {
    tag "method: $method; grid row: $grid_row; processor: $proc_id"
    errorStrategy 'retry'
    maxRetries 6
    memory { 
        def mem = params.max_gb * Math.pow(2, task.attempt - 1)
        return "${mem} GB"
    }

    time { 
        def hours = params.max_hours * Math.pow(2, task.attempt - 1)
        return "${hours} h"
    }

    input:
    tuple val(method), val(grid_row), val(proc_id), val(n_processors)

    output:
    path "chunk_result_${method}_${grid_row}_${proc_id}.rds", emit: chunk_result

    script:
    """
    run_simulation_chunk.R $params.simulatr_specifier_fp $method $grid_row $proc_id $n_processors $params.B
    """
}

process evaluate_methods {
    tag "evaluate_methods"
    maxRetries 6
    errorStrategy 'retry'
    memory { (Math.pow(2, task.attempt - 1) * 6).toInteger() + 'GB' }
    time { (Math.pow(2, task.attempt - 1) * 15).toInteger() + 'm' }
    publishDir params.result_dir, mode: "copy"

    input:
    path chunk_result
    path benchmarking_info

    output:
    path "$params.result_file_name", emit: final_results

    script:
    """
    run_evaluation.R $params.simulatr_specifier_fp $params.result_file_name chunk_result* benchmarking_info*
    """
}

// Workflow definition

workflow {
    obtain_basic_info()
    method_names_ch = obtain_basic_info.out.method_names_raw.splitText().map{it.trim()}
    grid_rows_ch = obtain_basic_info.out.grid_rows_raw.splitText().map{it.trim()}
    method_cross_grid_row_ch = method_names_ch.combine(grid_rows_ch)

    run_benchmark(method_cross_grid_row_ch)
    run_simulation_chunk(run_benchmark.out.proc_id_info.splitCsv())
    evaluate_methods(run_simulation_chunk.out.chunk_result.collect(), run_benchmark.out.benchmarking_info.collect())
}
