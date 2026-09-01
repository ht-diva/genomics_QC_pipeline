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
        filter_by_imputation_quality=str(
            config.get("run", {}).get(
                "filter_by_imputation_quality",
                "none",
            )
        ).lower(),
    shell:
        r"""
        set -euo pipefail

        # Create the output directory if it does not exist
        mkdir -p "$(dirname "{output.validate_log}")"

        echo "Validating chromosome {wildcards.chrom}..."

        # ---------------------------------------------------------
        # 1. Validate PGEN integrity
        # ---------------------------------------------------------
        plink2 \
            --pfile "{params.pfile}" \
            --validate \
            --out "{params.validate_prefix}" \
            --memory 3000 \
            --threads {threads}

        echo "PGEN integrity validation: PASS" \
            >> "{output.validate_log}"

        # ---------------------------------------------------------
        # 2. Check that the PVAR contains at least one variant
        # ---------------------------------------------------------
        n_variants=$(
            grep -vcE '^(#|[[:space:]]*$)' "{input.pvar}" \
            || true
        )

        if [ "$n_variants" -eq 0 ]; then
            echo "ERROR: chromosome {wildcards.chrom}: no variants found in the PVAR file." >&2
            exit 1
        fi

        echo "Number of variants: $n_variants" \
            >> "{output.validate_log}"

        echo "PVAR non-empty validation: PASS" \
            >> "{output.validate_log}"

        # ---------------------------------------------------------
        # 3. Validate autosomal chromosome labels
        # ---------------------------------------------------------

        # Normalize the expected chromosome label
        expected_chr=$(
            printf '%s\n' "{wildcards.chrom}" \
            | tr '[:upper:]' '[:lower:]' \
            | sed 's/^chr//'
        )

        # The expected chromosome must be between 1 and 22
        if ! printf '%s\n' "$expected_chr" \
            | grep -Eq '^([1-9]|1[0-9]|2[0-2])$'
        then
            echo "ERROR: chromosome {wildcards.chrom} is not autosomal." >&2
            exit 1
        fi

        # Find the first PVAR chromosome that does not match
        unexpected_chr=$(
            grep -vE '^(#|[[:space:]]*$)' "{input.pvar}" \
            | cut -f1 \
            | tr '[:upper:]' '[:lower:]' \
            | sed 's/^chr//' \
            | grep -vx "$expected_chr" \
            | head -n 1 \
            || true
        )

        if [ -n "$unexpected_chr" ]; then
            echo "ERROR: expected chromosome $expected_chr, but found $unexpected_chr." >&2
            exit 1
        fi

        echo "Autosomal chromosome validation: PASS" \
            >> "{output.validate_log}"

        # ---------------------------------------------------------
        # 4. Check that dosage information exists
        # ---------------------------------------------------------
        plink2 \
            --pfile "{params.pfile}" \
            --pgen-info \
            --memory 3000 \
            --threads {threads} \
            > "{output.pgen_info}" 2>&1

        if grep -Fqi \
            "No dosages present" \
            "{output.pgen_info}"
        then
            echo "ERROR: chromosome {wildcards.chrom}: no dosage information found." >&2
            cat "{output.pgen_info}" >&2
            exit 1
        fi

        if ! grep -Eqi \
            "dosages present" \
            "{output.pgen_info}"
        then
            echo "ERROR: chromosome {wildcards.chrom}: could not confirm dosage information." >&2
            cat "{output.pgen_info}" >&2
            exit 1
        fi

        echo "Dosage information validation: PASS" \
            >> "{output.validate_log}"

        # ---------------------------------------------------------
        # 5. Check explicitly phased dosages for MINIMAC3 filtering
        # ---------------------------------------------------------
        if [ "{params.filter_by_imputation_quality}" = "minimac3" ]; then
            if ! grep -Fqi \
                "Explicitly phased dosages present" \
                "{output.pgen_info}"
            then
                echo "ERROR: chromosome {wildcards.chrom}: MINIMAC3 filtering requires explicitly phased dosages." >&2
                echo "Expected PLINK --pgen-info to report:" >&2
                echo "  Explicitly phased dosages present" >&2
                cat "{output.pgen_info}" >&2
                exit 1
            fi

            echo "MINIMAC3 explicitly phased dosage validation: PASS" \
                >> "{output.validate_log}"
        else
            echo "MINIMAC3 explicitly phased dosage validation: NOT REQUIRED" \
                >> "{output.validate_log}"
        fi

        # ---------------------------------------------------------
        # 6. Check dosage missingness
        # ---------------------------------------------------------
        plink2 \
            --pfile "{params.pfile}" \
            --genotyping-rate dosage \
            --out "{params.dosage_prefix}" \
            --memory 3000 \
            --threads {threads}

        rate=$(
            grep -Eio \
                'genotyping rate is (exactly )?[0-9.eE+-]+' \
                "{output.dosage_log}" \
            | tail -n 1 \
            | awk '{{print $NF}}' \
            || true
        )

        if [ -z "$rate" ]; then
            echo "ERROR: chromosome {wildcards.chrom}: unable to parse dosage genotyping rate." >&2
            cat "{output.dosage_log}" >&2
            exit 1
        fi

        missing_rate=$(
            awk -v r="$rate" \
                'BEGIN {{printf "%.10f", 1-r}}'
        )

        echo "" >> "{output.dosage_log}"
        echo "Dosage missingness: $missing_rate" \
            >> "{output.dosage_log}"
        echo "Maximum allowed:    {params.max_missing_dosage_rate}" \
            >> "{output.dosage_log}"

        if ! awk \
            -v missing="$missing_rate" \
            -v max="{params.max_missing_dosage_rate}" \
            'BEGIN {{exit !(missing <= max)}}'
        then
            echo "FAIL" >> "{output.dosage_log}"
            echo "ERROR: chromosome {wildcards.chrom}: dosage missingness exceeds allowed threshold." >&2
            exit 1
        fi

        echo "PASS" >> "{output.dosage_log}"

        echo "Dosage missingness validation: PASS" \
            >> "{output.validate_log}"

        echo "Chromosome {wildcards.chrom}: input validation PASSED"
        """