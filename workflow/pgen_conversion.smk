from snakemake.utils import min_version
from pathlib import Path

##### set minimum snakemake version #####
min_version("8.4.1")


configfile: "config/config.yaml"


include: "rules/common.smk"

def get_pgen2(stem=False):
    if stem:
        return str(
            Path(config.get("pgen_dest_path"), Path(config.get("pgen_template2")).stem)
        )
    return str(Path(config.get("pgen_dest_path"), config.get("pgen_template2")))



if config.get("run").get("delivery"):

    include: "rules/delivery.smk"


rule all:
    input:
        #get_final_output(),
        expand(ws_path("updated_allele/interval_imputed_info70_{chrom}.bed"), chrom=[i for i in range(6, 7)]),


rule pgen2bed:
    input:
        get_pgen2(),
    #     ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_{chrom}.pgen"),
    #     ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_{chrom}.pvar"),
    #     ws_path("pgen/impute_recoded_selected_sample_filter_hq_var_{chrom}.psam"),
    output:
        ws_path("plinkFormat/interval_imputed_info70_{chrom}.bed"),
        ws_path("plinkFormat/interval_imputed_info70_{chrom}.bim"),
        ws_path("plinkFormat/interval_imputed_info70_{chrom}.fam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=get_pgen2(stem=True),
        prefix=ws_path("plinkFormat/interval_imputed_info70_{chrom}"),
    shell:
        """
        plink2 \
            --pfile {params.pfile} \
            --make-bed  \
            --alt1-allele 'force' {params.pfile}.pvar 4 3 \
            --out {params.prefix} \
            --threads {resources.threads} \
            --memory 90000 'require'
        """

