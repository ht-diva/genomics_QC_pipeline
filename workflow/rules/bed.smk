PGEN2BED_PREFIX = "bed/qc_harmonised/{chrom}_qced_new_id_alleles"


rule pgen2bed:
    input:
        rules.update_pgen_alleles.output,
    output:
        bed=ws_path(PGEN2BED_PREFIX + ".bed"),
        bim=ws_path(PGEN2BED_PREFIX + ".bim"),
        fam=ws_path(PGEN2BED_PREFIX + ".fam"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=rules.update_pgen_alleles.params.prefix,
        prefix=ws_path(PGEN2BED_PREFIX),
    shell:
        """plink2 \
--pfile {params.pfile} \
--hard-call-threshold 0.49999999 \
--ref-allele 'force' {params.pfile}.pvar 4 3 \
--alt1-allele {params.pfile}.pvar 5 3 \
--make-bed  \
--out {params.prefix} \
--threads {resources.threads} \
--memory 1900 'require'
"""


MERGE_QC_HARMONISED_BED_PREFIX = "bed/qc_harmonised/all_qced_new_id_alleles"


rule merge_qc_harmonised_bed:
    input:
        expand(rules.pgen2bed.output, chrom=get_chromosomes()),
    output:
        bed=ws_path(MERGE_QC_HARMONISED_BED_PREFIX + ".bed"),
        bim=ws_path(MERGE_QC_HARMONISED_BED_PREFIX + ".bim"),
        fam=ws_path(MERGE_QC_HARMONISED_BED_PREFIX + ".fam"),
        file_list=ws_path("bed/qc_harmonised/merge_list_new_id_alleles.txt"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        base_prefix=expand(
            rules.pgen2bed.params.prefix + ".bed",
            chrom=get_chromosomes(),
        ),
        pmerge=ws_path(MERGE_QC_HARMONISED_BED_PREFIX),
    shell:
        """
 ls -1 {params.base_prefix} | cut -f1 -d"." > {output.file_list} \
 && plink2 \
 --pmerge-list {output.file_list} bfile \
 --make-bed \
 --out {params.pmerge} \
 --threads {resources.threads} \
 --memory 90000 'require'
"""
