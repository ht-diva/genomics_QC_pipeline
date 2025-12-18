# ----------------------------------------------------------------------
#  Project handling
# ----------------------------------------------------------------------
# Default project (used if no .project file exists)
DEFAULT_PROJECT ?= example

# .project file – contains the name of the active project
PROJECT_FILE := .project

# Resolve the active project:
#   1️⃣ If the file exists, read its contents.
#   2️⃣ Otherwise fall back to DEFAULT_PROJECT.
PROJECT := $(or $(shell cat $(PROJECT_FILE) 2>/dev/null),$(DEFAULT_PROJECT))

# Full config‑file path derived from the project name
CONFIGFILE := config/config.$(PROJECT).yaml

# ----------------------------------------------------------------------
#  Common Snakemake command parts
# ----------------------------------------------------------------------
SNAKEFILE = workflow/Snakefile
PROFILE   = --profile slurm
BASE_CMD  = snakemake $(PROFILE) --snakefile $(SNAKEFILE) --configfile $(CONFIGFILE)

# Targets list (unchanged)
TARGETS = dependencies dag run unlock

# ----------------------------------------------------------------------
#  Top level
# ----------------------------------------------------------------------
all:
	@echo "Try one of: ${TARGETS}"
	@echo "Current project: $(PROJECT) (config → $(CONFIGFILE))"

# ----------------------------------------------------------------------
#  DAG
# ----------------------------------------------------------------------
dag:
	$(BASE_CMD) --dag | dot -Tsvg > dag.svg

# ----------------------------------------------------------------------
#  Environment
# ----------------------------------------------------------------------
dependencies:
	mamba env update -n snakemake --file environment.yml

dev-dependencies: dependencies
	mamba env update -n snakemake --file environment_dev.yml

# ----------------------------------------------------------------------
#  Dry‑run
# ----------------------------------------------------------------------
dry-run:
	$(BASE_CMD) --sdm conda --dry-run

# ----------------------------------------------------------------------
#  Run
# ----------------------------------------------------------------------
run:
	$(BASE_CMD)

rerun:
	$(BASE_CMD) --rerun-incomplete

unlock:
	snakemake --unlock --configfile $(CONFIGFILE)

dockerfile_:
	snakemake --containerize --snakefile $(SNAKEFILE) > DockerFile

pre-commit:
	if [ ! -f .git/hooks/pre-commit ]; then pre-commit install; fi
	pre-commit run --all-files

# ----------------------------------------------------------------------
#  Project helpers – create/override the .project file
# ----------------------------------------------------------------------
project-interval:
	@echo "interval" > $(PROJECT_FILE)
	@echo "✅ Project set to 'interval' (config → $(CONFIGFILE))"

project-believe:
	@echo "believe" > $(PROJECT_FILE)
	@echo "✅ Project set to 'believe' (config → $(CONFIGFILE))"

project-%:
	@echo "$*" > $(PROJECT_FILE)
	@echo "✅ Project set to '$*' (config → $(CONFIGFILE))"

# ----------------------------------------------------------------------
#  Clean up helper (optional)
# ----------------------------------------------------------------------
clean-project:
	@rm -f $(PROJECT_FILE)
	@echo "🗑️  Removed $(PROJECT_FILE); next run will fall back to DEFAULT_PROJECT='$(DEFAULT_PROJECT)'"
