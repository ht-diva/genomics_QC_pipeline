# imputed_genotype_QC_pipe
A comprehensive quality control pipeline for cleaning and preparing imputed genotype data for protein quantitative trait locus (pQTL) analysis.
This pipeline is based on Alessia Mapelli and Solène Cadiou's work, and has been adapted for reproducible genomic data processing.

A reproducible Snakemake workflow for validating, quality-controlling, harmonizing, 
and preparing imputed genotype data for downstream analyses, including protein quantitative 
trait locus (pQTL) studies.

The workflow starts from autosomal, chromosome-specific PGEN datasets containing dosage information, validates the input files 
before processing, applies configurable sample and variant filters, harmonizes variant 
identifiers and alleles, merges the chromosome-level results, exports final PGEN and BED datasets, 
and generates QC reports.

## Main features

- **Early input validation**: checks PGEN integrity, chromosome labels, variant presence, dosage availability, dosage missingness, and—when MINIMAC3 filtering is selected—the presence of explicitly phased dosages before downstream processing.
- **Autosome-only, chromosome-aware processing**: processes one dosage-containing PGEN/PVAR/PSAM trio per autosome (chromosomes 1–22) and prevents files assigned to the wrong chromosome from entering the workflow.
- **Sample selection**: supports PLINK 2 `--keep`, `--keep-fam`, `--remove`, and `--remove-fam` strategies.
- **Variant identifier standardization**: converts variant identifiers to a consistent `CHR:POS:REF:ALT` representation.
- **Mirror-variant filtering**: identifies and removes variants represented with reversed allele order at the same position.
- **Optional problematic-variant filtering**: removes variants supplied in a project-specific exclusion list.
- **Configurable MAC filtering**: removes variants below the configured minor allele count threshold using PLINK 2.
- **Configurable imputation-quality filtering**: supports INFO-score filtering, MINIMAC3 R² filtering, or no imputation-quality filter.
- **Variant and allele harmonization**: creates mapping files and standardizes final IDs and allele representations.
- **Multiple output formats**: produces an authoritative PLINK 2 PGEN dataset and an optional PLINK 1 BED compatibility export based on hard-called dosages.
- **Reporting and traceability**: generates chromosome-level and combined QC summaries together with run metadata.
- **Reproducible execution**: uses Snakemake, a SLURM profile, and containerized bioinformatics tools.

## Requirements

The host system requires:

- Linux;
- Git;
- Snakemake;
- Conda or Mamba;
- Apptainer or Singularity for container execution;
- SLURM for the supplied cluster profile;
- Graphviz only when generating the workflow DAG.

Bioinformatics tools such as PLINK 2 and qctool are executed through the containers declared in the workflow rules.

The Python environment is defined in [`environment.yml`](environment.yml). Development and formatting dependencies are defined in [`environment_dev.yml`](environment_dev.yml).

## Input data

### Required genotype files

The workflow accepts autosomes only (chromosomes 1–22). For every configured autosome, it expects one matching, chromosome-specific PLINK 2 file trio:

```text
chr{chrom}.pgen
chr{chrom}.pvar
chr{chrom}.psam
```

The filename templates are configurable. For example:

```yaml
pgen_src_path: "/path/to/input"
pgen_template: "chr{chrom}.pgen"
pvar_template: "chr{chrom}.pvar"
```

The `.psam` path is inferred from the PGEN stem, so all three files must share the same basename.
Each PGEN must contain dosage information. Combined genome-wide inputs and chromosome files containing records from more than one chromosome are not supported.

### Input expectations

Before starting the full QC workflow, each chromosome is validated. A valid input dataset must satisfy all enabled checks:

1. The PGEN file must pass PLINK 2 `--validate`.
2. The PVAR file must contain at least one variant.
3. The expected chromosome must be an autosome (1–22).
4. Chromosome labels in the PVAR file must match the chromosome being processed.
5. Labels such as `1`, `chr1`, `CHR1`, and `Chr1` are treated equivalently.
6. Dosage information must be present in the PGEN file.
7. When `filter_by_imputation_quality: "minimac3"`, PLINK 2 `--pgen-info` must report `Explicitly phased dosages present`.
8. Dosage missingness must not exceed the configured maximum.

