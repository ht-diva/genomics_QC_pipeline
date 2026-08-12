rule build_snp_mapping_files:
    input:
        branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": rules.filter_var.output.pvar,
                "info_score": rules.filter_hq_variants.output.pvar,
                "minimac3": rules.filter_by_minimac3.output.pvar,
            },
        ),
    output:
        mapping_table=ws_path(
            "snp_mapping/{chrom}/snp_mapping/table.snp_mapping.tsv.gz"
        ),
        table=ws_path("snp_mapping/{chrom}/outputs/{chrom}/{chrom}.gwaslab.tsv.gz"),
    container:
        "docker://ghcr.io/ht-diva/gwaspipe:7a17c0"
    params:
        config_file=config.get("config_file_path"),
        output_path=ws_path("snp_mapping/{chrom}/"),
    shell:
        "gwaspipe "
        "-f plink_pvar "
        "-i {input} "
        "-c {params.config_file} "
        "-o {params.output_path}"


UPDATE_PGEN_ID_PREFIX = "pgen/qc_harmonised/{chrom}_qced_new_id"


rule update_pgen_id:
    input:
        pfile=branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": rules.filter_var.output.pgen,
                "info_score": rules.filter_hq_variants.output.pgen,
                "minimac3": rules.filter_by_minimac3.output.pgen,
            },
        ),
        mapping_table=rules.build_snp_mapping_files.output.mapping_table,
    output:
        pgen=ws_path(UPDATE_PGEN_ID_PREFIX + ".pgen"),
        pvar=ws_path(UPDATE_PGEN_ID_PREFIX + ".pvar"),
        psam=ws_path(UPDATE_PGEN_ID_PREFIX + ".psam"),
    log:
        ws_path(UPDATE_PGEN_ID_PREFIX + ".log"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": rules.filter_var.params.prefix,
                "info_score": rules.filter_hq_variants.params.prefix,
                "minimac3": rules.filter_by_minimac3.params.prefix,
            },
        ),
        prefix=ws_path(UPDATE_PGEN_ID_PREFIX),
    shell:
        """plink2 \
--update-name {input.mapping_table} 1 2 \
--pfile {params.pfile} \
--make-pgen \
--out {params.prefix} \
--threads {threads} \
--memory 1900 'require'
"""


UPDATE_PGEN_ALELLES_PREFIX = "pgen/qc_harmonised/{chrom}_qced_new_id_alleles"


rule update_pgen_alleles:
    input:
        pgen=rules.update_pgen_id.output.pgen,
        table=rules.build_snp_mapping_files.output.table,
    output:
        pgen=ws_path(UPDATE_PGEN_ALELLES_PREFIX + ".pgen"),
        pvar=ws_path(UPDATE_PGEN_ALELLES_PREFIX + ".pvar"),
        psam=ws_path(UPDATE_PGEN_ALELLES_PREFIX + ".psam"),
    log:
        ws_path(UPDATE_PGEN_ALELLES_PREFIX + ".log"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.update_pgen_id.params.prefix,
        prefix=ws_path(UPDATE_PGEN_ALELLES_PREFIX),
    shell:
        """plink2 \
--ref-allele force {input.table} 5 3 \
--alt1-allele {input.table} 4 3 \
--make-pgen \
--pfile {params.pfile} \
--out {params.prefix} \
--threads {threads} \
--memory 1900 'require'
"""
