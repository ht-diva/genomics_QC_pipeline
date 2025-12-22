# Filter by HQ variants

CREATE_BGEN_PREFIX = (
    "pgen/qc/filtering/bgen_chr_{chrom}_impute_recoded_selected_sample_filtered_var"
)


rule create_bgen:
    input:
        rules.filter_var.output.pgen,
        rules.filter_var.output.pvar,
        rules.filter_var.output.psam,
    output:
        bgen=ws_path(CREATE_BGEN_PREFIX + ".bgen"),
        sample=ws_path(CREATE_BGEN_PREFIX + ".sample"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.filter_var.params.prefix,
        prefix=ws_path(CREATE_BGEN_PREFIX),
        export_output_fmt=config.get("plink2_dict").get("export_output_fmt"),
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --export {params.export_output_fmt} \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 19000 'require'
 """


QCTOOL_PREFIX = "pgen/qc/filtering/snp-stats_chr_{chrom}_impute_recoded_selected_sample_filtered_var"


rule qctool:
    input:
        rules.create_bgen.output.bgen,
    output:
        ws_path(QCTOOL_PREFIX + ".txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/qctool:2.2.0"
    resources:
        runtime=lambda wc, attempt: attempt * 240,
    shell:
        """qctool \
-g {input} \
-snp-stats \
-osnp {output} \
-threads {resources.threads}
    """


GET_HG_VARIANTS_PREFIX = "pgen/qc/filtering/hq_variants_chr_{chrom}_impute_recoded_selected_sample_filtered_var"


rule get_hq_variants:
    input:
        rules.qctool.output,
    output:
        snp_list=ws_path(GET_HG_VARIANTS_PREFIX + ".txt"),
        log=ws_path("pgen/qc/filtering/report_hq_variants_chr{chrom}.log"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        INFO_score=config.get("INFO_score"),
    shell:
        """
    total_rows=$(grep -v ^#  {input} | wc -l) && \
    echo "Number of rows before filtering for INFO score > {params.INFO_score}: $total_rows" >> {output.log} && \
    grep -v ^#  {input} | \
    awk '$17 > {params.INFO_score} {{ print $2 }}'  >  {output.snp_list} && \
    filtered_rows=$(wc -l < {output.snp_list}) && \
    echo "Number of rows after filtering for INFO score > {params.INFO_score}: $filtered_rows" >> {output.log}
    """


FILTER_HG_VARIANTS_PREFIX = (
    "pgen/qc/{chrom}.impute_recoded_selected_sample_filtered_var_filtered_info_score"
)


rule filter_hq_variants:
    input:
        rules.filter_var.output.pgen,
        rules.filter_var.output.pvar,
        rules.filter_var.output.psam,
        rules.get_hq_variants.output.snp_list,
    output:
        pgen=ws_path(FILTER_HG_VARIANTS_PREFIX + ".pgen"),
        pvar=ws_path(FILTER_HG_VARIANTS_PREFIX + ".pvar"),
        psam=ws_path(FILTER_HG_VARIANTS_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.filter_var.params.prefix,
        prefix=ws_path(FILTER_HG_VARIANTS_PREFIX),
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --extract {input[3]} \
 --make-pgen \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 1900 'require'
 """


MERGE_FILTER_HG_VARIANTS_PREFIX = (
    "pgen/qc/all_impute_recoded_selected_sample_filtered_var_filtered_info_score"
)


rule merge_filter_hq_variants:
    input:
        expand(
            rules.filter_hq_variants.output.pgen,
            chrom=get_chromosomes(),
        ),
    output:
        pgen=ws_path(MERGE_FILTER_HG_VARIANTS_PREFIX + ".pgen"),
        pvar=ws_path(MERGE_FILTER_HG_VARIANTS_PREFIX + ".pvar"),
        psam=ws_path(MERGE_FILTER_HG_VARIANTS_PREFIX + ".psam"),
        file_list=ws_path("pgen/qc/merge_list.txt"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        base_prefix=expand(
            rules.filter_hq_variants.output.pgen,
            chrom=get_chromosomes(),
        ),
        pmerge=ws_path(MERGE_FILTER_HG_VARIANTS_PREFIX),
    shell:
        """
 ls -1 {params.base_prefix} | cut -f1 -d"." > {output.file_list} \
 && plink2 --pmerge-list {output.file_list} \
 --make-pgen \
 --out {params.pmerge} \
 --threads {resources.threads} \
 --memory 90000 'require'
"""


# Filter by minimac3

FILTER_BY_MINIMAC3_PREFIX = (
    "pgen/qc/{chrom}.impute_recoded_selected_sample_filtered_var_filtered_minimac3"
)


rule filter_by_minimac3:
    input:
        rules.filter_var.output.pgen,
        rules.filter_var.output.pvar,
        rules.filter_var.output.psam,
    output:
        pgen=ws_path(FILTER_BY_MINIMAC3_PREFIX + ".pgen"),
        pvar=ws_path(FILTER_BY_MINIMAC3_PREFIX + ".pvar"),
        psam=ws_path(FILTER_BY_MINIMAC3_PREFIX + ".psam"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        minimac3_r2_filter=config.get("plink2_dict").get("minimac3-r2-filter"),
        prefix=ws_path(FILTER_BY_MINIMAC3_PREFIX),
        pfile=rules.filter_var.params.prefix,
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --minimac3-r2-filter {params.minimac3_r2_filter} \
 --make-pgen \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 19000 'require'
"""
