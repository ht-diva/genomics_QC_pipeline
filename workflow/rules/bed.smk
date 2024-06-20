rule pgen2bed:
    input:
        ws_path(
            "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pgen"
        ),
        ws_path(
            "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pvar"
        ),
        ws_path(
            "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.psam"
        ),
    output:
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"
        ),
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bim"
        ),
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.fam"
        ),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=ws_path(
            "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}"
        ),
        prefix=ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}"
        ),
    shell:
        """
        plink2 \
            --pfile {params.pfile} \
            --make-bed  \
            --alt1-allele 'force' {params.pfile}.pvar 4 3 \
            --out {params.prefix} \
            --threads {resources.threads} \
            --memory 90000 'require'
        """