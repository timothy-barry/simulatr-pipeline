#!/usr/bin/env Rscript
library(simulatr)

args <- commandArgs(trailingOnly = TRUE)
simulatr_spec <- readRDS(args[1])
method_names <- names(simulatr_spec@run_method_functions)

# extract relevant row IDs
n_row <- nrow(simulatr_spec@parameter_grid)
grid_ids <- seq(1, n_row)

# write row_idxs and method_names to separate files; convert both to Nextflow chanels.
write_vector <- function(file_name, vector) {
  file_con <- file(file_name)
  writeLines(as.character(vector), file_con)
  close(file_con)
}

write_vector("method_names.txt", method_names)
write_vector("grid_rows.txt", grid_ids)
