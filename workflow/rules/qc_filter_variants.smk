SANITIZE_PROBLEMATIC_SNPS = "pgen/qc/filtering/"

rule sanitize_problematic_snps:
    input:
        problematic_snps=config.get("problematic_snps_path"),
    output:
        ws_path(SANITIZE_PROBLEMATIC_SNPS + "problematic_snps_list.txt"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """sed 's/^chr//' {input.problematic_snps} > {output}"""


PROBLEMATIC_SNPS_PREFIX = "pgen/qc/filtering/{chrom}_filtered_problematic_snps"


rule filter_problematic_snps:
    input:
        problematic_snps=rules.sanitize_problematic_snps.output,
        pgen=rules.select_samples.output.pgen,
        pvar=rules.select_samples.output.pvar,
        psam=rules.select_samples.output.psam,
    output:
        pgen=temp(ws_path(PROBLEMATIC_SNPS_PREFIX + ".pgen")),
        pvar=ws_path(PROBLEMATIC_SNPS_PREFIX + ".pvar"),
        psam=ws_path(PROBLEMATIC_SNPS_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.select_samples.params.prefix,
        prefix=ws_path(PROBLEMATIC_SNPS_PREFIX),
    shell:
        """plink2 \
        --pfile {params.pfile} \
        --exclude {input.problematic_snps} \
        --make-pgen \
        --out {params.prefix} \
        --threads {resources.threads} \
        --memory 1900 'require'
        """


rule get_mirror_snps:
    input:
        pvar=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output.pvar,
            otherwise=rules.select_samples.output.pvar,
        ),
    output:
        ws_path("pgen/qc/filtering/{chrom}_mirror_snps.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        "python workflow/scripts/get_mirror_snps.py "
        "--input_file {input.pvar} "
        "--column ID "
        "--output_file {output}"


MIRROR_SNPS_PREFIX = "pgen/qc/filtering/{chrom}_filtered_mirror_snps"


rule filter_mirror_snps:
    input:
        mirror_snps=rules.get_mirror_snps.output,
        pgen=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output.pgen,
            otherwise=rules.select_samples.output.pgen,
        ),
        pvar=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output.pvar,
            otherwise=rules.select_samples.output.pvar,
        ),
        psam=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output.psam,
            otherwise=rules.select_samples.output.psam,
        ),
    output:
        pgen=temp(ws_path(MIRROR_SNPS_PREFIX + ".pgen")),
        pvar=ws_path(MIRROR_SNPS_PREFIX + ".pvar"),
        psam=ws_path(MIRROR_SNPS_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.params.prefix,
            otherwise=rules.select_samples.params.prefix,
        ),
        prefix=ws_path(MIRROR_SNPS_PREFIX),
    shell:
        """plink2 \
        --pfile {params.pfile} \
        --exclude {input.mirror_snps} \
        --make-pgen \
        --out {params.prefix} \
        --threads {resources.threads} \
        --memory 1900 'require'
        """


AFREQ_PREFIX = "pgen/qc/filtering/{chrom}_filtered_mirror_snps"


rule compute_afreq:
    input:
        pgen=rules.filter_mirror_snps.output.pgen,
        pvar=rules.filter_mirror_snps.output.pvar,
        psam=rules.filter_mirror_snps.output.psam,
    output:
        temp(ws_path(AFREQ_PREFIX + ".afreq")),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.filter_mirror_snps.params.prefix,
        prefix=ws_path(AFREQ_PREFIX),
    shell:
        """plink2 \
        --pfile {params.pfile} \
        --freq \
        --out {params.prefix} \
        --threads {resources.threads} \
        --memory 19000 'require'
        """


BEST_SNPS_PREFIX = "pgen/qc/filtering/{chrom}_best_snps"


rule select_best_snps:
    input:
        afreq=rules.compute_afreq.output,
        pvar=rules.filter_mirror_snps.output.pvar,
    output:
        temp(ws_path(BEST_SNPS_PREFIX + ".txt")),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        "python workflow/scripts/select_best_snps.py"
        "--afreq {input.afreq} "
        "--pvar {input.pvar} "
        "--output {output}"


FILTER_MULTIALLELIC_PREFIX = "pgen/qc/filtering/{chrom}_filtered_multiallelic_var"


rule filter_multiallelic_var:
    input:
        pgen=rules.filter_mirror_snps.output.pgen,
        pvar=rules.filter_mirror_snps.output.pvar,
        psam=rules.filter_mirror_snps.output.psam,
        snps_to_keep=rules.select_best_snps.output,
    output:
        pgen=temp(ws_path(FILTER_MULTIALLELIC_PREFIX + ".pgen")),
        pvar=ws_path(FILTER_MULTIALLELIC_PREFIX + ".pvar"),
        psam=ws_path(FILTER_MULTIALLELIC_PREFIX + ".psam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.filter_mirror_snps.params.prefix,
        prefix=ws_path(FILTER_MULTIALLELIC_PREFIX),
    shell:
        """plink2 \
        --pfile {params.pfile} \
        --extract {input.snps_to_keep} \
        --make-pgen \
        --out {params.prefix} \
        --threads {resources.threads} \
        --memory 19000 'require'
        """


FILTER_VAR_PREFIX = "pgen/qc/{chrom}.impute_recoded_selected_sample_filtered_var"


rule filter_var:
    input:
        pgen=branch(
            lookup(dpath="run/remove_multiallelic", within=config),
            then=rules.filter_multiallelic_var.output.pgen,
            otherwise=rules.filter_mirror_snps.output.pgen,
        ),
        pvar=branch(
            lookup(dpath="run/remove_multiallelic", within=config),
            then=rules.filter_multiallelic_var.output.pvar,
            otherwise=rules.filter_mirror_snps.output.pvar,
        ),
        psam=branch(
            lookup(dpath="run/remove_multiallelic", within=config),
            then=rules.filter_multiallelic_var.output.psam,
            otherwise=rules.filter_mirror_snps.output.psam,
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
            lookup(dpath="run/remove_multiallelic", within=config),
            then=rules.filter_multiallelic_var.params.prefix,
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