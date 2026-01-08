import re
from collections import defaultdict
from pathlib import Path

import click


def parse_report_file(report_file):
    """Parse a report file and extract key metrics"""
    report_path = Path(report_file)
    if not report_path.exists():
        return None

    metrics = {}
    with open(report_path, 'r') as f:
        content = f.read()
        content = content.replace(",", "")

        # Extract chromosome number from filename
        chrom_match = re.search(r'(\d+|X|Y)(?=_|$)', report_file)
        if chrom_match:
            metrics['chrom'] = chrom_match.group(1)

        # Parse variant filtering report
        if 'variant_filtering_report' in report_file:
            metrics['type'] = 'variant'
            metrics['initial_variants'] = int(re.search(r'Total variants before filtering: (\d+)', content).group(1))
            metrics['final_variants'] = int(re.search(r'Final variant count: (\d+)', content).group(1))
            metrics['variants_removed'] = int(re.search(r'Total variants removed: (\d+)', content).group(1))

        # Parse sample filtering report
        elif 'sample_filtering_report' in report_file:
            metrics['type'] = 'sample'
            metrics['initial_samples'] = int(re.search(r'Total samples before filtering: (\d+)', content).group(1))
            metrics['final_samples'] = int(re.search(r'Final sample count: (\d+)', content).group(1))
            metrics['samples_removed'] = int(re.search(r'Total samples removed: (\d+)', content).group(1))

        # Parse imputation quality report
        elif 'imputation_quality_report' in report_file:
            metrics['type'] = 'imputation'
            metrics['initial_variants'] = int(re.search(r'Total variants: (\d+)', content).group(1))
            metrics['final_variants'] = int(re.search(r'Final variant count: (\d+)', content).group(1))

            # Try different patterns for variants removed
            variants_removed_match = re.search(r'Total variants removed: (\d+)', content)
            if not variants_removed_match:
                variants_removed_match = re.search(r'Variants removed: (\d+)', content)
            if variants_removed_match:
                metrics['variants_removed'] = int(variants_removed_match.group(1))
            else:
                metrics['variants_removed'] = 0

    return metrics


@click.command()
@click.argument('output-file', nargs=1, type=click.Path())
@click.argument('reports', nargs=-1, type=click.Path())
def main(output_file, reports):
    """Generate a comprehensive summary report for all chromosomes."""

    # Parse all reports
    all_metrics = []
    for report_file in reports:
        try:
            metrics = parse_report_file(report_file)
            if metrics:
                all_metrics.append(metrics)
        except Exception as e:
            print(f"Warning: Could not parse report file {report_file}: {str(e)}")
            continue

    # Organize data by chromosome
    chrom_data = defaultdict(lambda: {'variant': {}, 'sample': {}, 'imputation': {}})
    for metric in all_metrics:
        chrom = metric['chrom']
        report_type = metric['type']
        chrom_data[chrom][report_type] = metric

    # Check sample consistency across chromosomes
    sample_values = []
    for chrom, data in chrom_data.items():
        if 'sample' in data and data['sample']:
            sample_values.append((
                data['sample'].get('initial_samples', 0),
                data['sample'].get('final_samples', 0),
                data['sample'].get('samples_removed', 0)
            ))

    # Verify all sample values are the same
    if sample_values:
        first_values = sample_values[0]
        all_same = all(v == first_values for v in sample_values)

        initial_samples, final_samples, samples_removed = first_values
        if all_same:
            msg = "Sample counts are consistent across all chromosomes"
        else:
            msg = "Warning: Sample counts differ between chromosomes. Using first chromosome's values."

    else:
        initial_samples = final_samples = samples_removed = 0
        msg = "No sample filtering reports found."

    # Generate text-based report
    report = """COMPREHENSIVE QC SUMMARY REPORT - ALL CHROMOSOMES
================================================

"""

    # Summary table header
    report += """
CHROM | INITIAL SAMPLES | FINAL SAMPLES | SAMPLES REMOVED | INITIAL VARIANTS | FINAL VARIANTS | QC VARIANTS REMOVED | IMPUTATION VARIANTS REMOVED
------|-----------------|---------------|-----------------|------------------|----------------|---------------------|-------------------------------
"""

    # Generate TSV filename by replacing extension
    output_path = Path(output_file)
    tsv_output = output_path.with_suffix('.tsv')

    # Generate TSV content
    tsv_content = "CHROM\tINITIAL_SAMPLES\tFINAL_SAMPLES\tSAMPLES_REMOVED\tINITIAL_VARIANTS\tFINAL_VARIANTS\tQC_VARIANTS_REMOVED\tIMPUTATION_VARIANTS_REMOVED\n"

    # Process each chromosome
    for chrom in sorted(chrom_data.keys(), key=lambda x: (int(x) if x.isdigit() else float('inf'), x)):
        data = chrom_data[chrom]

        # Get metrics with defaults
        initial_variants = data['variant'].get('initial_variants', 0)
        final_variants = data['imputation'].get('final_variants', 0)
        qc_removed = data['variant'].get('variants_removed', 0)
        imputation_removed = data['imputation'].get('variants_removed', 0)

        # Add row to text report
        report += f"""\
{chrom:5} | {initial_samples:15,} | {final_samples:13,} | {samples_removed:15,} |{initial_variants:17,} | {final_variants:14,} | {qc_removed:19,} | {imputation_removed:27,}
"""

        # Add row to TSV
        tsv_content += f"{chrom}\t{initial_samples}\t{final_samples}\t{samples_removed}\t{initial_variants}\t{final_variants}\t{qc_removed}\t{imputation_removed}\n"
    # Add overall summary to text report
    report += """

OVERALL SUMMARY
===============
"""
    # Calculate totals
    total_initial_variants = sum(d['variant'].get('initial_variants', 0) for d in chrom_data.values())
    total_final_variants = sum(d['imputation'].get('final_variants', 0) for d in chrom_data.values())
    total_variants_removed = sum(
        d['variant'].get('variants_removed', 0) + d['imputation'].get('variants_removed', 0) for d in
        chrom_data.values())
    total_qc_variants_removed = sum(d['variant'].get('variants_removed', 0) for d in chrom_data.values())
    total_imputation_removed = sum(d['imputation'].get('variants_removed', 0) for d in chrom_data.values())

    report += f"""
Sample counts ({msg}):
-------------
Initial samples: {initial_samples:,}
Final samples: {final_samples:,}
Samples removed: {samples_removed:,} ({samples_removed / initial_samples:.1%})

Variant counts across all chromosomes:
-------------------------------------
Initial variants: {total_initial_variants:,}
Final variants after all filtering: {total_final_variants:,}

Total variants removed: {total_variants_removed:,} ({total_variants_removed / total_initial_variants:.1%})
Total variants removed by QC filtering: {total_qc_variants_removed:,}
Total variants removed by imputation quality filtering: {total_imputation_removed:,}
"""

    # Write text report to main output file
    with open(output_path, 'w') as f:
        f.write(report)

    # Write TSV file
    with open(tsv_output, 'w') as f:
        f.write(tsv_content)


if __name__ == '__main__':
    main()
