rule generate_sample_filtering_report:
    input:
        # Input files from different stages
        original_psam=rules.recode_pgen.output.psam,  # psam file
        filtered_psam=rules.select_samples.output.psam,  # psam file
    output:
        ws_path("pgen/reports/{chrom}_sample_filtering_report.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wildcards, attempt: attempt * 60,
    params:
        chrom=lambda wildcards: wildcards.chrom,
        method=get_valid_method(),
        mind=config.get("plink2_dict").get("mind"),
        id_list=config.get("id_list_path"),
    shell:
        """python workflow/scripts/generate_sample_filtering_report.py \
                --original-psam {input.original_psam} \
                --filtered-psam {input.filtered_psam} \
                --id-list {params.id_list} \
                --method {params.method} \
                --mind {params.mind} \
                --chrom {params.chrom} \
                > {output}
            """


rule generate_variant_filtering_report:
    input:
        # Input files from different filtering steps
        original_pvar=rules.select_samples.output.pvar,
        mirror_filtered_pvar=rules.filter_mirror_snps.output[1],
        problematic_filtered_pvar=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.filter_problematic_snps.output[1],
            otherwise=rules.filter_mirror_snps.output[1],
        ),
        final_pvar=rules.filter_var.output.pvar,
        mirror_snps_list=rules.get_mirror_snps.output,
        problematic_snps_list=branch(
            lookup(dpath="run/filter_problematic_snps", within=config),
            then=rules.sanitize_problematic_snps.output,
            otherwise="",
        ),
    output:
        ws_path("pgen/reports/{chrom}_variant_filtering_report.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wildcards, attempt: attempt * 60,
    params:
        chrom=lambda wildcards: wildcards.chrom,
    shell:
        """python workflow/scripts/generate_variant_filtering_report.py \
--original-pvar {input.original_pvar} \
--mirror-filtered-pvar {input.mirror_filtered_pvar} \
--problematic-filtered-pvar {input.problematic_filtered_pvar} \
--final-pvar {input.final_pvar} \
--mirror-snps-list {input.mirror_snps_list} \
--problematic-snps-list {input.problematic_snps_list} \
--chrom {params.chrom} \
> {output}
"""


rule generate_imputation_quality_report:
    input:
        # Input files from different filtering steps
        pre_filter_pvar=rules.filter_var.output.pvar,
        post_filter_pvar=branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": rules.filter_var.output.pvar,
                "info_score": rules.filter_hq_variants.output.pvar,
                "minimac3": rules.filter_by_minimac3.output.pvar,
            },
        ),
    output:
        ws_path("pgen/reports/{chrom}_imputation_quality_report.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        chrom=lambda wildcards: wildcards.chrom,
        threshold_used=branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": rules.filter_var.output.pvar,
                "info_score": config.get("INFO_score"),
                "minimac3": config.get("plink2_dict").get("minimac3-r2-filter"),
            },
        ),
        filtering_method=branch(
            lookup(dpath="run/filter_by_imputation_quality", within=config),
            cases={
                "none": "none",
                "info_score": "INFO score filtering",
                "minimac3": "Minimac3 R2 filtering",
            },
        ),
    shell:
        """python workflow/scripts/generate_imputation_quality_report.py \
--pre-filter-pvar {input.pre_filter_pvar} \
--post-filter-pvar {input.post_filter_pvar} \
--threshold-used {params.threshold_used} \
--filtering-method {params.filtering_method} \
--chrom {params.chrom} \
> {output}
"""


