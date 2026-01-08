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
        echo "\n\n";
        cat {params.basedir}/../README.md >> {output};
        """
