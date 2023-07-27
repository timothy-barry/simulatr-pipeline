#!/usr/bin/env Rscript

# Get CL args
args <- commandArgs(trailingOnly = TRUE)
n_args <- length(args)
simulatr_spec <- readRDS(args[1])
result_file_name <- args[2]
raw_results_fp <- args[seq(3, n_args)]

# combine raw results and save
results <- lapply(X = raw_results_fp, FUN = readRDS) |>
  data.table::rbindlist() |>
  as.data.frame()

# join the results with the parameter grid
results_joined <- results |> 
  dplyr::left_join(simulatr_spec@parameter_grid |> 
              dplyr::mutate(grid_id = dplyr::row_number()) |> 
              dplyr::select(grid_id, ground_truth), 
            by = "grid_id")

# evaluate the metrics
if(length(simulatr_spec@evaluation_functions) > 0){
  metrics <- lapply(names(simulatr_spec@evaluation_functions), function(fun_name){
    results_joined |> 
      dplyr::rowwise() |>
      dplyr::mutate(metric = fun_name, value = simulatr_spec@evaluation_functions[[fun_name]](output, ground_truth)) |>
      dplyr::ungroup()
  }) |>
    data.table::rbindlist() |>
    as.data.frame() |>
    dplyr::group_by(grid_id, method, metric) |>
    dplyr::summarise(mean = mean(value), se = sd(value)/sqrt(dplyr::n()), .groups = "drop") |>
    dplyr::left_join(simulatr_spec@parameter_grid |> 
                        dplyr::mutate(grid_id = dplyr::row_number()) |> 
                        dplyr::select(-ground_truth), 
                      by = "grid_id") |>
    dplyr::select(-grid_id) |>
    dplyr::relocate(method, metric, mean, se)
} else{
  metrics <- NULL
}

# return
output <- list(
  results = results,
  metrics = metrics
)

saveRDS(object = output, file = result_file_name)