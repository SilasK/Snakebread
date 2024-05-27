import os, sys
import logging, traceback

logging.basicConfig(
    # filename=snakemake.log[0],
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

import pandas as pd
from collections import defaultdict


def extract_data(file_path):
    """
    Extracts data from a single file.

    Args:
        file_path: Path to the file.

    Returns:
        A tuple containing:
            - A dictionary with header information (estimated reads and processed reads)
            - A list of rows containing data from lines containing "t__"
    """

    stats = {}
    rows = []
    header = None
    with open(file_path, "r") as f:
        for line in f:
            if line.startswith("#"):
                line = line[1:].strip()
                if line.startswith("mpa"):
                    stats["db_version"] = line
                elif line.startswith("estimated_reads_mapped_to_known_clades"):
                    stats["mapped_reads"] = int(line.split(":")[1])
                elif "reads processed" in line:
                    stats["processed_reads"] = int(line.split()[0])
                elif line.startswith("SampleID"):
                    stats["SampleID"] = line.split()[1]
                elif line.startswith("clade_name"):
                    header = line.split()

            else:
                rows.append(line.strip().split())

    data = pd.DataFrame(data=rows, columns=header).set_index(
        ["clade_name", "clade_taxid"]
    )
    return stats, data


from pathlib import Path

input_files = input_files = snakemake.input
combined_data = {}
combined_stats = []

for file_path in input_files:
    stats, data = extract_data(file_path)
    combined_data[stats["SampleID"]] = data.relative_abundance
    combined_stats.append(pd.Series(stats))


stats = pd.concat(combined_stats, axis=1).T.set_index("SampleID")


assert stats.db_version.nunique() == 1, "You have different metaphaln versions"


# transposed cladenames is index
abundance = pd.concat(combined_data, axis=1).fillna(0).astype(float)

# max profile

max_abundance = abundance.max(axis=1).sort_index()


with open(snakemake.output[0], "w") as fout:
    fout.write(f"#{stats.db_version.iloc[0]}\n")
    fout.write("#clade_name\tclade_taxid\trelative_abundance\n")

max_abundance.to_csv(snakemake.output[0], mode="a", sep="\t", header=False)
