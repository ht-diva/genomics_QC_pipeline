def get_final_output():
    final_output = []

    final_output.append(rules.list_rs.output.list_recode_rsid),
    final_output.append(rules.list_rs.output.list_pseudo_biallelic),
    final_output.extend(
        expand(
            rules.header_info.output.info,
            chrom=get_chromosomes(),
        )
    ),
    final_output.extend(
        [
            rules.merge_qc_harmonised_pgen.output.pgen,
            rules.merge_qc_harmonised_pgen.output.psam,
            rules.merge_qc_harmonised_pgen.output.pvar,
        ]
    ),
    final_output.append(
        rules.freq_qc_harmonised_pgen.output.afreq,
    ),
    final_output.extend(
        [
            rules.merge_qc_harmonised_bed.output.bed,
            rules.merge_qc_harmonised_bed.output.bim,
            rules.merge_qc_harmonised_bed.output.fam,
        ]
    ),
    # add reports
    final_output.append(rules.generate_chromosome_summary_report.output.tsv),
    final_output.append(rules.generate_chromosome_summary_report.output.txt),
    final_output.append(rules.generate_harmonization_summary_report.output.report)

    if config.get("run").get("delivery"):
        final_output.append(rules.write_readme.output),
        final_output.extend(
            expand(
                rules.sync_header_info.output,
                chrom=get_chromosomes(),
            )
        ),
        final_output.append(rules.sync_tables.output),

        final_output.append(rules.sync_pfiles_qc_harmonised_all.output),
        final_output.append(rules.sync_pfiles_qc_harmonised_all_freq.output),
        final_output.extend(
            expand(
                rules.sync_pfiles_qc_harmonised_c.output,
                chrom=get_chromosomes(),
            )
        ),

        final_output.append(rules.sync_bedfiles_all.output),
        final_output.extend(
            expand(
                rules.sync_bedfiles_c.output,
                chrom=get_chromosomes(),
            )
        ),
        final_output.append(rules.sync_reports.output)

    return final_output