The explicitly phased-dosage check is specific to the MINIMAC3 strategy. It is recorded as `NOT REQUIRED` and skipped when `filter_by_imputation_quality` is set to `info_score` or `none`; all other input-validation checks still run.

The validation creates a chromosome-specific `.ok` marker only after all checks pass. Downstream rules depend on these markers, so invalid inputs stop the pipeline before any QC transformation is performed.

### Optional supporting files

Depending on the configuration, the workflow may also require:

- an ID list for sample inclusion or exclusion;
- a list of problematic variants;
- a GWASPipe SNP-mapping configuration;
- project-specific paths for final delivery.

## Installation

Clone the repository:

```bash
git clone https://github.com/ht-diva/imputed_genotype_QC_pipe.git
cd imputed_genotype_QC_pipe
```

Create or update the Snakemake environment:

```bash
make dependencies
```

For development dependencies:

```bash
make dev-dependencies
```

## Configuration

Project configurations are stored as:

```text
config/config.<project>.yaml
```

Existing examples include:

- `config/config.example.yaml`;
- `config/config.believe.yaml`;
- `config/config.interval.yaml`.

### Selecting a project

Use one of the Makefile helpers:

```bash
make project-believe
make project-interval
make project-example
```

The selected project name is stored in `.project`. If `.project` is absent, the Makefile uses the default project defined by `DEFAULT_PROJECT`.

To remove the current selection:

```bash
make clean-project
```

You can also bypass project selection and call Snakemake with an explicit configuration:

```bash
snakemake \
    --profile slurm \
    --snakefile workflow/Snakefile \
    --configfile config/config.believe.yaml
```

### Example configuration

The following example documents the main configuration groups. Adapt paths and thresholds to the study.

```yaml
run:
  delivery: false
  filter_problematic_snps: true
  filter_by_imputation_quality: "minimac3"

input_validation:
  max_missing_dosage_rate: 0.0

workspace_path: "results"

pgen_src_path: "/path/to/chromosome_files"
pgen_template: "chr{chrom}.pgen"
pvar_template: "chr{chrom}.pvar"

dest_path: "/path/to/delivery"
problematic_snps_path: "/path/to/problematic_snps.txt"
config_file_path: "config/gwaspipe/config_snp_mapping.yml"

sample_selection_method: "keep-fam"
id_list_path: "/path/to/sample_ids.fam"

plink2_dict:
  mac: 10

export_output_fmt: "bgen-1.1"
minimac3-r2-filter: 0.3
INFO_score: "0.7"
```

### Run options

| Option | Values | Description |
| --- | --- | --- |
| `delivery` | `true`, `false` | Enables or disables creation of the delivery structure. |
| `filter_problematic_snps` | `true`, `false` | Enables or disables filtering with the supplied problematic-variant list. |
| `filter_by_imputation_quality` | `info_score`, `minimac3`, `none` | Selects the imputation-quality filtering strategy. |

### Input-validation options

| Option | Example | Description |
| --- | ---: | --- |
| `max_missing_dosage_rate` | `0.0` | Maximum permitted dosage missingness. `0.0` requires complete dosage data. |

### Sample-selection options

| Value | PLINK 2 behavior |
| --- | --- |
| `keep` | Keeps sample IDs using `--keep`. |
| `keep-fam` | Keeps family/sample IDs using `--keep-fam`. |
| `remove` | Removes sample IDs using `--remove`. |
| `remove-fam` | Removes family/sample IDs using `--remove-fam`. |

The format of `id_list_path` must match the selected method.

### MAC-filtering parameter

The MAC threshold is configured under `plink2_dict` and passed to PLINK 2:

| Parameter | Meaning |
| --- | --- |
| `mac` | Minimum minor allele count required for a variant to be retained. |

The threshold must be selected for the study design and sample size; the example value is not a universal recommendation.

### Imputation-quality strategies

The workflow supports three values for `filter_by_imputation_quality`:

- `info_score`: generates BGEN data, computes qctool SNP statistics, selects variants meeting `INFO_score`, and extracts them from the chromosome-specific PGEN files. Explicitly phased dosages are not required by the pipeline validation for this strategy;
- `minimac3`: first requires `plink2 --pgen-info` to report `Explicitly phased dosages present`, then applies the configured `minimac3-r2-filter` threshold;
- `none`: skips imputation-quality filtering and passes the preceding QC dataset to harmonization.

