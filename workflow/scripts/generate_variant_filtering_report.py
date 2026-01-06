#!/usr/bin/env python3

import os
import sys

import click


def count_variants(pvar_file):
    """Count the number of variants in a pvar file"""
    if not pvar_file or not os.path.exists(pvar_file):
        return 0
    with open(pvar_file, 'r') as f:
        next(f)
        return sum(1 for _ in f)


def count_snps_in_list(snp_list_file):
    """Count SNPs in a exclusion list file"""
    if not snp_list_file or not os.path.exists(snp_list_file):
        return 0
    with open(snp_list_file, 'r') as f:
        return sum(1 for _ in f)


@click.command()
@click.option('--original-pvar', required=True, help='Original pvar file before filtering')
@click.option('--mirror-filtered-pvar', required=True, help='Pvar file after mirror SNP filtering')
@click.option('--problematic-filtered-pvar', required=True, help='Pvar file after problematic SNP filtering')
@click.option('--final-pvar', required=True, help='Final pvar file after all filtering')
@click.option('--mirror-snps-list', required=True, help='List of mirror SNPs excluded')
@click.option('--problematic-snps-list', default='', help='List of problematic SNPs excluded (empty if not used)')
@click.option('--chrom', default='unknown', help='Chromosome number')
def main(original_pvar, mirror_filtered_pvar, problematic_filtered_pvar, final_pvar,
         mirror_snps_list, problematic_snps_list, chrom):
    """Generate a variant filtering report."""

    original_count = count_variants(original_pvar)
    mirror_filtered_count = count_variants(mirror_filtered_pvar)
    problematic_filtered_count = count_variants(problematic_filtered_pvar)
    final_count = count_variants(final_pvar)

    mirror_snps_count = count_snps_in_list(mirror_snps_list)
    problematic_snps_count = count_snps_in_list(problematic_snps_list) if problematic_snps_list else 0

    mirror_removed = original_count - mirror_filtered_count
    problematic_removed = mirror_filtered_count - problematic_filtered_count
    qc_removed = problematic_filtered_count - final_count

    report = f"""Variant Filtering Report for Chromosome {chrom}
================================================

1. INITIAL VARIANT COUNT
   Total variants before filtering: {original_count:,}

2. MIRROR SNP FILTERING
   Mirror SNPs excluded: {mirror_snps_count:,}
   Variants after mirror filtering: {mirror_filtered_count:,}
   Variants removed after mirror filtering: {mirror_removed:,} ({mirror_removed / original_count:.1%})

3. PROBLEMATIC SNP FILTERING
   Problematic SNPs excluded: {problematic_snps_count:,}
   Variants after problematic filtering: {problematic_filtered_count:,}
   Variants removed after problematic filtering: {problematic_removed:,} ({problematic_removed / mirror_filtered_count:.1%})

4. QUALITY CONTROL FILTERING
   Variants after QC filtering: {final_count:,}
   Variants removed after QC filtering: {qc_removed:,} ({qc_removed / problematic_filtered_count:.1%})

5. SUMMARY
   Total variants removed: {original_count - final_count:,} ({1 - (final_count / original_count):.1%})
   Final variant count: {final_count:,}
"""

    click.echo(report)


if __name__ == '__main__':
    if '--problematic-snps-list' in sys.argv:
        idx = sys.argv.index('--problematic-snps-list')
        if idx + 1 >= len(sys.argv) or sys.argv[idx + 1].startswith('--'):
            sys.argv.insert(idx + 1, '')
    main()
