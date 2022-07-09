simspec_filename="/Users/ekatsevi/data/projects/symcrt/private/spec_objects/debug/sim_spec_gaussian_supervised_alternative.rds"
# simspec_filename="/Users/ekatsevi/data/projects/symcrt/private/spec_objects/v1/sim_spec_binomial_semi_supervised_null/sim_spec_binomial_semi_supervised_null.rds"
output_dir="/Users/ekatsevi/Desktop"
nextflow run main.nf \
    --simulatr_specifier_fp $simspec_filename \
    --result_dir $output_dir \
    --B 40000 \
    -resume