## Running the pipeline

### Recommended checks

Confirm the selected project:

```bash
make
```

Inspect the planned jobs without executing them:

```bash
make dry-run
```

Generate a DAG:

```bash
make dag
```

This writes `dag.svg`.

### Submit the workflow

Submit the supplied SLURM wrapper:

```bash
sbatch submit.sbatch
```

Alternatively, start it through the Makefile from an appropriate execution environment:

```bash
make run
```

### Resume an interrupted workflow

Snakemake normally resumes from the existing outputs. To explicitly rerun incomplete jobs:

```bash
make rerun
```

### Unlock after an interrupted run

If the controlling Snakemake process was killed, the working directory may remain locked. First confirm that no other Snakemake process is using the same directory, then run:

```bash
make unlock
```

Never unlock a directory while another workflow is actively writing the same outputs.

## Pipeline steps

### 1. Input validation

For every chromosome, `validate_imputed_input`:

- creates the validation output directory when necessary;
- validates PGEN integrity with PLINK 2;
- confirms that the PVAR file contains variants;
- normalizes chromosome labels for validation;
- requires the expected chromosome to be an autosome (1–22);
- verifies that the PVAR chromosome matches the chromosome wildcard;
- confirms that dosages are present;
- conditionally requires explicitly phased dosages when `filter_by_imputation_quality` is set to `minimac3`;
- records the explicitly phased-dosage check as `NOT REQUIRED` for the `info_score` and `none` strategies;
- calculates dosage genotyping rate and derives dosage missingness;
- compares dosage missingness with `max_missing_dosage_rate`;
- creates `{chrom}_imputed_input.ok` only when every check passes.

The validation outputs make it possible to distinguish PGEN corruption, chromosome-label problems, absent dosages, missing explicitly phased dosages for MINIMAC3 filtering, and excessive dosage missingness.

### 2. Variant-list preparation and input summaries

The workflow combines PVAR information across chromosomes to create mapping lists used later in the pipeline. It also generates basic information reports for the original chromosome-specific datasets.

### 3. Variant ID standardization

Variant identifiers are standardized to a coordinate-and-allele representation:

```text
CHR:POS:REF:ALT
```

This provides stable identifiers for filtering and harmonization.

### 4. Sample selection

Samples are included or excluded using the method configured by `sample_selection_method` and the file supplied through `id_list_path`.

### 5. Mirror-variant filtering

The workflow identifies variant pairs at the same chromosome and position whose alleles are represented in reversed order, for example:

```text
1:12345:A:G
1:12345:G:A
```

These mirror variants are recorded and removed to avoid ambiguous downstream representation.

### 6. Optional problematic-variant filtering

When enabled, the supplied problematic-variant list is normalized and matching variants are removed. When disabled, the workflow continues from the mirror-filtered dataset.

### 7. PLINK 2 MAC filtering

The workflow uses PLINK 2 to remove variants below the configured minor allele count (MAC) threshold.

### 8. Optional imputation-quality filtering

The selected `info_score`, `minimac3`, or `none` path is applied independently to each chromosome.

### 9. SNP mapping and harmonization

Mapping files are generated for downstream harmonization. Variant identifiers and alleles are then updated to a consistent representation across chromosomes.

### 10. Merge and format conversion

Final chromosome-specific PGEN files are merged into a genome-wide PGEN dataset. This harmonized PGEN is the authoritative imputed dataset.

For compatibility with software that requires PLINK 1 files, the workflow can also convert the harmonized chromosome-level PGEN files to BED and merge them. During this conversion, PLINK 2 is run with `--hard-call-threshold 0.49999999`. This is an extremely permissive threshold, meaning that almost every dosage is converted to its nearest hard call.

> **Warning:** BED is an optional compatibility export and should be used with caution because it is based on hard-called dosages. The harmonized PGEN remains the authoritative imputed dataset. If the PGEN contains true multiallelic variants, BED cannot represent them as faithfully as PGEN; BED export may therefore require additional handling for datasets containing true multiallelic records.

### 11. Reports and delivery

The workflow creates filtering and harmonization reports. If delivery is enabled, final files are organized under the configured destination path.

