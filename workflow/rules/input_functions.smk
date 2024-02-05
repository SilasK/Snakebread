

pepfile: "sample_table_config.yaml"


# pepschema: f"{snakemake_dir.parent}/config/sample_table_schema.yaml"


SAMPLES = pep.sample_table["sample_name"]
PAIRED = pep.sample_table.columns.str.contains("R2").any()

if PAIRED:
    FRACTIONS = ["R1", "R2"]
else:
    FRACTIONS = ["se"]





def get_qc_reads(wildcards):
    headers = ["Reads_qc_" + f for f in FRACTIONS]
    return pep.sample_table.loc[wildcards.sample, headers]
