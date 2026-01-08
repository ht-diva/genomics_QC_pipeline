#!/usr/bin/env python3

import os

import click


def count_samples(psam_file):
    """Count the number of samples in a psam file"""
    if not psam_file or not os.path.exists(psam_file):
        return 0
    with open(psam_file, 'r') as f:
        next(f)  # Skip header
        return sum(1 for _ in f)


def count_ids_in_list(id_list_file):
    """Count IDs in a sample list file"""
    if not id_list_file or not os.path.exists(id_list_file):
        return 0
    with open(id_list_file, 'r') as f:
        return sum(1 for _ in f)


@click.command()
@click.option('--original-psam', required=True, help='Original psam file before filtering')
@click.option('--filtered-psam', required=True, help='Filtered psam file after filtering')
@click.option('--id-list', required=True, help='Sample ID list used for filtering')
@click.option('--method', required=True, help='Filtering method used')
@click.option('--mind', required=True, help='MIND threshold used')
@click.option('--chrom', default='unknown', help='Chromosome number')
def main(original_psam, filtered_psam, id_list, method, mind, chrom):
    """Generate a sample filtering report."""

    # Count samples at each stage
    original_count = count_samples(original_psam)
    filtered_count = count_samples(filtered_psam)
    id_list_count = count_ids_in_list(id_list)

    # Calculate differences
    samples_removed = original_count - filtered_count

    # Determine filtering method description
    method_description = {
        "keep": "keeping only samples in the ID list",
        "keep-fam": "keeping only samples in the ID list (FAM format)",
        "remove": "removing samples in the ID list",
        "remove-fam": "removing samples in the ID list (FAM format)"
    }.get(method, method)

    # Generate report
    report = f"""Sample Filtering Report for Chromosome {chrom}
===============================================

1. INITIAL SAMPLE COUNT
   Total samples before filtering: {original_count:,}

2. SAMPLE SELECTION
   Filtering method: {method_description}
   Number of IDs in list: {id_list_count:,}
   Samples after selection: {filtered_count:,}
   Samples removed in this step: {samples_removed:,} ({samples_removed / original_count:.1%})

3. MIND FILTERING
   Minimum genotype call rate threshold: {mind}
   (Note: Additional samples may have been removed by --mind filtering)

4. SUMMARY
   Final sample count: {filtered_count:,}
   Total samples removed: {samples_removed:,} ({samples_removed / original_count:.1%})
"""

    # Write report to stdout
    click.echo(report)


if __name__ == '__main__':
    main()
