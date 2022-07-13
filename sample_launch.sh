source ~/.research_config
simspec_filename=$LOCAL_SYMCRT_DATA_DIR/private/spec_objects/debug/sim_spec_gaussian_supervised_alternative.rds
output_dir=$LOCAL_SYMCRT_DATA_DIR/private/output/debug/
nextflow run main.nf \
    --simulatr_specifier_fp $simspec_filename \
    --result_dir $output_dir \
    --B 5