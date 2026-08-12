rule list_rs:
    input:
        directory_path=expand(get_pvar(), chrom=get_chromosomes()),
    output:
        list_merge_rsid=ws_path("pgen/merge_rsids.txt"),
        list_recode_rsid=ws_path("pgen/recode_rsids.txt"),
        list_pseudo_biallelic_var=ws_path("pgen/pseudo_biallelic_var.txt"),
        list_pseudo_biallelic=ws_path("pgen/pseudo_biallelic.txt"),
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    shell:
        """
tail -n +2 -q {input.directory_path} > {output.list_merge_rsid} && \
awk -F'\t' '$2 in a{{if(a[$2])print a[$2];a[$2]=""; print; next}} {{a[$2]=$0}}' {output.list_merge_rsid} > {output.list_pseudo_biallelic_var} && \
awk -v OFS="\t" 'BEGIN {{print "RSID", "ID"}} {{print $3, $1":"$2":"$4":"$5}}' {output.list_pseudo_biallelic_var} > {output.list_pseudo_biallelic} && \
awk -v OFS="\t" 'BEGIN {{print "SNPID", "rsID", "CHR", "POS", "NEA", "EA"}} {{print $1":"$2":"$4":"$5, $3, $1, $2, $4, $5}}' {output.list_merge_rsid} > {output.list_recode_rsid}
"""


rule header_info:
    input:
        pgen=get_pgen(),
    output:
        info=ws_path("pgen/{chrom}_impute.info"),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    shell:
        """PFILE=$(echo "{input}" | sed 's/\.[^.]*$//');
plink2 \
--pfile $PFILE \
--pgen-info \
--memory 3000 \
--threads {threads} &> {output.info}
"""
