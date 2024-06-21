rule sync_tables:
    input:
        recode=ws_path("pgen/recode_rsids.txt"),
        biallelic=ws_path("pgen/pseudo_biallelic.txt"),
    output:
        touch(protected(dest_path_pgen("pgen/.tables_delivery.done"))),
    params:
        recode=dest_path_pgen("pgen/recode_rsids.txt"),
        biallelic=dest_path_pgen("pgen/pseudo_biallelic.txt"),
    resources:
        runtime=lambda wc, attempt: attempt * 10,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.recode} {params.recode} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.biallelic} {params.biallelic}"""


rule sync_pfiles:
    input:
        pgen_c=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pgen"
        ),
        pvar_c=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pvar"
        ),
        psam_c=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.psam"
        ),
        pgen_a=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.pgen"
        ),
        pvar_a=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.pvar"
        ),
        psam_a=ws_path(
            "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.psam"
        ),
    output:
        touch(dest_path_pgen("pgen/qc_recoded/.{chrom}_delivery.done")),
    params:
        folder=dest_path_pgen("pgen/qc_recoded/"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.pgen_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pvar_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.psam_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pgen_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pvar_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.psam_a} {params.folder} """


rule sync_bedfiles:
    input:
        bed=ws_path(
            "bed/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"
        ),
        bim=ws_path(
            "bed/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bim"
        ),
        fam=ws_path(
            "bed/qc_recoded/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.fam"
        ),
    output:
        touch(dest_path_bed("bed/qc_recoded/.{chrom}_delivery.done")),
    params:
        folder=dest_path_bed("bed/qc_recoded/"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.bed} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bim} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.fam} {params.folder} && \
 """