## Output structure

The exact filenames depend on configuration and enabled branches. A typical workspace contains:

```text
results/
├── pgen/
│   ├── validation/
│   │   ├── {chrom}_imputed_input.validate.log
│   │   ├── {chrom}_imputed_input.pgen_info.txt
│   │   ├── {chrom}_imputed_input.dosage_missingness.log
│   │   └── {chrom}_imputed_input.ok
│   ├── filtering/
│   ├── qc/
│   ├── qc_harmonised/
├── bed/
│   └── qc_harmonised/
├── reports/
│   ├── all_chromosomes_stage_qc_report.tsv
│   ├── all_chromosomes_filtering_summary_report.txt
│   ├── all_chromosomes_filtering_summary_report.tsv
│   └── all_chromosomes_harmonization_summary_report.txt
└── README.txt
```

### Validation files

| File | Meaning |
| --- | --- |
| `*.validate.log` | PLINK 2 PGEN validation output plus chromosome-validation status, including the conditional MINIMAC3 explicitly phased-dosage check. |
| `*.pgen_info.txt` | PGEN metadata used to confirm dosage presence and, for MINIMAC3 filtering, explicitly phased dosages. |
| `*.dosage_missingness.log` | Dosage genotyping-rate output, calculated missingness, configured threshold, and PASS/FAIL status. |
| `*.ok` | Completion marker created only after all input checks pass. |

If a validation job fails, Snakemake may remove incomplete files because they are declared as rule outputs. Use `--keep-incomplete` during diagnosis when those partial files are needed.

## QC reports

The pipeline generates several complementary QC reports. The main summary file is `all_chromosomes_stage_qc_report.tsv`, which provides a consolidated overview of all processing and QC stages across chromosomes.

The stage QC report includes sample and variant counts before and after each stage, the number of removed variants, filtering methods and thresholds, dosage completeness, dosage missingness, and PASS/FAIL status where available.

Depending on the selected path, the reports can include stages such as:

- input data;
- sample selection;
- mirror filtering;
- problematic-variant filtering;
- MAC filtering;
- imputation-quality filtering;
- final harmonized data.

The other combined filtering and harmonization reports provide detailed textual or tabular summaries of their respective workflow sections.

| Report | Description |
| --- | --- |
| `all_chromosomes_stage_qc_report.tsv` | Main consolidated chromosome-level summary of all processing and QC stages. |
| `all_chromosomes_filtering_summary_report.tsv` | Tabular summary of chromosome-level filtering results. |
| `all_chromosomes_filtering_summary_report.txt` | Human-readable filtering summary. |
| `all_chromosomes_harmonization_summary_report.txt` | Human-readable summary of harmonization results. |

The generated `README.txt` records run traceability information, including repository state and configuration-related metadata.

## Troubleshooting

### Find the rule-specific SLURM log

Snakemake reports the exact log path when a cluster job fails. Validation logs follow a structure similar to:

```text
.snakemake/slurm_logs/rule_validate_imputed_input/{chrom}/{job_id}.log
```

Display the end of the latest log for a chromosome:

```bash
latest_log=$(ls -t .snakemake/slurm_logs/rule_validate_imputed_input/14/*.log | head -n 1)
tail -n 100 "$latest_log"
```

### Preserve partial validation outputs

For targeted diagnosis:

```bash
snakemake \
    results/pgen/validation/14_imputed_input.ok \
    --force \
    --keep-incomplete \
    --printshellcmds
```

Then inspect:

```bash
cat results/pgen/validation/14_imputed_input.validate.log
cat results/pgen/validation/14_imputed_input.pgen_info.txt
cat results/pgen/validation/14_imputed_input.dosage_missingness.log
```

### Validation directory is absent

The validation rule creates its output directory before running PLINK 2. If it is absent after a failed run, confirm that the current workflow version contains the directory-creation command and that Snakemake is reading the expected checkout and branch.

### `.ok` is absent

The `.ok` file is not a diagnostic log. It is created only after the entire validation rule succeeds. Its absence means that at least one validation check failed or the job was interrupted.

### SLURM reports only `FAILED`

`SLURM status is: FAILED` is a summary, not the underlying cause. Read the rule-specific log and, when necessary, query accounting information:

