# /usr/bin/env bash

# snakemake --version

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"


snakefile="$SCRIPT_DIR/workflow/Snakefile"

CONFIG_FILE="./biobakery_config.yaml"

if [ ! -f "$CONFIG_FILE" ]; then
  # File does not exist, copy the source file to the destination
  cat "Copy config file, change parameters you want."

  cp "$SCRIPT_DIR/config/template_config.yaml" "$CONFIG_FILE"

  exit 0

  
fi


snakemake -s $snakefile --configfile $CONFIG_FILE \
--rerun-triggers mtime \
--profile cluster \
--jobs 50 \
--use-conda \
$@


