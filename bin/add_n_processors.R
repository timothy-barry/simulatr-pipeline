#!/usr/bin/env Rscript
library(simulatr)

# read command line arguments
args <- commandArgs(trailingOnly = TRUE)
n_args <- length(args)
data_benchmarking_fps <- args[grepl("data_", args)]
method_benchmarking_fps <- args[grepl("method_", args)]
max_gb <- as.numeric(args[n_args-3])
max_hours <- as.numeric(args[n_args-2])
B_in <- as.integer(args[n_args-1])
simulatr_spec_name <- args[n_args]
simulatr_spec <- readRDS(simulatr_spec_name)

# get data-generation benchmarking data
data_benchmarking <- lapply(X = data_benchmarking_fps, FUN = readRDS) |>
  data.table::rbindlist() |>
  as.data.frame()

# get method benchmarking data
method_benchmarking <- lapply(X = method_benchmarking_fps, FUN = readRDS) |>
  data.table::rbindlist() |>
  as.data.frame()

# maximize over methods per grid row
method_max_benchmarking <- method_benchmarking |>
  dplyr::group_by(row_idx) |>
  dplyr::summarise(seconds = max(seconds),
                   bytes = max(bytes))

# calculate number of processors per grid row
if(B_in == 0){
  B <- simulatr_spec@fixed_parameters$B
} else{
  B <- B_in
}
n_processors_df <- dplyr::inner_join(
  data_benchmarking |>
    dplyr::rename(data_seconds = seconds, data_bytes = bytes),
  method_max_benchmarking |>
    dplyr::rename(method_seconds = seconds, method_bytes = bytes),
  by = "row_idx"
) |>
  dplyr::mutate(seconds = pmax(data_seconds, method_seconds),
                bytes = pmax(data_bytes, method_bytes),
                n_processors_time = ceiling(B*seconds/(60*60*max_hours)),
                n_processors_bytes = ceiling(B*bytes/(1e9*max_gb)),
                n_processors = pmax(n_processors_time, n_processors_bytes)) |>
  dplyr::select(row_idx, n_processors)

# add this information to new simulatr specifier object
new_parameter_grid <- simulatr_spec@parameter_grid |>
  dplyr::select(-n_processors) |>
  dplyr::mutate(row_idx = dplyr::row_number()) |>
  dplyr::left_join(n_processors_df, by = "row_idx") |>
  dplyr::select(-row_idx)
new_simulatr_spec <- simulatr_spec
new_simulatr_spec@parameter_grid <- new_parameter_grid

# save the new simulatr specifier object
sim_string <- sub('\\.rds$', '', simulatr_spec_name)
# saveRDS(new_simulatr_spec, paste0(sim_string, "_checked.rds"))
saveRDS(new_simulatr_spec, "new_simspec_obj.rds")

# save the benchmarking information and new parameter grid to publish
saveRDS(method_benchmarking, paste0(sim_string, "_method_benchmarking.rds"))
saveRDS(data_benchmarking, paste0(sim_string, "_data_benchmarking.rds"))
saveRDS(new_parameter_grid, paste0(sim_string, "_grid_benchmarking.rds"))
