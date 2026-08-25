def get_final_output():
    final_output = []

    # README
    final_output.append(
        rules.write_readme.output
    )

    # Input PGEN validation reports
    final_output.extend(
        expand(
            rules.validate_imputed_input.output.validate_log,
            chrom=get_chromosomes(),
        )
    )

    final_output.extend(
        expand(
            rules.validate_imputed_input.output.pgen_info,
            chrom=get_chromosomes(),
        )
    )

    final_output.extend(
        expand(
            rules.validate_imputed_input.output.dosage_log,
            chrom=get_chromosomes(),
        )
    )

    # Final harmonized PGEN files
    final_output.extend(
        [
            rules.merge_qc_harmonised_pgen.output.pgen,
            rules.merge_qc_harmonised_pgen.output.psam,
            rules.merge_qc_harmonised_pgen.output.pvar,
        ]
    )

    # Final allele-frequency file
    final_output.append(
        rules.freq_qc_harmonised_pgen.output.afreq
    )

    # Final harmonized BED files
    final_output.extend(
        [
            rules.merge_qc_harmonised_bed.output.bed,
            rules.merge_qc_harmonised_bed.output.bim,
            rules.merge_qc_harmonised_bed.output.fam,
        ]
    )

    # QC reports
    final_output.extend(
        [
            rules.generate_chromosome_summary_report.output.tsv,
            rules.generate_chromosome_summary_report.output.txt,
            rules.generate_harmonization_summary_report.output.report,
            rules.generate_stage_qc_report.output.tsv,
        ]
    )

    # Optional delivery
    if config.get("run", {}).get("delivery"):
        final_output.extend(
            [
                rules.sync_pfiles_qc_harmonised_all.output,
                rules.sync_pfiles_qc_harmonised_all_freq.output,
                rules.sync_bedfiles_all.output,
                rules.sync_reports.output,
                rules.sync_readme.output,
            ]
        )

        final_output.extend(
            expand(
                rules.sync_pfiles_qc_harmonised_c.output,
                chrom=get_chromosomes(),
            )
        )

        final_output.extend(
            expand(
                rules.sync_bedfiles_c.output,
                chrom=get_chromosomes(),
            )
        )

    return final_output