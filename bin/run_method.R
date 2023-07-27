#!/usr/bin/env Rscript
library(simulatr)

# accept command line arguments, load simulatr_specifier
args <- commandArgs(trailingOnly = TRUE)
simulatr_spec <- readRDS(args[1])
data_list_obj <- readRDS(args[2])
method <- args[3]
B_in <- as.integer(args[4])

# obtain the row index and processor ID
row_idx <- data_list_obj[["row_idx"]]
proc_id <- data_list_obj[["proc_id"]]

# obtain the method object
method_object <- simulatr_spec@run_method_functions[[method]]

# i) set seed, ii) update B (if necessary), and (iii) obtain method args
out <- setup_script(simulatr_spec, B_in, method_object, row_idx)
simulatr_spec <- out$simulatr_spec
ordered_args <- c(list(NA), out$ordered_args)

# obtain the data list
data_list <- data_list_obj[["data_list"]]

if (method_object@loop) {
  result_list <- vector(mode = "list", length = length(data_list))
  for (i in seq(1, length(data_list))) {
    curr_df <- data_list[[i]]
    ordered_args[[1]] <- curr_df
    out <- dplyr::tibble(output = list(do.call(method_object@f, ordered_args)),
                          run_id = i)
    result_list[[i]] <- out
  }
  result_df <- do.call(rbind, result_list)
} else {
  ordered_args[[1]] <- data_list
  result_df <- do.call(method_object@f, ordered_args)
}

to_save <- collate_result_list(result_df, proc_id, row_idx, method)
# save result
saveRDS(to_save, "raw_result.rds")
