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
B <- out$simulatr_spec@fixed_parameters$B

# split data_list into n_processors equally sized chunks
n_processors <- get_param_from_simulatr_spec(simulatr_spec, row_idx, "n_processors")
if(n_processors > 1){
  cuts <- cut(seq(1, B), n_processors)
} else{
  cuts <- factor(rep("all_data", B))
}
l_cuts <- levels(cuts)
for (i in seq(1, n_processors)) {
  # number of replicates to do for this processor
  B_i <- sum(cuts == l_cuts[i])
  # call the data generator function; either loop or just pass all arguments
  if (data_generator@loop) {
    data_list <- replicate(B_i, do.call(data_generator@f, ordered_args), FALSE)
  } else {
    ordered_args_i <- ordered_args
    ordered_args_i[which(data_generator@arg_names == "B")] <- B_i
    data_list <- do.call(data_generator@f, ordered_args_i)
  }

  # save data object
  to_save_object <- list(data_list = data_list, row_idx = row_idx, proc_id = i)
  to_save_fp <- paste0("data_list_", i)
  saveRDS(to_save_object, to_save_fp)

  # clear memory
  rm(to_save_object, data_list)
  gc()
}
