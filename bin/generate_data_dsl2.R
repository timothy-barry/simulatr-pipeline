#!/usr/bin/env Rscript
library(simulatr)

# read command line arguments
args <- commandArgs(trailingOnly = TRUE)
simulatr_spec <- readRDS(args[1])
row_idx <- as.integer(args[2])
B_in <- as.integer(args[3])

# extract data generator
data_generator <- simulatr_spec@generate_data_function

# set seed, obtain updated simulatr specifier object, and get argument list
out <- setup_script(simulatr_spec, B_in, data_generator, row_idx)
simulatr_spec <- out$simulatr_spec
ordered_args <- out$ordered_args

# call the data generator function; either loop or just pass all arguments
if (data_generator@loop) {
  B <- get_param_from_simulatr_spec(simulatr_spec, row_idx, "B")
  data_list <- replicate(B, do.call(data_generator@f, ordered_args), FALSE)
} else {
  data_list <- do.call(data_generator@f, ordered_args)
}

# split data_list into n_processors equally sized chunks
n_processors <- min(get_param_from_simulatr_spec(simulatr_spec, row_idx, "n_processors"), length(data_list))

if (n_processors > 1) {
  cuts <- cut(seq(1, length(data_list)), n_processors)
} else {
  cuts <- factor(rep("all_data", length(data_list)))
}

l_cuts <- levels(cuts)
for (i in seq(1, n_processors)) {
  to_save_data <- data_list[cuts == l_cuts[i]]
  to_save_object <- list(data_list = to_save_data, row_idx = row_idx, proc_id = i)
  to_save_fp <- paste0("data_list_", i)
  saveRDS(to_save_object, to_save_fp)
}
