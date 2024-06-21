rule sync_tables:
    input:
        recode=ws_path("pgen/recode_rsids.txt"),
        biallelic=ws_path("pgen/pseudo_biallelic.txt"),
    output:
        touch(dest_path("pgen/.tables_delivery.done")),
    params:
        recode=dest_path("pgen/recode_rsids.txt"),
        biallelic=dest_path("pgen/pseudo_biallelic.txt"),
    resources:
        runtime=lambda wc, attempt: attempt * 10,
    shell:
        """
        rsync -rlptoDvz --chmod "D755,F644" {input.recode} {params.recode} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.biallelic} {params.biallelic}"""


rule sync_pfiles_c:
    input:
        pgen_c=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pgen"
        ),
        pvar_c=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.pvar"
        ),
        psam_c=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.psam"
        ),
    output:
        touch(dest_path("pgen/.{chrom}_delivery.done")),
    params:
        folder=dest_path("pgen/"),
    resources:
        runtime=lambda wc, attempt: attempt * 90,
    shell:
        """mkdir -p {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pgen_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pvar_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.psam_c} {params.folder}"""


rule sync_pfiles_all:
    input:
        pgen_a=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.pgen"
        ),
        pvar_a=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.pvar"
        ),
        psam_a=ws_path(
            "pgen/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.psam"
        ),
    output:
        touch(dest_path("pgen/.all_delivery.done")),
    params:
        folder=dest_path("pgen/"),
    resources:
        runtime=lambda wc, attempt: attempt * 90,
    shell:
        """mkdir -p {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pgen_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.pvar_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.psam_a} {params.folder} """


rule sync_bedfiles_c:
    input:
        bed_c=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bed"
        ),
        bim_c=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.bim"
        ),
        fam_c=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.fam"
        ),
    output:
        touch(dest_path("bed/.{chrom}_delivery.done")),
    params:
        folder=dest_path("bed/"),
    resources:
        runtime=lambda wc, attempt: attempt * 90,
    shell:
        """mkdir -p {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bed_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bim_c} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.fam_c} {params.folder}"""


rule sync_bedfiles_all:
    input:
        bed_a=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.bed"
        ),
        bim_a=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.bim"
        ),
        fam_a=ws_path(
            "bed/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.fam"
        ),
    output:
        touch(dest_path("bed/.all_delivery.done")),
    params:
        folder=dest_path("bed/"),
    resources:
        runtime=lambda wc, attempt: attempt * 90,
    shell:
        """mkdir -p {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bed_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.bim_a} {params.folder} && \
        rsync -rlptoDvz --chmod "D755,F644" {input.fam_a} {params.folder}"""
