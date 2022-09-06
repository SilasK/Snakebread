import os, sys
import logging, traceback

logging.basicConfig(
    filename=snakemake.log[0],
    level=logging.INFO,
    format="%(asctime)s %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)


def handle_exception(exc_type, exc_value, exc_traceback):
    if issubclass(exc_type, KeyboardInterrupt):
        sys.__excepthook__(exc_type, exc_value, exc_traceback)
        return

    logging.error(
        "".join(
            [
                "Uncaught exception: ",
                *traceback.format_exception(exc_type, exc_value, exc_traceback),
            ]
        )
    )


# Install exception handler
sys.excepthook = handle_exception

## Start of the script

from biom import load_table



input_fps = snakemake.input
output_fp = snakemake.output[0]


# This is the content of https://github.com/biocore/qiime/blob/master/scripts/merge_otu_tables.py
merged = load_table(input_fps[0])

for input_fp in input_fps[1:]:
    merged = merged.merge(load_table(input_fp))

# write the merged table to tsv
merged.to_tsv(header_key="taxonomy", 
header_value=None,
observation_column_name='#OTU ID')


