#!/usr/bin/env Rscript
library(simulatr)
library(rlecuyer)

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

# extract the method object and its ordered arguments
method_object <- simulatr_spec@run_method_functions[[method]]
ordered_args_method <- c(list(NA), get_ordered_args(method_object, simulatr_spec, row_idx))

# set the parallel seed
seed <- simulatr_spec@fixed_parameters$seed
.lec.SetPackageSeed(4) |> invisible()
snames <- as.character(seq(1, n_processors))
.lec.CreateStream(snames) |> invisible()
.lec.CurrentStream(snames[proc_id]) |> invisible()

# determine the number of datasets to generate
B <- if (B_in != 0) B_in else simulatr_spec@fixed_parameters$B
n_datasets_to_generate <- ceiling(B/n_processors)

# data generation
if (data_generator@loop) {
  ordered_args_data_gen <- get_ordered_args(data_generator, simulatr_spec, row_idx)
  data_list <- replicate(n = n_datasets_to_generate,
                         expr = do.call(data_generator@f, ordered_args_data_gen),
                         simplify = FALSE)
} else {
  # update sim spec with n procs
  simulatr_spec@fixed_parameters$B <- n_datasets_to_generate
  ordered_args_data_gen <- get_ordered_args(data_generator, simulatr_spec, row_idx)
  data_list <- do.call(data_generator@f, ordered_args_data_gen)
}

# method application
if (method_object@loop) {
  result_list <- vector(mode = "list", length = n_datasets_to_generate)
  for (b_idx in seq(1, n_datasets_to_generate)) {
    curr_df <- data_list[[b_idx]]
    ordered_args_method[[1]] <- curr_df
    out <- dplyr::tibble(output = list(do.call(method_object@f, ordered_args_method)),
                         run_id = b_idx)
    result_list[[b_idx]] <- out
  }
  result_df <- do.call(rbind, result_list)
} else {
  stop("Method loop not yet implemented.")
  ordered_args_method[[1]] <- data_list
  result_df <- do.call(method_object@f, ordered_args_method)
}

# save result
to_save <- collate_result_list(result_df, proc_id, row_idx, method)
saveRDS(to_save, "chunk_result.rds")
