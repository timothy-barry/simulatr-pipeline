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
invisible(gc(reset = TRUE)) # garbage collect prior to generating data
seconds <- system.time(
if (data_generator@loop) {
  data_list <- replicate(B_in, do.call(data_generator@f, ordered_args), FALSE)
} else {
  data_list <- do.call(data_generator@f, ordered_args)
})[["elapsed"]]/B_in
to_save_object <- list(data_list = data_list, row_idx = row_idx) # unfortunately requires copying the data
bytes <- get_memory_used()/B_in

# save the data
saveRDS(to_save_object, "data_benchmark.rds")

# save the benchmarking information
saveRDS(data.frame(row_idx = row_idx, seconds = seconds, bytes = bytes), "data_benchmarking_info.rds")
