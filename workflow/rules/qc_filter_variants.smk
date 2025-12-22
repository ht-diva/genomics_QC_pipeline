
rule get_mirror_snps:
    input:
        rules.select_samples.output.pvar,
    output:
        ws_path("pgen/qc/filtering/{chrom}_mirror_snps.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        "python workflow/scripts/get_mirror_snps.py "
        "--input_file {input} "
        "--column ID "
        "--output_file {output}"


MIRROS_SNPS_PREFIX = "pgen/qc/filtering/{chrom}_filtered_mirror_snps"


rule filter_mirror_snps:
    input:
        rules.get_mirror_snps.output,
        rules.select_samples.output.pgen,
    output:
        temp(ws_path(MIRROS_SNPS_PREFIX + ".pgen")),
        temp(ws_path(MIRROS_SNPS_PREFIX + ".pvar")),
        temp(ws_path(MIRROS_SNPS_PREFIX + ".psam")),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.select_samples.params.prefix,
        prefix=ws_path(MIRROS_SNPS_PREFIX),
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --exclude {input[0]} \
 --make-pgen \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 1900 'require'
 """


SANITIZE_PROBLEMATIC_SNPS = "pgen/qc/filtering/"


rule sanitize_problematic_snps:
    input:
        problematic_snps=config.get("problematic_snps_path"),
    output:
        ws_path(SANITIZE_PROBLEMATIC_SNPS + "problematic_snps_list.txt"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """sed 's/^chr//' {input} > {output}"""


PROBLEMATIC_SNPS_PREFIX = "pgen/qc/filtering/{chrom}_filtered_problematic_snps"


rule filter_problematic_snps:
    input:
        rules.filter_mirror_snps.output,
        rules.sanitize_problematic_snps.output,
    output:
        temp(ws_path(PROBLEMATIC_SNPS_PREFIX + ".pgen")),
        temp(ws_path(PROBLEMATIC_SNPS_PREFIX + ".pvar")),
        temp(ws_path(PROBLEMATIC_SNPS_PREFIX + ".psam")),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.filter_mirror_snps.params.prefix,
        prefix=ws_path(PROBLEMATIC_SNPS_PREFIX),
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --exclude {input[1]} \
 --make-pgen \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 1900 'require'
 """


FILTER_VAR_PREFIX = "pgen/qc/{chrom}.impute_recoded_selected_sample_filtered_var"


rule filter_var:
    input:
        branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output,
            otherwise=rules.filter_mirror_snps.output,
        ),
    output:
        pgen=ws_path(FILTER_VAR_PREFIX + ".pgen"),
        pvar=ws_path(FILTER_VAR_PREFIX + ".pvar"),
        psam=ws_path(FILTER_VAR_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.params.prefix,
            otherwise=rules.filter_mirror_snps.params.prefix,
        ),
        prefix=ws_path(FILTER_VAR_PREFIX),
        geno=config.get("plink2_dict").get("geno"),
        hwe=config.get("plink2_dict").get("hwe"),
        mac=config.get("plink2_dict").get("mac"),
    shell:
        """plink2 \
 --pfile {params.pfile} \
 --not-chr X Y XY \
 --geno {params.geno} \
 --hwe {params.hwe} \
 --mac {params.mac} \
 --make-pgen \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 19000 'require'
 """
