#!/usr/bin/env Rscript

library(simulatr)

# read command line arguments
args <- commandArgs(trailingOnly = TRUE)
simulatr_spec <- readRDS(args[1])
method <- args[2]
row_idx <- as.integer(args[3])
proc_id <- as.integer(args[4])
n_processors <- as.integer(args[5])
B_in <- as.integer(args[6])

# extract data generator and its ordered arguments
data_generator <- simulatr_spec@generate_data_function
ordered_args_data_gen <- get_ordered_args(data_generator, simulatr_spec, row_idx)

# extract the method object and its ordered arguments
method_object <- simulatr_spec@run_method_functions[[method]]
ordered_args_method <- c(list(NA), get_ordered_args(method_object, simulatr_spec, row_idx))

# extract the seed
seed <- simulatr_spec@fixed_parameters$seed

# find the replicate indices
B <- if (B_in != 0) B_in else simulatr_spec@fixed_parameters$B
all_b <- 1:B
proc_id_b <- all_b[1 + (all_b %% n_processors) == proc_id]

# data generation
if (data_generator@loop) {
  data_list <- lapply(
    proc_id_b,
    function(b) {
      R.utils::withSeed(do.call(data_generator@f, ordered_args_data_gen),
                        seed = seed + b)
    }
  )
} else {
  data_list <- do.call(data_generator@f, ordered_args_data_gen)
}

# method application
if (method_object@loop) {
  result_list <- vector(mode = "list", length = length(proc_id_b))
  for (b_idx in 1:length(proc_id_b)) {
    curr_df <- data_list[[b_idx]]
    ordered_args_method[[1]] <- curr_df
    out <- dplyr::tibble(output = list(R.utils::withSeed(do.call(method_object@f, ordered_args_method), seed = seed)),
                         run_id = proc_id_b[b_idx])
    result_list[[b_idx]] <- out
  }
  result_df <- do.call(rbind, result_list)
} else {
  ordered_args_method[[1]] <- data_list
  result_df <- do.call(method_object@f, ordered_args_method)
}

# save result
to_save <- collate_result_list(result_df, proc_id, row_idx, method)
saveRDS(to_save, "chunk_result.rds")
