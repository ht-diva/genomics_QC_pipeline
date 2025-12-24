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
