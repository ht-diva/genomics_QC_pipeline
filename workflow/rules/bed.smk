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
            --hard-call-threshold 0.49999999 \
            --make-bed  \
            --alt1-allele 'force' {params.pfile}.pvar 4 3 \
            --out {params.prefix} \
            --threads {resources.threads} \
            --memory 1900 'require'
        """


rule merge_filter_hq_variants_new_id_alleles_bed:
    input:
        expand(
            ws_path(
                "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"
            ),
            chrom=[i for i in range(1, 23)],
        ),
    output:
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.bed"
        ),
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.bim"
        ),
        ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.fam"
        ),
        file_list=ws_path("bed/qc_recoded_harmonised/merge_list_new_id_alleles.txt"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        base_prefix=expand(
            ws_path(
                "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"
            ),
            chrom=[i for i in range(1, 23)],
        ),
        pmerge=ws_path(
            "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all"
        ),
    shell:
        """
 ls -1 {params.base_prefix} | cut -f1 -d"." > {output.file_list} \
 && plink2 \
 --pmerge-list {output.file_list} bfile \
 --make-bed \
 --out {params.pmerge} \
 --threads {resources.threads} \
 --memory 90000 'require'
"""
