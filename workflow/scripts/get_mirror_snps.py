import pandas as pd
import click
from pathlib import Path

@click.command()
@click.option('--input', type=click.Path(exists=True), required=True, help='Path to the TSV file (can be gzipped)')
@click.option('--column', required=True, help='Name of the column containing SNPIDs')
@click.option('--output_file', required=True, help='Path to the output file')
def main(input_file, column, output_file):
    """Find mirror SNPIDs in a TSV file and write results to a file."""

    # Read the TSV file
    df = pd.read_csv(input_file, sep='\t', compression='infer')

    # Split SNPID into components
    split_df = df[column].str.split(':', expand=True)
    split_df.columns = ['chr', 'pos', 'allele1', 'allele2']

    # Group by 'chr' and 'pos' and filter groups with 2 or more members
    grouped = split_df.groupby(['chr', 'pos']).filter(lambda x: len(x) >= 2)

    # Create a set of tuples for faster lookup
    allele_pairs = set(zip(grouped['allele1'], grouped['allele2'], grouped['chr'], grouped['pos']))

    # Find mirror SNPIDs
    mirror_pairs = set()
    for i, row in grouped.iterrows():
        swapped = (row['allele2'], row['allele1'], row['chr'], row['pos'])
        if swapped in allele_pairs:
            original = f"{row['chr']}:{row['pos']}:{row['allele1']}:{row['allele2']}"
            mirror = f"{row['chr']}:{row['pos']}:{row['allele2']}:{row['allele1']}"
            mirror_pairs.add(tuple(sorted((original, mirror))))

    # Print the number of mirror SNPID pairs
    click.echo(f"Found {len(mirror_pairs)} mirror SNPID pairs.")

    # Write the mirror SNPID pairs to a file
    with open(output_file, 'w') as f:
        for pair in sorted(mirror_pairs):
            f.write(f"{pair[0]}\n{pair[1]}\n")

    click.echo(f"Mirror SNPID pairs written to 'mirror_snp_pairs.txt'.")

if __name__ == "__main__":
    main()
