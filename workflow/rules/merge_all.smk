MERGE_NEW_ID_ALLELES_PREFIX = "pgen/qc_harmonised/all_chroms_qced_harmonized"


rule merge_qc_harmonised_pgen:
    input:
        expand(
            rules.update_pgen_alleles.output,
            chrom=get_chromosomes(),
        ),
    output:
        pgen=ws_path(MERGE_NEW_ID_ALLELES_PREFIX + ".pgen"),
        pvar=ws_path(MERGE_NEW_ID_ALLELES_PREFIX + ".pvar"),
        psam=ws_path(MERGE_NEW_ID_ALLELES_PREFIX + ".psam"),
        file_list=ws_path("pgen/qc_harmonised/merge_list_qced_harmonized.txt"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        base_prefix=expand(
            rules.update_pgen_alleles.params.prefix + ".pgen",
            chrom=get_chromosomes(),
        ),
        pmerge=ws_path(MERGE_NEW_ID_ALLELES_PREFIX),
    shell:
        """
 ls -1 {params.base_prefix} | cut -f1 -d"." > {output.file_list} \
 && plink2 --pmerge-list {output.file_list} \
 --make-pgen \
 --out {params.pmerge} \
 --threads {resources.threads} \
 --memory 90000 'require'
"""


FREQ_NEW_ID_ALLELES_PREFIX = "pgen/qc_harmonised/all_chroms_qced_harmonized_freq"


rule freq_qc_harmonised_pgen:
    input:
        rules.merge_qc_harmonised_pgen.output,
    output:
        afreq=ws_path(FREQ_NEW_ID_ALLELES_PREFIX + ".afreq"),
        log=ws_path(FREQ_NEW_ID_ALLELES_PREFIX + ".log"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=ws_path(MERGE_NEW_ID_ALLELES_PREFIX),
        prefix=ws_path(FREQ_NEW_ID_ALLELES_PREFIX),
    shell:
        """plink2 \
--pfile {params.pfile} \
 --freq \
 --out {params.prefix} \
 --threads {resources.threads} \
 --memory 90000 'require'
"""
