#!/usr/bin/env python3

import os

import click


def count_samples(psam_file):
    """Count samples in a PSAM file."""
    if not psam_file or not os.path.exists(psam_file):
        return 0

    with open(psam_file, "r") as file:
        return sum(
            1
            for line in file
            if line.strip() and not line.startswith("#")
        )


def count_ids_in_list(id_list_file):
    """Count non-empty records in a sample ID list."""
    if not id_list_file or not os.path.exists(id_list_file):
        return 0

    with open(id_list_file, "r") as file:
        return sum(
            1
            for line in file
            if line.strip() and not line.startswith("#")
        )


@click.command()
@click.option(
    "--original-psam",
    required=True,
    type=click.Path(exists=True),
    help="Original PSAM file before sample selection.",
)
@click.option(
    "--filtered-psam",
    required=True,
    type=click.Path(exists=True),
    help="Filtered PSAM file after sample selection.",
)
@click.option(
    "--id-list",
    required=True,
    type=click.Path(exists=True),
    help="Sample ID list used for sample selection.",
)
@click.option(
    "--method",
    required=True,
    help="Sample-selection method used.",
)
@click.option(
    "--chrom",
    default="unknown",
    show_default=True,
    help="Chromosome number.",
)
def main(original_psam, filtered_psam, id_list, method, chrom):
    """Generate a sample-selection report."""

    # Count samples at each stage
    original_count = count_samples(original_psam)
    filtered_count = count_samples(filtered_psam)
    id_list_count = count_ids_in_list(id_list)

    # Calculate the number and percentage of removed samples
    samples_removed = original_count - filtered_count

    if original_count > 0:
        removed_percentage = samples_removed / original_count
    else:
        removed_percentage = 0.0

    # Describe the sample-selection method
    method_description = {
        "keep": "keeping only samples in the ID list",
        "keep-fam": "keeping only samples in the ID list (FAM format)",
        "remove": "removing samples in the ID list",
        "remove-fam": "removing samples in the ID list (FAM format)",
    }.get(method, method)

    report = f"""Sample Filtering Report for Chromosome {chrom}
===============================================

1. INITIAL SAMPLE COUNT
   Total samples before filtering: {original_count:,}

2. SAMPLE SELECTION
   Filtering method: {method_description}
   Number of IDs in list: {id_list_count:,}
   Samples after selection: {filtered_count:,}
   Samples removed in this step: {samples_removed:,} ({removed_percentage:.1%})

3. SUMMARY
   Final sample count: {filtered_count:,}
   Total samples removed: {samples_removed:,} ({removed_percentage:.1%})
"""

    click.echo(report)


if __name__ == "__main__":
    main()