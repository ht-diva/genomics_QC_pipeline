def get_pgen(stem=False):
    if stem:
        return str(
            Path(config.get("pgen_src_path"), Path(config.get("pgen_template")).stem)
        )
    return str(Path(config.get("pgen_src_path"), config.get("pgen_template")))


def get_pvar(stem=False):
    if stem:
        return str(
            Path(config.get("pgen_src_path"), Path(config.get("pvar_template")).stem)
        )
    return str(Path(config.get("pgen_src_path"), config.get("pvar_template")))


def ws_path(file_path):
    return str(Path(config.get("workspace_path"), file_path))


def dest_path(file_path):
    return str(Path(config.get("dest_path"), file_path))


def get_final_output():
    final_output = []
    final_output.append(ws_path("pgen/recode_rsids.txt")),
    final_output.append(ws_path("pgen/pseudo_biallelic.txt")),
    final_output.extend(
        expand(
            ws_path("pgen/impute_dedup_{chrom}.info"),
            chrom=[i for i in range(1, 23)],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_{chrom}.{ext}"
            ),
            chrom=[i for i in range(1, 23)],
            ext=["pgen", "pvar", "psam"],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "pgen/qc_recoded/impute_recoded_selected_sample_filter_hq_var_all.{ext}"
            ),
            ext=["pgen", "pvar", "psam"],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.{ext}"
            ),
            chrom=[i for i in range(1, 23)],
            ext=["pgen", "pvar", "psam"],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "pgen/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.{ext}"
            ),
            ext=["pgen", "pvar", "psam"],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_{chrom}.{ext}"
            ),
            chrom=[i for i in range(1, 23)],
            ext=["bed", "bim", "fam"],
        )
    ),
    final_output.extend(
        expand(
            ws_path(
                "bed/qc_recoded_harmonised/impute_recoded_selected_sample_filter_hq_var_new_id_alleles_all.{ext}"
            ),
            ext=["bed", "bim", "fam"],
        )
    ),

    if config.get("run").get("delivery"):
        final_output.append(dest_path("pgen/.tables_delivery.done")),

        final_output.append(dest_path("pgen/.qc_recoded_all_delivery.done")),
        final_output.append(dest_path("pgen/.qc_recoded_harmonised_all_delivery.done")),

        final_output.extend(
            expand(
                dest_path("pgen/.header_info_{chrom}.done"),
                chrom=[i for i in range(1, 23)],
            )
        ),
        final_output.extend(
            expand(
                dest_path("pgen/.qc_recoded_{chrom}_delivery.done"),
                chrom=[i for i in range(1, 23)],
            )
        ),
        final_output.extend(
            expand(
                dest_path("pgen/.qc_recoded_harmonised_{chrom}_delivery.done"),
                chrom=[i for i in range(1, 23)],
            )
        ),

    return final_output
