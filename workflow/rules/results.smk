def get_final_output():
    final_output = []

    final_output.append(ws_path("pgen/recode_rsids.txt")),
    final_output.append(ws_path("pgen/pseudo_biallelic.txt")),
    final_output.extend(
        expand(
            rules.header_info.output.info,
            chrom=get_chromosomes(),
        )
    ),
    # final_output.extend(
    #     expand(
    #         ws_path("snp_mapping/{chrom}/snp_mapping/table.snp_mapping.tsv.gz"),
    #         chrom=get_chromosomes(),
    #     )
    # ),
    # final_output.extend(
    #     expand(
    #         ws_path("snp_mapping/{chrom}/outputs/{chrom}/{chrom}.gwaslab.tsv.gz"),
    #         chrom=get_chromosomes(),
    #     )
    # ),
    # if config.get("run").get("filter_by_INFO_score"):
    #     final_output.extend(
    #         expand(
    #             ws_path(
    #                 "pgen/qc_recoded/{chrom}_impute_recoded_selected_sample_filter_hq_var.{ext}"
    #             ),
    #             chrom=get_chromosomes(),
    #             ext=["pgen", "pvar", "psam"],
    #         )
    #     ),
    #     final_output.extend(
    #         expand(
    #             ws_path(
    #                 "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_all.{ext}"
    #             ),
    #             ext=["pgen", "pvar", "psam"],
    #         )
    #     ),
    # final_output.extend(
    #     expand(
    #         rules.update_pgen_alleles.params.prefix + ".{ext}",
    #         chrom=get_chromosomes(),
    #         ext=["pgen", "pvar", "psam"],
    #     )
    # ),
    final_output.extend(
        rules.merge_qc_harmonised_pgen.output,
    ),
    final_output.extend(
        rules.freq_qc_harmonised_pgen.output,
    ),
    # final_output.extend(
    #     expand(
    #         rules.pgen2bed.params.prefix + ".{ext}",
    #         chrom=get_chromosomes(),
    #         ext=["bed", "bim", "fam"],
    #     )
    # ),
    final_output.extend(
        expand(
            rules.merge_qc_harmonised_bed.params.pmerge + ".{ext}",
            ext=["bed", "bim", "fam"],
        )
    ),
    final_output.append(rules.generate_chromosome_summary_report.output)

    if config.get("run").get("delivery"):
        final_output.append(dest_path("README.txt")),
        final_output.extend(
            expand(
                dest_path("pgen/.header_info_{chrom}.done"),
                chrom=get_chromosomes(),
            )
        ),
        final_output.append(dest_path("pgen/.tables_delivery.done")),

        final_output.append(dest_path("pgen/.qc_harmonised_all_delivery.done")),
        final_output.append(dest_path("pgen/.qc_harmonised_all_freq_delivery.done")),
        final_output.extend(
            expand(
                dest_path("pgen/.qc_harmonised_{chrom}_delivery.done"),
                chrom=get_chromosomes(),
            )
        ),

        final_output.append(dest_path("bed/.all_delivery.done")),
        final_output.extend(
            expand(
                dest_path("bed/.{chrom}_delivery.done"),
                chrom=get_chromosomes(),
            )
        ),

    return final_output
