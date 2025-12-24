#!/usr/bin/env python3

import click
import os
import sys

def count_variants(pvar_file):
    """Count the number of variants in a pvar file"""
    if not pvar_file or not os.path.exists(pvar_file):
        return 0
    with open(pvar_file, 'r') as f:
        next(f)  # Skip header
        return sum(1 for _ in f)

@click.command()
@click.option('--pre-filter-pvar', required=True, help='Pvar file before imputation filtering')
@click.option('--post-filter-pvar', required=True, help='Pvar file after imputation filtering')
@click.option('--threshold-used', required=True, help='Threshold value used for filtering')
@click.option('--filtering-method', required=True, help='Filtering method used')
@click.option('--chrom', default='unknown', help='Chromosome number')
def main(pre_filter_pvar, post_filter_pvar, threshold_used, filtering_method, chrom):
    """Generate an imputation quality filtering report based on the filtering method used."""

    # Count variants at each stage
    pre_filter_count = count_variants(pre_filter_pvar)
    post_filter_count = count_variants(post_filter_pvar)

    # Calculate differences
    variants_removed = pre_filter_count - post_filter_count
    removal_rate = variants_removed / pre_filter_count if pre_filter_count > 0 else 0

    # Generate report based on filtering method
    if filtering_method == "none":
        report = f"""Imputation Quality Filtering Report for Chromosome {chrom}
============================================================

No imputation quality filtering was applied to this chromosome.

1. VARIANT COUNT
   Total variants: {pre_filter_count:,}

2. SUMMARY
   No variants were removed by imputation quality filtering.
   Final variant count remains: {post_filter_count:,}
"""
    else:
        report = f"""Imputation Quality Filtering Report for Chromosome {chrom}
============================================================

1. VARIANTS BEFORE FILTERING
   Total variants: {pre_filter_count:,}

2. FILTERING METHOD
   {filtering_method}
   Threshold used: {threshold_used}

3. VARIANTS AFTER FILTERING
   Total variants: {post_filter_count:,}
   Variants removed: {variants_removed:,} ({removal_rate:.1%})

4. SUMMARY
   Final variant count: {post_filter_count:,}
   Overall removal rate: {removal_rate:.1%}
"""

    # Write report to stdout
    click.echo(report)

if __name__ == '__main__':
    # Handle case where filtering-method contains spaces
    if '--filtering-method' in sys.argv:
        idx = sys.argv.index('--filtering-method')
        if idx + 1 < len(sys.argv) and not sys.argv[idx + 1].startswith('--'):
            # Combine all following arguments until next option
            filtering_method = []
            i = idx + 1
            while i < len(sys.argv) and not sys.argv[i].startswith('--'):
                filtering_method.append(sys.argv[i])
                i += 1
            sys.argv[idx + 1] = ' '.join(filtering_method)
            del sys.argv[idx + 2:i]
    main()