rule generate_chromosome_summary_report:
    input:
        # Collect all chromosome-specific reports
        variant_reports=expand(
            rules.generate_sample_filtering_report.output,
            chrom=get_chromosomes(),
        ),
        sample_reports=expand(
            rules.generate_variant_filtering_report.output,
            chrom=get_chromosomes(),
        ),
        imputation_reports=expand(
            rules.generate_imputation_quality_report.output,
            chrom=get_chromosomes(),
        ),
    output:
        txt=ws_path("pgen/reports/all_chromosomes_filtering_summary_report.txt"),
        tsv=ws_path("pgen/reports/all_chromosomes_filtering_summary_report.tsv"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 10,
    shell:
        """python workflow/scripts/generate_chromosome_summary_report.py \
{output.txt} \
{input.sample_reports} \
{input.variant_reports} \
{input.imputation_reports} \
"""


rule generate_harmonization_summary_report:
    input:
        update_id_log=expand(
            rules.update_pgen_id.log,
            chrom=get_chromosomes(),
        ),
        update_alleles_log=expand(
            rules.update_pgen_alleles.log,
            chrom=get_chromosomes(),
        ),
    output:
        report=ws_path("pgen/reports/all_chromosomes_harmonization_summary_report.txt"),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wc, attempt: attempt * 10,
    shell:
        """python workflow/scripts/generate_harmonization_summary_report.py \
{output.report} \
{input.update_id_log} \
{input.update_alleles_log} \
"""
# ---------------------------------------------------------------------
# Full stage QC report
# ---------------------------------------------------------------------

QC_STAGES = [
    "raw_input",
    "sample_selection",
    "mirror_filtering",
]

# Optional problematic-SNP filtering
if config.get("run", {}).get("filter_problematic_snps"):
    QC_STAGES.append("problematic_filtering")

# Optional multiallelic filtering
if config.get("run", {}).get("remove_multiallelic"):
    QC_STAGES.append("multiallelic_filtering")

QC_STAGES.extend(
    [
        "variant_qc",
        "imputation_quality",
        "harmonization",
    ]
)


def get_post_problematic_file(wildcards, extension):
    """
    Return the dataset after mirror/problematic SNP filtering.
    """

    if config.get("run", {}).get("filter_problematic_snps"):
        path = getattr(
            rules.filter_problematic_snps.output,
            extension,
        )
    else:
        path = getattr(
            rules.filter_mirror_snps.output,
            extension,
        )

    return str(path).format(chrom=wildcards.chrom)


def get_pre_variant_qc_file(wildcards, extension):
    """
    Return the dataset immediately before filter_var.
    """

    if config.get("run", {}).get("remove_multiallelic"):
        path = getattr(
            rules.filter_multiallelic_var.output,
            extension,
        )

        return str(path).format(chrom=wildcards.chrom)

    return get_post_problematic_file(
        wildcards,
        extension,
    )


def get_post_imputation_file(wildcards, extension):
    """
    Return the dataset after the configured imputation-quality step.
    """

    filtering_method = config.get("run", {}).get(
        "filter_by_imputation_quality"
    )

    if filtering_method == "none":
        path = getattr(
            rules.filter_var.output,
            extension,
        )

    elif filtering_method == "info_score":
        path = getattr(
            rules.filter_hq_variants.output,
            extension,
        )

    elif filtering_method == "minimac3":
        path = getattr(
            rules.filter_by_minimac3.output,
            extension,
        )

    else:
        raise ValueError(
            "Unknown filter_by_imputation_quality value: "
            f"{filtering_method}"
        )

    return str(path).format(chrom=wildcards.chrom)


def get_stage_before_file(wildcards, extension):
    """
    Return the dataset immediately BEFORE each report stage.
    """

    stage = wildcards.stage

    if stage == "raw_input":
        # For raw_input there is no true "before".
        # We return the same file and set before/removed to NA
        # in generate_full_report.py.
        path = getattr(
            rules.recode_pgen.output,
            extension,
        )

    elif stage == "sample_selection":
        path = getattr(
            rules.recode_pgen.output,
            extension,
        )

    elif stage == "mirror_filtering":
        path = getattr(
            rules.select_samples.output,
            extension,
        )

    elif stage == "problematic_filtering":
        path = getattr(
            rules.filter_mirror_snps.output,
            extension,
        )

    elif stage == "multiallelic_filtering":
        return get_post_problematic_file(
            wildcards,
            extension,
        )

    elif stage == "variant_qc":
        return get_pre_variant_qc_file(
            wildcards,
            extension,
        )

    elif stage == "imputation_quality":
        path = getattr(
            rules.filter_var.output,
            extension,
        )

    elif stage == "harmonization":
        return get_post_imputation_file(
            wildcards,
            extension,
        )

    else:
        raise ValueError(
            f"Unknown QC stage: {stage}"
        )

    return str(path).format(chrom=wildcards.chrom)


def get_stage_after_file(wildcards, extension):
    """
    Return the dataset immediately AFTER each report stage.
    """

    stage = wildcards.stage

    if stage == "raw_input":
        path = getattr(
            rules.recode_pgen.output,
            extension,
        )

    elif stage == "sample_selection":
        path = getattr(
            rules.select_samples.output,
            extension,
        )

    elif stage == "mirror_filtering":
        path = getattr(
            rules.filter_mirror_snps.output,
            extension,
        )

    elif stage == "problematic_filtering":
        path = getattr(
            rules.filter_problematic_snps.output,
            extension,
        )

    elif stage == "multiallelic_filtering":
        path = getattr(
            rules.filter_multiallelic_var.output,
            extension,
        )

    elif stage == "variant_qc":
        path = getattr(
            rules.filter_var.output,
            extension,
        )

    elif stage == "imputation_quality":
        return get_post_imputation_file(
            wildcards,
            extension,
        )

    elif stage == "harmonization":
        path = getattr(
            rules.update_pgen_alleles.output,
            extension,
        )

    else:
        raise ValueError(
            f"Unknown QC stage: {stage}"
        )

    return str(path).format(chrom=wildcards.chrom)


def get_stage_qc_prefix(wildcards):
    """
    Return the PLINK --pfile prefix for the dataset after each stage.
    """

    pgen = get_stage_after_file(
        wildcards,
        "pgen",
    )

    if not pgen.endswith(".pgen"):
        raise ValueError(
            f"Expected .pgen file, got: {pgen}"
        )

    return pgen[:-5]


# ---------------------------------------------------------------------
# Generate PLINK dosage metrics for every chromosome x stage
# ---------------------------------------------------------------------

rule generate_stage_qc_plink_metrics:
    input:
        pgen=lambda wc: get_stage_after_file(
            wc,
            "pgen",
        ),
        pvar=lambda wc: get_stage_after_file(
            wc,
            "pvar",
        ),
        psam=lambda wc: get_stage_after_file(
            wc,
            "psam",
        ),
    output:
        pgen_info=temp(
            ws_path(
                "pgen/reports/stage_qc/"
                "{chrom}.{stage}.pgen_info.log"
            )
        ),
        vmiss=temp(
            ws_path(
                "pgen/reports/stage_qc/"
                "{chrom}.{stage}.missing.vmiss"
            )
        ),
        missing_log=temp(
            ws_path(
                "pgen/reports/stage_qc/"
                "{chrom}.{stage}.missing.log"
            )
        ),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wildcards, attempt: attempt * 60,
    params:
        pfile=get_stage_qc_prefix,

        pgen_info_prefix=lambda wc: ws_path(
            "pgen/reports/stage_qc/"
            f"{wc.chrom}.{wc.stage}.pgen_info"
        ),

        missing_prefix=lambda wc: ws_path(
            "pgen/reports/stage_qc/"
            f"{wc.chrom}.{wc.stage}.missing"
        ),
    shell:
        """
        mkdir -p $(dirname {output.pgen_info})

        plink2 \
            --pfile {params.pfile} \
            --pgen-info \
            --out {params.pgen_info_prefix}

        plink2 \
            --pfile {params.pfile} \
            --missing variant-only vcols=nmissdosage,nobs \
            --out {params.missing_prefix}
        """


# ---------------------------------------------------------------------
# Generate one row per chromosome x stage
# ---------------------------------------------------------------------

rule generate_stage_qc_row:
    input:
        before_pvar=lambda wc: get_stage_before_file(
            wc,
            "pvar",
        ),

        after_pvar=lambda wc: get_stage_after_file(
            wc,
            "pvar",
        ),

        psam=lambda wc: get_stage_after_file(
            wc,
            "psam",
        ),

        pgen_info=(
            rules.generate_stage_qc_plink_metrics.output.pgen_info
        ),

        vmiss=(
            rules.generate_stage_qc_plink_metrics.output.vmiss
        ),
    output:
        tsv=temp(
            ws_path(
                "pgen/reports/stage_qc/"
                "{chrom}.{stage}.tsv"
            )
        ),
    container:
        "docker://ghcr.io/ht-diva/containers/python_ds:406993"
    resources:
        runtime=lambda wildcards, attempt: attempt * 10,
    shell:
        """
        python workflow/scripts/generate_full_report.py \
            --before-pvar {input.before_pvar} \
            --after-pvar {input.after_pvar} \
            --psam {input.psam} \
            --pgen-info {input.pgen_info} \
            --vmiss {input.vmiss} \
            --chromosome {wildcards.chrom} \
            --stage {wildcards.stage} \
            --output {output.tsv}
        """


# ---------------------------------------------------------------------
# Combine all rows into one report
# ---------------------------------------------------------------------

rule generate_stage_qc_report:
    input:
        rows=expand(
            ws_path(
                "pgen/reports/stage_qc/"
                "{chrom}.{stage}.tsv"
            ),
            chrom=get_chromosomes(),
            stage=QC_STAGES,
        ),
    output:
        tsv=ws_path(
            "pgen/reports/"
            "all_chromosomes_stage_qc_report.tsv"
        ),
    resources:
        runtime=lambda wildcards, attempt: attempt * 10,
    shell:
        """
        awk 'FNR == 1 && NR != 1 {{next}} {{print}}' \
            {input.rows} > {output.tsv}
        """

rule write_readme:
    output:
        ws_path("README.txt"),
    params:
        basedir=workflow.basedir,
    shell:
        """echo "\n## Traceability \n" >> {output};
        echo "These files has been produced by " >> {output};
        echo "Remote origin: $(git config --get remote.origin.url)" >> {output};
        echo "Last commit: $(git log -1 --pretty="%H %s")" >> {output};
        echo "\n\n" >> {output};
        cat {params.basedir}/../README.md >> {output};
        """
