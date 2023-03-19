source ~/.research_config
simspec_filename=$LOCAL_CODE_DIR/symcrt2-project/code/sim_spec/sim_spec_dl_vs_knockoffs_small.rds
output_dir=$LOCAL_CODE_DIR/symcrt2-project/results
result_filename=dl_vs_knockoffs_small.rds
nextflow run main.nf \
    --simulatr_specifier_fp $simspec_filename \
    --result_dir $output_dir \
    --result_file_name $result_filename \
    --B_check 1 \
    --B 1