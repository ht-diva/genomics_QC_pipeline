#!/usr/bin/env python3

import argparse


def count_data_lines(path):
    """
    Count non-header, non-empty lines.

    Works for:
      - .psam -> number of samples
      - .pvar -> number of variants
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
    Determine whether dosage data are stored in the PGEN.

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
    Sum MISSING_DOSAGE_CT and OBS_CT across all variants.

    dosage_missing_rate =
        total missing dosages / total possible observations
    """
    total_missing = 0
    total_observations = 0

    with open(vmiss_path) as handle:
        header = None
        missing_idx = None
        obs_idx = None

        for line in handle:
            line = line.strip()

            if not line:
                continue

            fields = line.split()

            if header is None:
                header = [field.lstrip("#") for field in fields]

                if "MISSING_DOSAGE_CT" not in header:
                    raise ValueError(
                        "MISSING_DOSAGE_CT column not found in "
                        f"{vmiss_path}"
                    )

                if "OBS_CT" not in header:
                    raise ValueError(
                        f"OBS_CT column not found in {vmiss_path}"
                    )

                missing_idx = header.index("MISSING_DOSAGE_CT")
                obs_idx = header.index("OBS_CT")

                continue

            total_missing += int(fields[missing_idx])
            total_observations += int(fields[obs_idx])

    if total_observations == 0:
        missing_rate = 0.0
    else:
        missing_rate = total_missing / total_observations

    return total_missing, missing_rate


def main():
    parser = argparse.ArgumentParser(
        description="Generate one stage-QC report row."
    )

    parser.add_argument(
        "--pvar",
        required=True,
        help="PVAR file for this pipeline stage.",
    )

    parser.add_argument(
        "--psam",
        required=True,
        help="PSAM file for this pipeline stage.",
    )

    parser.add_argument(
        "--pgen-info",
        required=True,
        help="PLINK --pgen-info log.",
    )

    parser.add_argument(
        "--vmiss",
        required=True,
        help="PLINK variant missingness report.",
    )

    parser.add_argument(
        "--chromosome",
        required=True,
        help="Chromosome.",
    )

    parser.add_argument(
        "--stage",
        required=True,
        help="Pipeline stage.",
    )

    parser.add_argument(
        "--output",
        required=True,
        help="Output TSV.",
    )

    args = parser.parse_args()

    # ----------------------------------------------------------
    # Dataset dimensions
    # ----------------------------------------------------------

    n_samples = count_data_lines(args.psam)
    n_variants = count_data_lines(args.pvar)

    # ----------------------------------------------------------
    # Dosage information
    # ----------------------------------------------------------

    dosages_present = check_dosages(args.pgen_info)

    if dosages_present is True:

        n_dosages_missing, dosage_missing_rate = (
            read_dosage_missingness(args.vmiss)
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

    # Format rate
    if isinstance(dosage_missing_rate, float):
        dosage_missing_rate = f"{dosage_missing_rate:.10g}"

    # ----------------------------------------------------------
    # Write output
    # ----------------------------------------------------------

    header = [
        "chromosome",
        "stage",
        "n_samples",
        "n_variants",
        "dosage_status",
        "n_dosages_missing",
        "dosage_missing_rate",
        "status",
    ]

    row = [
        args.chromosome,
        args.stage,
        n_samples,
        n_variants,
        dosage_status,
        n_dosages_missing,
        dosage_missing_rate,
        status,
    ]

    with open(args.output, "w") as out:
        out.write("\t".join(header) + "\n")
        out.write("\t".join(map(str, row)) + "\n")


if __name__ == "__main__":
    main()