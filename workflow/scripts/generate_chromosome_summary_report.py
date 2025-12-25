import sys
import os
import re
from collections import defaultdict

def parse_report_file(report_file):
    """Parse a report file and extract key metrics"""
    if not os.path.exists(report_file):
        return None

    metrics = {}
    with open(report_file, 'r') as f:
        content = f.read()

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

def main():
    """Generate a comprehensive summary report for all chromosomes."""

    variant_reports = snakemake.input.variant_reports
    sample_reports = snakemake.input.sample_reports
    imputation_reports = snakemake.input.imputation_reports
    output_file = snakemake.output[0]

    # Parse all reports
    all_metrics = []
    for report_file in variant_reports + sample_reports + imputation_reports:
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

    # Generate summary report
    report = """COMPREHENSIVE QC SUMMARY REPORT - ALL CHROMOSOMES
================================================

"""

    # Summary table header
    report += """
CHROM | INITIAL VARIANTS | FINAL VARIANTS | VARIANTS REMOVED | INITIAL SAMPLES | FINAL SAMPLES | SAMPLES REMOVED | IMPUTATION VARIANTS REMOVED
------|------------------|----------------|------------------|-----------------|---------------|-----------------|-------------------------------
"""

    # Process each chromosome
    for chrom in sorted(chrom_data.keys(), key=lambda x: (int(x) if x.isdigit() else float('inf'), x)):
        data = chrom_data[chrom]

        # Get metrics with defaults
        initial_variants = data['variant'].get('initial_variants', 0)
        final_variants = data['variant'].get('final_variants', 0)
        variants_removed = data['variant'].get('variants_removed', 0)

        initial_samples = data['sample'].get('initial_samples', 0)
        final_samples = data['sample'].get('final_samples', 0)
        samples_removed = data['sample'].get('samples_removed', 0)

        imputation_removed = data['imputation'].get('variants_removed', 0)

        # Add row to table
        report += f"""\
{chrom:5} | {initial_variants:16,} | {final_variants:14,} | {variants_removed:16,} | {initial_samples:15,} | {final_samples:13,} | {samples_removed:15,} | {imputation_removed:27,}
"""

    # Add overall summary
    report += """

OVERALL SUMMARY
===============
"""

    # Calculate totals
    total_initial_variants = sum(d['variant'].get('initial_variants', 0) for d in chrom_data.values())
    total_final_variants = sum(d['variant'].get('final_variants', 0) for d in chrom_data.values())
    total_variants_removed = sum(d['variant'].get('variants_removed', 0) for d in chrom_data.values())

    total_initial_samples = sum(d['sample'].get('initial_samples', 0) for d in chrom_data.values())
    total_final_samples = sum(d['sample'].get('final_samples', 0) for d in chrom_data.values())
    total_samples_removed = sum(d['sample'].get('samples_removed', 0) for d in chrom_data.values())

    total_imputation_removed = sum(d['imputation'].get('variants_removed', 0) for d in chrom_data.values())

    report += f"""
Total initial variants across all chromosomes: {total_initial_variants:,}
Total final variants after all filtering: {total_final_variants:,}
Total variants removed: {total_variants_removed:,} ({total_variants_removed/total_initial_variants:.1%})

Total initial samples: {total_initial_samples:,}
Total final samples: {total_final_samples:,}
Total samples removed: {total_samples_removed:,} ({total_samples_removed/total_initial_samples:.1%})

Total variants removed by imputation quality filtering: {total_imputation_removed:,}
"""

    # Write report to Snakemake output file
    with open(output_file, 'w') as f:
        f.write(report)

if __name__ == '__main__':
    main()
