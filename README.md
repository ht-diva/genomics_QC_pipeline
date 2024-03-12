# genomics_QC_pipeline

## Requirements
* Singularity

see also [environment.yml](environment.yml) and [Makefile](Makefile)

## Getting started

* git clone https://github.com/ht-diva/genomics_QC_pipeline.git
* cd genomics_QC_pipeline
* adapt the [submit.sbatch](submit.sbatch) and [config/config.yaml](config/config.yaml) files to your environment
* sbatch submit.sbatch

The output is written to the path defined by the **workspace_path** variable in the config.yaml file. By default, this path is `./results`.