```bash
sacct -j JOB_ID \
    --format=JobID,State,ExitCode,Elapsed,Timelimit,MaxRSS,ReqMem
```

- `FAILED` with exit code 1 usually indicates a command or validation failure;
- `OUT_OF_MEMORY` indicates insufficient memory;
- `TIMEOUT` indicates an insufficient time limit;
- `NODE_FAIL` indicates a cluster/node failure.

Do not increase resources unless SLURM accounting supports a resource-related cause.

### Working directory is locked

Confirm that no other Snakemake instance is active:

```bash
squeue -u "$USER"
pgrep -afu "$USER" snakemake
```

If none is active, run:

```bash
make unlock
```

### Stop submitted jobs

List your jobs:

```bash
squeue -u "$USER"
```

Cancel selected jobs with `scancel JOB_ID`. The following command cancels all jobs belonging to the current user and should therefore be used with care:

```bash
scancel -u "$USER"
```

## Rule reference

The table below groups the principal rules by purpose. Optional rules run only when selected by the configuration.

| Stage | Rule | Purpose |
| --- | --- | --- |
| Input validation | `validate_imputed_input` | Validate PGEN integrity, chromosome labels, variant presence, dosage availability, conditional MINIMAC3 explicitly phased dosages, and dosage missingness. |
| Input preparation | `list_rs` | Combine PVAR records and generate variant-ID mapping lists. |
| Input reporting | `header_info` | Generate basic information for each original chromosome dataset. |
| ID standardization | `recode_pgen` | Replace input variant IDs with standardized coordinate-and-allele IDs. |
| Sample selection | `select_samples` | Keep or remove samples according to the configured method and ID list. |
| Problematic variants | `sanitize_problematic_snps` | Normalize the supplied problematic-variant list. |
| Problematic variants | `filter_problematic_snps` | Remove variants from the configured problematic-variant list. |
| Mirror variants | `get_mirror_snps` | Identify reversed-allele variant pairs at the same position. |
| Mirror variants | `filter_mirror_snps` | Remove identified mirror variants. |
| MAC filtering | `filter_var` | Remove variants below the configured PLINK 2 MAC threshold. |
| INFO filtering | `create_bgen` | Convert filtered PGEN data to BGEN for INFO-statistic processing. |
| INFO filtering | `qctool` | Calculate SNP statistics from BGEN data. |
| INFO filtering | `get_hq_variants` | Select variants meeting the configured INFO threshold. |
| INFO filtering | `filter_hq_variants` | Extract INFO-filtered variants from PGEN data. |
| MINIMAC3 filtering | `filter_by_minimac3` | Apply the configured MINIMAC3 R² threshold. |
| Mapping | `build_snp_mapping_files` | Generate mapping resources for harmonization. |
| Harmonization | `update_pgen_id` | Update variant identifiers to the harmonized representation. |
| Harmonization | `update_pgen_alleles` | Align allele representation with harmonized identifiers. |
| PGEN merge | `merge_qc_harmonised_pgen` | Merge final chromosome-specific PGEN files. |
| BED conversion | `pgen2bed` | Optionally convert harmonized PGEN data to hard-called BED format using `--hard-call-threshold 0.49999999`. |
| BED merge | `merge_qc_harmonised_bed` | Merge chromosome-specific BED files. |
| Reporting | `generate_chromosome_summary_report` | Generate filtering summaries in text and tabular formats. |
| Reporting | `generate_harmonization_summary_report` | Generate the combined harmonization report. |
| Traceability | `write_readme` | Record run and repository metadata in the output workspace. |
| Delivery | delivery rules | Copy and organize final deliverables when enabled. |

## Development and acknowledgements

This pipeline builds on work by Alessia Mapelli and Solène Cadiou and was adapted for reproducible genomic-data processing.

Development and implementation were carried out by:

- Gianmauro Cuccuru;
- Claudia Teresa Maria Giambartolomei;
- Giulia Pontali.

Contributions, bug reports, and improvement proposals can be submitted through the repository's [GitHub Issues](https://github.com/ht-diva/imputed_genotype_QC_pipe/issues).

## Citation

If you use this workflow, cite the repository and record the exact commit or release used for the analysis. The output traceability file should be retained with the final results.

