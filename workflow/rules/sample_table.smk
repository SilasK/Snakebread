import pandas as pd


sample_name_constraint = "[A-Za-z][A-Za-z0-9]+"
wildcard_constraints:
    sample=sample_name_constraint,

sample_table_file="samples.csv"
SampleTable = pd.read_csv(sample_table_file, index_col=0)



assert SampleTable.index.is_unique, "Sample table index is not unique"
assert SampleTable.index.str.match(sample_name_constraint).all(), "Not all sample names correspond to sample name criteria"



SAMPLES = SampleTable.index.tolist()
PAIRED = SampleTable.columns.str.contains("R2").any()

if PAIRED:
    FRACTIONS = ["R1", "R2"]
else:
    FRACTIONS = ["se"]





def get_qc_reads(wildcards):
    headers = ["Reads_QC_" + f for f in FRACTIONS]
    
    files = SampleTable.loc[wildcards.sample, headers]

    if files.isnull().all():

        logger.warning("QC-Fastq paths not in sample table, use default ones")
        return expand("QC/reads/{{sample}}_{fraction}.fastq.gz", fraction=FRACTIONS)
    else:
        return files



def get_raw_reads(wildcards):
    headers = ["Reads_raw_" + f for f in FRACTIONS]
    fastq_dir = Path(config["fastq_dir"])

    return [fastq_dir / f for f in pep.sample_table.loc[wildcards.sample, headers]]

