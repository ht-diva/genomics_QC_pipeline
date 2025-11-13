# genomics_QC_pipeline
The genomic QC pipeline is designed to clean and prepare imputed genotype data for pQTL analysis.
All the rules were based on Alessia Mapelli’s work: [https://github.com/ht-diva/pqtl-believe-interval/blob/main/Script_QC_INTERVAL_genomics.R]


## Requirements
* Singularity

see also [environment.yml](environment.yml) and [Makefile](Makefile)

## Getting started

* git clone https://github.com/ht-diva/genomics_QC_pipeline.git
* cd genomics_QC_pipeline

**Choosing a project**

The pipeline can be run with different configuration sets (e.g., `interval`, `believe`, …).

Set the active project by creating/updating the hidden `.project` file **or** by using one of the Makefile helpers:
  ```bash
  make project-interval   # uses config/config.interval.yaml
  make project-believe    # uses config/config.believe.yaml
  make project-<name>     # any custom name matching config/config.<name>.yaml
  ```
The selected project is shown when you run `make` (it prints “Current project: …”).

Then run the pipe with:
  ```bash
  sbatch submit.sbatch
  ```


The output is written to the path defined by the **workspace_path** variable in the config.yaml file. By default, this path is `./results`.

## Rules description
1. **get_mirror_snps**: <br />
*Purpose:* Generate a list of all mirror SNPs ( X:XXXXXXX:A:B and X:XXXXXXX:B:A) <br />
*Output:* A list of mirror SNPs pairs <br />

2. **filter_mirror_snps**: <br />
*Purpose:* Filter out the mirror SNPs pairs <br />
*Output:* Updated pgen files without mirror SNPs pairs. <br />

3. **filter_problematic_snps**: <br />
*Purpose:* Filter out a list of problematic SNPs <br />
*Output:* Updated pgen files without problematic SNPs. <br />

4. **list_rs:** <br />
*Purpose:* Generate lists of all rsIDs and pseudo biallelic variants from the initial pgen file.<br />
*Output:* Two files – one containing all rsIDs and the other containing pseudo biallelic variants.<br />

5. **recode_pgen:** <br />
*Purpose:* Replace the IDs in the imputed pgen file with a new format: chr:pos:ref:alt. <br />
*Output:* An updated pgen file with the new ID format. <br />

6. **selected_sample:** <br />
*Purpose:* Select individuals who are present in both the 2018 data and have corresponding proteomic data. <br />
*Output:* A filtered list of individuals. <br />

7. **filter_var:** <br />
*Purpose:* Perform several quality control steps: remove additional failed samples, identify and remove heterozygosity outliers, perform minor allele frequency (MAF) filtering, remove related samples based on Hardy-Weinberg equilibrium (HWE). <br />
*Output:* A cleaned dataset with high-quality variants and samples. <br />

8. **create_bgen:** <br />
*Purpose:* Convert the filtered data from the previous steps into bgen format, a commonly used format for storing large-scale genotype data. <br />
*Output:* A bgen file containing the cleaned genotype data. <br />

9. **qctool:** <br />
*Purpose:* Compute SNP statistics using qctool, ensuring the quality of the variants. <br />
*Output:* SNP statistics file. <br />

10. **get_hq_variants:** <br />
*Purpose:* Filter variants to retain only those with an info score greater than 0.7. <br />
*Output:* A list of high-quality variants. <br />

11. **filter_hq_variants:** <br />
*Purpose:* Extract SNPs with an info score greater than 0.7 from the pgen file and create a new pgen file for each chromosome. <br />
*Output:* pgen files for each chromosome containing only high-quality variants. <br />

12. **merge_filter_hq_variants:** <br />
*Purpose:* Merge the chromosome-specific pgen files from the previous step into a single pgen file. <br />
*Output:* A combined pgen file containing high-quality variants from all chromosomes. <br />

13. **update_pgen_id:** <br />
*Purpose:* Update the variant IDs in the pgen file to the format chr:pos:A0:A1, with A0 and A1 in alphabetical order. <br />
*Output:* An updated pgen file with harmonised IDs. <br />

14. **update_pgen_alleles:** <br />
*Purpose:* Harmonize the alleles in the pgen file to match the new IDs. <br />
*Output:* A pgen file with harmonised alleles. <br />

15. **merge_filter_hq_variants_new_id_alleles_pgen:** <br />
*Purpose:* Merge all the pgen files from the previous step into a final single pgen file. <br />
*Output:* A final combined pgen file with harmonised IDs and alleles, ready for pQTL analysis. <br />

16. **pgen2bed:** <br />
*Purpose:* Convert pgen file into bed format. Set hard-call-threshold equal to 0.49999999. <br />
*Output:* A bed file with harmonised alleles and minimized missing dosage. <br />

17. **merge_filter_hq_variants_new_id_alleles_bed:** <br />
*Purpose:* Merge all the bed files from the previous step into a final single bed file. <br />
*Output:* A final combined bed file. <br />

## Output
1. **pgen** folder (contains raw pgen files with the new IDs format: chr:pos:ref:alt) <br />
   - qc_recoded subfolder (contains pgen files that have been processed through quality control and recoding steps but not yet harmonised.)
   - qc_recoded_harmonised subfolder (contains pgen files that have been both quality controlled, recoded, and harmonised.)
2. **bed** folder
   - qc_recoded_harmonised subfolder (contains bed files that have been harmonised.)
