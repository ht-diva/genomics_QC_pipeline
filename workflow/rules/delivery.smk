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
        pgen=ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pgen"),
        pvar=ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pvar"),
        psam=ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.psam"),
    output:
        touch(dest_path_pgen("pgen/.{chrom}_delivery.done")),
    params:
        folder=dest_path_pgen("pgen/"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.pgen} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pvar} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.psam} {params.folder}"""

rule sync_bedfiles:
    input:
        bed=ws_path("bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"),
        bim=ws_path("bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bim"),
        fam=ws_path("bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.fam"),
    output:
        touch(dest_path_bed("bed/.{chrom}_delivery.done")),
    params:
        folder=dest_path_bed("bed/"),
    resources:
        runtime= lambda wc,attempt: attempt * 60,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.bed} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bim} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.fam} {params.folder}"""
