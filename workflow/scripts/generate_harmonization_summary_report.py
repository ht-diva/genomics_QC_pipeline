#!/usr/bin/env python3
import re
import sys
from collections import defaultdict
from datetime import datetime
from pathlib import Path

import click


def parse_plink_log(log_file: str) -> dict | None:
    """Parse PLINK2 log file and extract key information.

    Args:
        log_file: Path to the PLINK2 log file

    Returns:
        Dictionary containing parsed metrics or None if file doesn't exist
    """
    log_path = Path(log_file)
    if not log_path.exists():
        return None

    metrics = {
        'chrom': '',
        'errors': [],
        'warnings': [],
        'num_ref_alleles_updated': 0,
        'num_alt1_alleles_updated': 0,
        'num_ids_updated': 0,
        'num_variants': 0,
        'type': None
    }

    chrom_match = re.search(r'(\d+|X|Y)(?=_|$)', log_file)
    if chrom_match:
        metrics['chrom'] = chrom_match.group(1)

    with log_path.open('r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            if 'Error' in line:
                metrics['errors'].append(line)
            elif 'Warning' in line:
                metrics['warnings'].append(line)
            elif '--ref-allele:' in line:
                metrics['type'] = 'allele'
                metrics['num_ref_alleles_updated'] = _extract_count(line)
            elif '--alt1-allele:' in line:
                metrics['type'] = 'allele'
                metrics['num_alt1_alleles_updated'] = _extract_count(line)
            elif '--update-name:' in line:
                metrics['type'] = 'id'
                metrics['num_ids_updated'] = _extract_count(line)
            elif 'variants loaded' in line.lower():
                metrics['num_variants'] = _extract_count(line)

    return metrics if metrics['type'] else None


def _extract_count(line: str) -> int:
    """Helper function to extract count from log line."""
    match = re.search(r'\d+', line.split(':')[1])
    return int(match.group()) if match else 0


def write_report_section(file, title: str, metrics: dict, section_type: str) -> None:
    """Write a formatted section to the report file."""
    file.write(f"\n=== {title} ===\n")

    if section_type == 'id':
        file.write(f"IDs updated: {metrics['num_ids_updated']}\n")
    else:
        file.write(f"REF Alleles rotated: {metrics['num_ref_alleles_updated']}\n")
        file.write(f"ALT Alleles rotated: {metrics['num_alt1_alleles_updated']}\n")

    if metrics['errors']:
        file.write("\nErrors:\n" + "\n".join(metrics['errors']) + "\n")
    if metrics['warnings']:
        file.write("\nWarnings:\n" + "\n".join(metrics['warnings']) + "\n")


@click.command()
@click.argument('output-file', nargs=1, type=click.Path())
@click.argument('logs', nargs=-1, type=click.Path())
def generate_report(output_file: str, logs: tuple[str]) -> None:
    """Generate comprehensive harmonization report from PLINK2 logs."""
    all_metrics = []
    for log_file in logs:
        try:
            if metrics := parse_plink_log(log_file):
                all_metrics.append(metrics)
        except Exception as e:
            click.echo(f"Warning: Could not parse log file {log_file}: {str(e)}", err=True)
    if not all_metrics:
        click.echo("No valid log files found.", err=True)
        sys.exit(1)

    chrom_data = defaultdict(lambda: {'id': None, 'allele': None})
    for metric in all_metrics:
        chrom = metric['chrom']
        report_type = metric['type']
        chrom_data[chrom][report_type] = metric

    total_chroms = len(chrom_data)
    total_variants = sum(m['num_variants'] for m in all_metrics if m.get('num_variants', 0) > 0)
    total_ids_updated = sum(m['num_ids_updated'] for m in all_metrics if m['type'] == 'id')
    total_ref_rotated = sum(m['num_ref_alleles_updated'] for m in all_metrics if m['type'] == 'allele')
    total_alt_rotated = sum(m['num_alt1_alleles_updated'] for m in all_metrics if m['type'] == 'allele')

    with Path(output_file).open('w') as f:
        f.write(f"\n=== COMPREHENSIVE HARMONIZATION SUMMARY REPORT - ALL CHROMOSOMES ===\n")
        f.write(f"Report generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write(f"Total chromosomes processed: {total_chroms}\n")
        f.write(f"Total variants found: {total_variants}\n")
        f.write(f"Total IDs updated: {total_ids_updated}\n")
        f.write(f"Total REF alleles rotated: {total_ref_rotated}\n")
        f.write(f"Total ALT alleles rotated: {total_alt_rotated}\n")

        for chrom, data in sorted(chrom_data.items()):
            if data['id']:
                write_report_section(
                    f,
                    f"PLINK2 Update ID Log for Chromosome {chrom}",
                    data['id'],
                    'id'
                )
            if data['allele']:
                write_report_section(
                    f,
                    f"PLINK2 Update Alleles Log for Chromosome {chrom}",
                    data['allele'],
                    'allele'
                )


if __name__ == "__main__":
    generate_report()
