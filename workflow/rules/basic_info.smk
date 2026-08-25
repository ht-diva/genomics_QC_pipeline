VALIDATE_INPUT_PREFIX = "pgen/validation/{chrom}_imputed_input"


VALIDATE_INPUT_PREFIX = "pgen/validation/{chrom}_imputed_input"


rule validate_imputed_input:
    input:
        pgen=get_pgen(),
        pvar=get_pvar(),
        psam=get_pgen(stem=True) + ".psam",
    output:
        validate_log=ws_path(
            VALIDATE_INPUT_PREFIX + ".validate.log"
        ),
        pgen_info=ws_path(
            VALIDATE_INPUT_PREFIX + ".pgen_info.txt"
        ),
        dosage_log=ws_path(
            VALIDATE_INPUT_PREFIX + ".dosage_missingness.log"
        ),
        ok=touch(
            ws_path(VALIDATE_INPUT_PREFIX + ".ok")
        ),
    container:
        "docker://quay.io/biocontainers/plink2:2.00a5--h4ac6f70_0"
    threads:
        8
    resources:
        runtime=lambda wc, attempt: attempt * 60,
    params:
        pfile=get_pgen(stem=True),
        validate_prefix=ws_path(
            VALIDATE_INPUT_PREFIX + ".validate"
        ),
        dosage_prefix=ws_path(
            VALIDATE_INPUT_PREFIX + ".dosage_missingness"
        ),
        max_missing_dosage_rate=config.get(
            "input_validation", {}
        ).get(
            "max_missing_dosage_rate", 0.0
        ),
    shell:
        r"""
        set -euo pipefail

        # Create the output directory if it does not exist
        mkdir -p "$(dirname {output.validate_log})"

        echo "Validating chromosome {wildcards.chrom}..."

        # ---------------------------------------------------------
        # 1. Validate PGEN integrity
        # ---------------------------------------------------------
        plink2 \
            --pfile {params.pfile} \
            --validate \
            --out {params.validate_prefix} \
            --memory 3000 \
            --threads {threads}

        echo "PGEN integrity validation: PASS" \
            >> {output.validate_log}

        # ---------------------------------------------------------
        # 2. Check that the PVAR contains at least one variant
        # ---------------------------------------------------------
        if ! awk '
            !/^#/ && NF > 0 {{
                found = 1
                exit
            }}

            END {{
                exit !found
            }}
        ' {input.pvar}; then
            echo "ERROR: chromosome {wildcards.chrom}: no variants found in the PVAR file." >&2
            exit 1
        fi

        echo "PVAR non-empty validation: PASS" \
            >> {output.validate_log}

        # ---------------------------------------------------------
        # 3. Validate autosomal chromosome labels
        # ---------------------------------------------------------
        awk -v expected="{wildcards.chrom}" '
            BEGIN {{
                expected_chr = tolower(expected)
                sub(/^chr/, "", expected_chr)

                # The expected chromosome must be between 1 and 22
                if (
                    expected_chr !~ /^[0-9]+$/ ||
                    expected_chr < 1 ||
                    expected_chr > 22
                ) {{
                    print "ERROR: expected chromosome is not an autosome: " \
                          expected > "/dev/stderr"
                    exit 1
                }}
            }}

            # Skip headers and empty lines
            /^#/ || NF == 0 {{
                next
            }}

            {{
                chromosome = tolower($1)
                sub(/^chr/, "", chromosome)

                # Every chromosome in the PVAR must be an autosome
                if (
                    chromosome !~ /^[0-9]+$/ ||
                    chromosome < 1 ||
                    chromosome > 22
                ) {{
                    print "ERROR: non-autosomal chromosome found: " $1 \
                          > "/dev/stderr"
                    exit 1
                }}

                # Every chromosome must match the expected chromosome
                if (chromosome != expected_chr) {{
                    print "ERROR: expected chromosome " expected \
                          ", but found " $1 > "/dev/stderr"
                    exit 1
                }}
            }}
        ' {input.pvar}

        echo "Autosomal chromosome validation: PASS" \
            >> {output.validate_log}

        # ---------------------------------------------------------
        # 4. Check that dosage information exists
        # ---------------------------------------------------------
        plink2 \
            --pfile {params.pfile} \
            --pgen-info \
            --memory 3000 \
            --threads {threads} \
            > {output.pgen_info} 2>&1

        if grep -qi \
            "No dosages present" \
            {output.pgen_info}
        then
            echo "ERROR: chromosome {wildcards.chrom}: no dosage information found." >&2
            cat {output.pgen_info} >&2
            exit 1
        fi

        if ! grep -Eqi \
            "dosages present" \
            {output.pgen_info}
        then
            echo "ERROR: chromosome {wildcards.chrom}: could not confirm dosage information." >&2
            cat {output.pgen_info} >&2
            exit 1
        fi

        echo "Dosage information validation: PASS" \
            >> {output.validate_log}

        # ---------------------------------------------------------
        # 5. Check dosage missingness
        # ---------------------------------------------------------
        plink2 \
            --pfile {params.pfile} \
            --genotyping-rate dosage \
            --out {params.dosage_prefix} \
            --memory 3000 \
            --threads {threads}

        rate=$(
            grep -Eio \
                'genotyping rate is (exactly )?[0-9.eE+-]+' \
                {output.dosage_log} \
            | tail -n 1 \
            | awk '{{print $NF}}' \
            || true
        )

        if [ -z "$rate" ]; then
            echo "ERROR: chromosome {wildcards.chrom}: unable to parse dosage genotyping rate." >&2
            cat {output.dosage_log} >&2
            exit 1
        fi

        missing_rate=$(
            awk -v r="$rate" \
                'BEGIN {{printf "%.10f", 1-r}}'
        )

        echo "" >> {output.dosage_log}
        echo "Dosage missingness: $missing_rate" \
            >> {output.dosage_log}
        echo "Maximum allowed:    {params.max_missing_dosage_rate}" \
            >> {output.dosage_log}

        if ! awk \
            -v missing="$missing_rate" \
            -v max="{params.max_missing_dosage_rate}" \
            'BEGIN {{exit !(missing <= max)}}'
        then
            echo "FAIL" >> {output.dosage_log}
            echo "ERROR: chromosome {wildcards.chrom}: dosage missingness exceeds allowed threshold." >&2
            exit 1
        fi

        echo "PASS" >> {output.dosage_log}

        echo "Dosage missingness validation: PASS" \
            >> {output.validate_log}

        echo "Chromosome {wildcards.chrom}: input validation PASSED"
        """

rule list_rs:
    input:
        directory_path=expand(
            get_pvar(),
            chrom=get_chromosomes(),
        ),
        validated=expand(
            rules.validate_imputed_input.output.ok,
            chrom=get_chromosomes(),
        ),
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
