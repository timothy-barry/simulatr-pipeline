#!/usr/bin/env Rscript

# Get CL args
args <- commandArgs(trailingOnly = TRUE)
n_args <- length(args)
result_file_name <- args[1]
curr_results_fp <- args[2]
raw_results_fp <- args[seq(3, n_args)]
all_results_fp <- c(curr_results_fp, raw_results_fp)

# combine raw results and save
out <- lapply(X = all_results_fp, FUN = readRDS) |> dplyr::bind_rows()
saveRDS(object = out, file = result_file_name)
