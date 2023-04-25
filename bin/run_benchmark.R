#!/usr/bin/env Rscript

library(simulatr)

# read command line arguments
args <- commandArgs(trailingOnly = TRUE)
simulatr_spec <- readRDS(args[1])
method <- args[2]
row_idx <- as.integer(args[3])
B_check <- as.integer(args[4])
B_in <- as.integer(args[5])
max_gb <- as.numeric(args[6])
max_hours <- as.numeric(args[7])

# extract data generator and its ordered arguments
data_generator <- simulatr_spec@generate_data_function
ordered_args_data_gen <- get_ordered_args(data_generator, simulatr_spec, row_idx)

# extract the method object and its ordered arguments
method_object <- simulatr_spec@run_method_functions[[method]]
ordered_args_method <- get_ordered_args(method_object, simulatr_spec, row_idx)

# extract the seed
seed <- simulatr_spec@fixed_parameters$seed

# benchmark data generation
invisible(gc())
data_bytes <- pryr::mem_change(
  data_seconds <- system.time(
    if (data_generator@loop) {
      data_list <- lapply(
        1:B_check,
        function(b) {
          R.utils::withSeed(do.call(data_generator@f, ordered_args_data_gen),
                            seed = seed + b)
        }
      )
    } else {
      data_list <- do.call(data_generator@f, ordered_args)
    }
  )[["elapsed"]]
) |> as.numeric()
data_bytes_per_rep <- data_bytes / B_check
data_seconds_per_rep <- data_seconds / B_check

# benchmark method application
method_bytes <- pryr::mem_change(
  method_seconds <- system.time(
    if (method_object@loop) {
      result_list <- vector(mode = "list", length = B_check)
      for (b in 1:B_check) {
        curr_df <- data_list[[b]]
        ordered_args_method[[1]] <- curr_df
        out <- R.utils::withSeed(do.call(method_object@f, ordered_args_method), seed = seed)
        out$run_id <- b
        result_list[[b]] <- out
      }
      result_df <- do.call(rbind, result_list)
    } else {
      ordered_args[[1]] <- data_list
      result_df <- do.call(method_object@f, ordered_args_method)
    }
  )[["elapsed"]]
) |> as.numeric()
method_bytes_per_rep <- method_bytes / B_check
method_seconds_per_rep <- method_seconds / B_check

# compute the number of processors needed
B <- if (B_in != 0) B_in else simulatr_spec@fixed_parameters$B
gb_per_rep <- (data_bytes_per_rep + method_bytes_per_rep) / 1e9
hrs_per_rep <- (data_seconds_per_rep + method_seconds_per_rep) / (60 * 60)
n_processors <- max(ceiling(B * hrs_per_rep / (1.2 * max_hours)), 
                    ceiling(B * gb_per_rep / (1.2 * max_gb)))

# write benchmarking information
benchmarking_info <- data.frame(method = method, 
                                grid_id = row_idx, 
                                gb_per_rep = method_bytes_per_rep / 1e9, 
                                hrs_per_rep = method_seconds_per_rep / (60*60), 
                                n_processors = n_processors)
saveRDS(benchmarking_info, "benchmarking_info.rds")

# write processors information
proc_id_info <- data.frame(method = method, 
                           grid_id = row_idx, 
                           proc_id = 1:n_processors, 
                           n_processors = n_processors)
write.table(proc_id_info, file = "proc_id_info.csv", col.names = FALSE, row.names = FALSE, sep = ",")