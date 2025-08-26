import pandas as pd


sample_name_constraint = "[A-Za-z][A-Za-z0-9]+"
wildcard_constraints:
    sample=sample_name_constraint,


# Load sample.csv or sample.tsv
try:
    SampleTable = pd.read_csv("samples.csv", index_col=0)
except FileNotFoundError:
    try:
        SampleTable = pd.read_csv("samples.tsv", sep="\t", index_col=0)
    except FileNotFoundError:
        raise FileNotFoundError(
            "Sample table not found. Please provide a 'samples.csv' or 'samples.tsv' file."
        )

# make some checks on sample names
assert SampleTable.index.is_unique, "Sample table index is not unique"
assert SampleTable.index.str.match(
    sample_name_constraint
).all(), "Not all sample names correspond to sample name criteria"


# check if QC fastq files are provided
if not SampleTable.columns.str.startswith("Reads_QC").any():
    import warnings

    warnings.warn(
        "QC-Fastq paths not in sample table, use default 'QC/reads/{sample}_{fraction}.fastq.gz'"
    )

# HACK: limit to 5 samplse
SAMPLES = SampleTable.index.tolist()[:5]
PAIRED = SampleTable.columns.str.contains("R2").any()

if PAIRED:
    FRACTIONS = ["R1", "R2"]
else:
    FRACTIONS = ["se"]


def get_qc_reads(wildcards):
    headers = ["Reads_QC_" + f for f in FRACTIONS]

    try:
        return SampleTable.loc[wildcards.sample, headers]
    except KeyError:
        return expand("QC/reads/{{sample}}_{fraction}.fastq.gz", fraction=FRACTIONS)


def get_raw_reads(wildcards):
    headers = ["Reads_raw_" + f for f in FRACTIONS]
    fastq_dir = Path(config["fastq_dir"])

    return [fastq_dir / f for f in SampleTable.loc[wildcards.sample, headers]]
