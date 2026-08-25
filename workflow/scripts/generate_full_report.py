#!/usr/bin/env python3

import argparse


def count_data_lines(path):
    """
    Count non-empty, non-header lines.

    For a PVAR this corresponds to the number of variants.
    For a PSAM this corresponds to the number of samples.
    """
    count = 0

    with open(path) as handle:
        for line in handle:
            line = line.strip()

            if not line:
                continue

            if line.startswith("#"):
                continue

            count += 1

    return count


def check_dosages(pgen_info_path):
    """
    Determine whether dosage information is present.

    Returns:
        True  -> dosages present
        False -> no dosages present
        None  -> could not determine
    """

    with open(pgen_info_path) as handle:
        text = handle.read().lower()

    if "no dosages present" in text:
        return False

    if "dosages present" in text:
        return True

    return None


def read_dosage_missingness(vmiss_path):
    """
    Sum dosage missingness across all variants.
    """

    total_missing = 0
    total_observations = 0

    with open(vmiss_path) as handle:
        header = None

        for line in handle:
            line = line.strip()

            if not line:
                continue

            fields = line.split()

            if header is None:
                header = [
                    field.lstrip("#")
                    for field in fields
                ]

                if "MISSING_DOSAGE_CT" not in header:
                    raise ValueError(
                        "MISSING_DOSAGE_CT column not found "
                        f"in {vmiss_path}"
                    )

                if "OBS_CT" not in header:
                    raise ValueError(
                        f"OBS_CT column not found in {vmiss_path}"
                    )

                missing_idx = header.index(
                    "MISSING_DOSAGE_CT"
                )

                obs_idx = header.index(
                    "OBS_CT"
                )

                continue

            total_missing += int(
                fields[missing_idx]
            )

            total_observations += int(
                fields[obs_idx]
            )

    if total_observations == 0:
        missing_rate = 0.0
    else:
        missing_rate = (
            total_missing
            / total_observations
        )

    return total_missing, missing_rate


def main():

    parser = argparse.ArgumentParser(
        description=(
            "Generate one row of the full pipeline QC report."
        )
    )

    parser.add_argument(
        "--before-pvar",
        required=True,
    )

    parser.add_argument(
        "--after-pvar",
        required=True,
    )

    parser.add_argument(
        "--psam",
        required=True,
    )

    parser.add_argument(
        "--pgen-info",
        required=True,
    )

    parser.add_argument(
        "--vmiss",
        required=True,
    )

    parser.add_argument(
        "--chromosome",
        required=True,
    )

    parser.add_argument(
        "--stage",
        required=True,
    )

    parser.add_argument(
        "--filter-method",
        required=True,
        help="Filtering method used at this stage.",
    )

    parser.add_argument(
        "--filter-threshold",
        required=True,
        help="Filtering threshold used at this stage.",
    )

    parser.add_argument(
        "--output",
        required=True,
    )

    args = parser.parse_args()

    # ----------------------------------------------------------
    # Sample count
    # ----------------------------------------------------------

    n_samples = count_data_lines(
        args.psam
    )

    # ----------------------------------------------------------
    # Variant counts
    # ----------------------------------------------------------

    n_variants_after = count_data_lines(
        args.after_pvar
    )

    if args.stage == "input_data":

        # The input row represents the starting dataset.
        # There is no filtering at this stage, so before and after
        # correspond to the same total number of variants.
        n_variants_before = n_variants_after
        n_variants_removed = 0

    else:

        n_variants_before = count_data_lines(
            args.before_pvar
        )

        n_variants_removed = (
                n_variants_before
                - n_variants_after
        )

    # ----------------------------------------------------------
    # Dosage QC
    # ----------------------------------------------------------

    dosages_present = check_dosages(
        args.pgen_info
    )

    if dosages_present is True:

        (
            n_dosages_missing,
            dosage_missing_rate,
        ) = read_dosage_missingness(
            args.vmiss
        )

        if n_dosages_missing == 0:
            dosage_status = "COMPLETE"
        else:
            dosage_status = "PARTIAL"

        status = "PASS"

    elif dosages_present is False:

        dosage_status = "MISSING"
        n_dosages_missing = "NA"
        dosage_missing_rate = "NA"

        status = "WARN"

    else:

        dosage_status = "ERROR"
        n_dosages_missing = "NA"
        dosage_missing_rate = "NA"

        status = "FAIL"

    # ----------------------------------------------------------
    # Structural checks
    # ----------------------------------------------------------

    if args.stage != "input_data":

        # A filtering step must not increase variant count.
        if n_variants_removed < 0:
            status = "FAIL"

        # Sample selection should not change variant count.
        if (
            args.stage == "sample_selection"
            and n_variants_removed != 0
        ):
            status = "FAIL"

        # Harmonization should not remove variants.
        if (
            args.stage == "harmonization"
            and n_variants_removed != 0
        ):
            status = "FAIL"

    # ----------------------------------------------------------
    # Format dosage missing rate
    # ----------------------------------------------------------

    if isinstance(
        dosage_missing_rate,
        float,
    ):
        dosage_missing_rate = (
            f"{dosage_missing_rate:.10g}"
        )

    # ----------------------------------------------------------
    # Output
    # ----------------------------------------------------------

    header = [
        "chromosome",
        "stage",
        "n_samples",
        "n_variants_before",
        "n_variants_removed",
        "n_variants_after",
        "filter_method",
        "filter_threshold",
        "dosage_status",
        "n_dosages_missing",
        "dosage_missing_rate",
        "status",
    ]

    row = [
        args.chromosome,
        args.stage,
        n_samples,
        n_variants_before,
        n_variants_removed,
        n_variants_after,
        args.filter_method,
        args.filter_threshold,
        dosage_status,
        n_dosages_missing,
        dosage_missing_rate,
        status,
    ]

    with open(args.output, "w") as out:

        out.write(
            "\t".join(header)
            + "\n"
        )

        out.write(
            "\t".join(
                map(str, row)
            )
            + "\n"
        )


if __name__ == "__main__":
    main()