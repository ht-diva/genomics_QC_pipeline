# genomics_QC_pipeline
A comprehensive quality control pipeline for cleaning and preparing imputed genotype data for protein quantitative trait locus (pQTL) analysis.
This pipeline is based on Alessia Mapelli and Solène Cadiou's work, and has been adapted for reproducible genomic data processing.

## Features

- **Comprehensive QC**: Filters mirror SNPs, problematic variants, and low-quality samples
- **Format Conversion**: Handles PGEN and BED formats
- **Harmonization**: Standardizes variant IDs and alleles across datasets
- **Modular Design**: Configurable for different projects (INTERVAL, BELIEVE, etc.)
- **Reproducible**: Uses Snakemake workflow management with containerized tools


### Software Dependencies
- [Snakemake](https://snakemake.readthedocs.io/) (workflow management)
- [Singularity](https://sylabs.io/singularity/) (container runtime)
- Git (version control)

### Configuration
See [environment.yml](environment.yml) for Python dependencies and [Makefile](Makefile) for common commands.

## Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ht-diva/genomics_QC_pipeline.git
   cd genomics_QC_pipeline
   ```

2. **Select a project configuration**:
   ```bash
   # Choose one of the available configurations
   make project-interval    # For INTERVAL study
   make project-believe     # For BELIEVE study
   make project-<custom>    # For custom configurations
   ```

3. **Run the pipeline**:
   ```bash
   sbatch submit.sbatch


## Configuration

### Project Selection
The pipeline supports multiple project configurations stored in `config/config.<name>.yaml`. The active project is set by:

1. Creating/updating the `.project` file, or
2. Using Makefile helpers (recommended)

### Output Location
Results are written to the path specified by `workspace_path` in your config file (default: `./results`).

## Pipeline Workflow

The pipeline consists of several processing steps organized in 3 main blocks:

### 1. Quality Control
- **ID Standardization**: Converts variant IDs to `chr:pos:ref:alt` format
- **Sample Selection**: Filters to include only individuals with matching proteomic data
- **Mirror SNP Handling**: Identifies and removes problematic palindromic variants
- **Multiallelic-site handling**: variants are grouped by chromosome and position among valid biallelic SNPs, one SNP per position is retained.
The selected SNPs are written to `pgen/qc/filtering/{chrom}_best_snps.txt`
The excluded SNPs are written to `pgen/qc/filtering/{chrom}_removed_multiallelic_snps.txt`
- **Variant Filtering**: Removes low-quality variants based on multiple metrics (MAF, HWE, etc.)
- **Imputation quality**: Filters based on imputation quality metrics (INFO-score or MINIMAC3)

### 2. Data Harmonization
- **SNP mapping**: generates mapping tables with GWASPipe
- **ID Harmonization**: Arrange the variant IDs in alphabetical order
- **Allele Harmonization**: Ensures consistent allele representation across datasets

### 3. Final Preparation
- **Format Conversion**: Supports PGEN ↔ BED conversions
- **Merging**: Combines chromosome-specific files into unified datasets
- **Delivery**: Organizes final outputs in standardized directory structure
- **Report Generation**: Generates comprehensive summary reports detailing the pipeline's results.

## Output Structure

```
results/
├── bed/
│   └── qc_harmonised/
├── pgen/
│   ├── qc/
│   │   ├── {chrom}.impute_recoded_selected_sample_filtered_var.pgen
│   │   ├── {chrom}.impute_recoded_selected_sample_filtered_var.pvar
│   │   ├── {chrom}.impute_recoded_selected_sample_filtered_var.psam
│   │   ├── {chrom}.impute_recoded_selected_sample_filtered_var_filtered_hq_var.pvar
│   │   ├── {chrom}.impute_recoded_selected_sample_filtered_var_filtered_minimac3.pvar
│   │   └── filtering/
│   │       ├── {chrom}_mirror_snps.txt
│   │       ├── {chrom}_best_snps.txt
│   │       └── {chrom}_removed_multiallelic_snps.txt
│   ├── qc_harmonised/
│   ├── pseudo_biallelic.txt
│   └── recode_rsid.txt
├── reports/
│   ├── all_chromosomes_filtering_summary_report.txt
│   ├── all_chromosomes_filtering_summary_report.tsv
│   └── all_chromosomes_harmonization_summary_report.txt
└── README.txt
```

## Rule Reference
 | Steps         | Rule Name                                | Purpose                                                                            | Output Files                                                                              |
|---------------|------------------------------------------|------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------|
| Basic info    |                                          |                                                                                    |                                                                                           |
|               | `list_rs`                                | Generate lists of rsIDs and pseudo-biallelic variants                              | `merge_rsids.txt`, `recode_rsids.txt`, `pseudo_biallelic_var.txt`, `pseudo_biallelic.txt` |
|               | `header_info`                            | Generate a basic information report from the original dataset for each chromosome  | Text report                                                                               |
| QC            |                                          |                                                                                    |                                                                                           |
|               | `recode_pgen`                            | Replace IDs with `chr:pos:ref:alt` format                                          | Recoded PGEN files                                                                        |
|               | `select_samples`                         | Select individuals present in both genomic and proteomic datasets                  | Filtered sample files                                                                     |
|               | `sanitize_problematic_snps`              | Standardize the problematic SNP list by removing the `chr` prefix                  | `problematic_snps_list.txt`                                                               |
|               | `filter_problematic_snps`                | Filter out a list of predefined problematic SNPs                                   | `{chrom}_filtered_problematic_snps.{pgen,pvar,psam}`                                      |
|               | `get_mirror_snps`                        | Identify mirror SNP pairs (`X:XXXXXXX:A:B` and `X:XXXXXXX:B:A`)                    | `{chrom}_mirror_snps.txt`                                                                 |
|               | `filter_mirror_snps`                     | Remove mirror SNPs from the dataset                                                | `{chrom}_filtered_mirror_snps.{pgen,pvar,psam}`                                           |
|               | `compute_afreq`                          | Compute allele frequencies after mirror SNP filtering                              | `{chrom}_filtered_mirror_snps.afreq`                                                      |
|               | `select_best_snps`                       | Select the best SNP to keep at multiallelic positions based on allele frequency    | `{chrom}_best_snps.txt`                                                                   |
|               | `save_removed_multiallelic_snps`         | Save the multiallelic SNPs excluded after selecting the best SNP per position      | `{chrom}_removed_multiallelic_snps.txt`                                                   |
|               | `filter_multiallelic_var`                | Keep only the selected SNPs at multiallelic positions                              | `{chrom}_filtered_multiallelic_var.{pgen,pvar,psam}`                                      |
|               | `filter_var`                             | Perform QC filtering using missingness, HWE, and MAC thresholds                    | Quality-controlled PGEN files                                                             |
|               | `create_bgen`                            | Convert filtered data to BGEN format                                               | `{chrom}_impute_recoded_selected_sample_filtered_var.{bgen,sample}`                       |
|               | `qctool`                                 | Compute SNP statistics using qctool                                                | `snp-stats_chr_{chrom}_impute_recoded_selected_sample_filtered_var.txt`                   |
|               | `get_hq_variants`                        | Filter variants with INFO score > 0.7                                              | List of high-quality variants                                                             |
|               | `filter_hq_variants`                     | Extract high-quality variants from PGEN files                                      | Chromosome-specific PGEN files with HQ variants                                           |
|               | `filter_by_minimac3`                     | Extract variants passing the minimac3 threshold                                    | Chromosome-specific PGEN files with minimac3-filtered variants                            |
|               | `merge_filter_hq_variants`               | Merge chromosome-specific PGEN files                                               | Combined PGEN file with HQ variants                                                       |
| Harmonization |                                          |                                                                                    |                                                                                           |
|               | `build_snp_mapping_files`                | Generate SNP mapping files for harmonization                                       | Mapping table and harmonized PVAR table                                                   |
|               | `update_pgen_id`                         | Update variant IDs to `chr:pos:A0:A1` format (alphabetical order)                  | PGEN files with updated IDs                                                               |
|               | `update_pgen_alleles`                    | Harmonize alleles to match the new IDs                                             | PGEN files with harmonized alleles                                                        |
|               | `merge_qc_harmonised_pgen`               | Merge final harmonized PGEN files                                                  | Final combined PGEN file                                                                  |
|               | `pgen2bed`                               | Convert PGEN to BED format (`hard-call-threshold = 0.49999999`)                    | BED files with harmonized alleles                                                         |
|               | `merge_qc_harmonised_bed`                | Merge final harmonized BED files                                                   | Final combined BED file                                                                   |
| Documentation |                                          |                                                                                    |                                                                                           |
|               | `write_readme`                           | Generate documentation with traceability information                               | `README.txt` with git information                                                         |
|               | `generate_chromosome_summary_report`     | Generate a comprehensive report with variant filtering results                     | Text report                                                                               |
|               | `generate_chromosome_summary_report`     | Generate a table of variant filtering results                                      | TSV table                                                                                 |
|               | `generate_harmonization_summary_report`  | Generate a comprehensive report with harmonization results                         | Text report                                                                               |



## Workflow example

This graph illustrates the progression of the workflow from the input files to the final outputs. For simplicity, the workflow is restricted to two chromosomes only.
[Open the workflow diagram (PDF)](dag.pdf)

## Customization

To adapt the pipeline for your project:

1. Create a new config file in `config/config.<your_project>.yaml`
2. Update paths and parameters as needed
3. Add any project-specific rules to the appropriate `.smk` files

## Support

For issues or questions:
- Check existing [GitHub Issues](https://github.com/ht-diva/genomics_QC_pipeline/issues)
- Refer to the original [INTERVAL QC script](https://github.com/ht-diva/pqtl-believe-interval/blob/main/Script_QC_INTERVAL_genomics.R)


## Citation

If you use this pipeline, please cite:
- This pipeline repository
