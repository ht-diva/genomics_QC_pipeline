RECODE_PREFIX = "pgen/qc/{chrom}_impute_recoded"


rule recode_pgen:
    input:
        get_pgen(),
    output:
        pgen=ws_path(RECODE_PREFIX + ".pgen"),
        pvar=ws_path(RECODE_PREFIX + ".pvar"),
        psam=ws_path(RECODE_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        prefix=ws_path(RECODE_PREFIX),
        pfile=get_pgen(stem=True),
    shell:
        """plink2 \
--pfile {params.pfile} \
--set-all-var-ids '@:#:$r:$a' \
--new-id-max-allele-len 1000 \
--make-pgen \
--out {params.prefix} \
--threads {threads} \
--memory 90000 'require'
"""


# Define the whitelist of allowed methods
ALLOWED_SAMPLE_SELECTION_METHODS = ["keep", "keep-fam", "remove", "remove-fam"]


def get_valid_method():
    """Return the method from config if it is allowed, otherwise abort."""
    method = config.get("sample_selection_method")
    if method not in ALLOWED_SAMPLE_SELECTION_METHODS:
        raise ValueError(
            f"Invalid sample_selection_method '{method}'. "
            f"Choose one of {ALLOWED_SAMPLE_SELECTION_METHODS}."
        )
    return method


SELECT_PREFIX = "pgen/qc/{chrom}_impute_recoded_selected_sample"


rule select_samples:
    input:
        rules.recode_pgen.output.pgen,
        rules.recode_pgen.output.pvar,
        rules.recode_pgen.output.psam,
    output:
        pgen=ws_path(SELECT_PREFIX + ".pgen"),
        pvar=ws_path(SELECT_PREFIX + ".pvar"),
        psam=ws_path(SELECT_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        method=get_valid_method(),
        id_list=config.get("id_list_path"),
        pfile=ws_path(RECODE_PREFIX),
        prefix=ws_path(SELECT_PREFIX),
        mind=config.get("plink2_dict").get("mind"),
    shell:
        """plink2 \
--pfile {params.pfile} \
--{params.method} {params.id_list} \
--make-pgen \
--mind {params.mind} \
--out {params.prefix} \
--threads {threads} \
--memory 90000 'require'
"""
