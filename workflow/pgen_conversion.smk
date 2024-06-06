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

