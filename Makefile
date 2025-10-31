# --- Variables ---------------------------------------------------------------
# Common Snakemake command parts
SNAKEFILE = workflow/Snakefile
PROFILE   = --profile slurm
SDM       = --sdm conda
BASE_CMD  = snakemake $(PROFILE) $(SDM) --snakefile $(SNAKEFILE)

# Config files for the different runs
# use the --configfile command line argument to overwrite values from the configfile statement.
# command line overwrites the same key of the configfile statement.
CONFIG_BELIEVE  = config/config.believe.yaml
CONFIG_INTERVAL = config/config.interval.yaml

# Targets list
TARGETS = dependencies dag run unlock

# --- Top level ---------------------------------------------------------------
all:
	@echo "Try one of: ${TARGETS}"

# --- DAG --------------------------------------------------------------------
dag:
	snakemake --dag | dot -Tsvg > dag.svg

# --- Environment ------------------------------------------------------------
dependencies:
	mamba env update -n snakemake --file environment.yml

dev-dependencies: dependencies
	mamba env update -n snakemake --file environment_dev.yml

# --- Dry‑run ---------------------------------------------------------------
dry-run:
	$(BASE_CMD) --dry-run

dry-run-believe:
	$(BASE_CMD) --dry-run --configfile $(CONFIG_BELIEVE)

dry-run-interval:
	$(BASE_CMD) --dry-run --configfile $(CONFIG_INTERVAL)

# --- Run --------------------------------------------------------------------
run:
	$(BASE_CMD)

run-believe:
	$(BASE_CMD) --configfile $(CONFIG_BELIEVE)

run-interval:
	$(BASE_CMD) --configfile $(CONFIG_INTERVAL)

# --- Misc -------------------------------------------------------------------
rerun:
	$(BASE_CMD) --rerun-incomplete

unlock:
	snakemake --unlock

dockerfile_:
	snakemake --containerize --snakefile $(SNAKEFILE) > Dockerfile

pre-commit:
	if [ ! -f .git/hooks/pre-commit ]; then pre-commit install; fi
	pre-commit run --all-files
