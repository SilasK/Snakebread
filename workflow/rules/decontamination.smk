import os


kraken_db_files = ("hash.k2d", "opts.k2d", "taxo.k2d")

Kraken_db_folder = DB_DIR / "Kraken/human_pangenome"


localrules:
    download_human_pangenome_db,


rule download_human_pangenome_db:
    output:
        Kraken_db_folder.parent / "k2_HPRC_20230810.tar.gz",
    log:
        "logs/download/download_kraken_human_pangenome.log",
    shell:
        "wget https://zenodo.org/records/8339732/files/k2_HPRC_20230810.tar.gz -O {output} 2> {log} ;\n"


rule extract_human_pangenome_db:
    input:
        Kraken_db_folder.parent / "k2_HPRC_20230810.tar.gz",
    output:
        directory(Kraken_db_folder),
    log:
        "logs/download/download_kraken_human_pangenome.log",
    shell:
        " tar -xzvf {input} -C {resources.tmpdir} 2>> {log} ; \n"
        " mv {resources.tmpdir}/db {output} 2>> {log}"


def get_kraken_db_files():
    "depending on wildcard 'db_name'"
    return multiext(f"{Kraken_db_folder}/", *kraken_db_files)


Kraken_db_size = 0


def calculate_kraken_memory(overhead=7000):
    "Calculate db size of kraken db. in MB"
    " depending on input.db_files"

    global Kraken_db_size

    if Kraken_db_size is None:
        kraken_db_files = get_kraken_db_files()
        db_size_bytes = sum(os.path.getsize(f) for f in kraken_db_files)

        Kraken_db_size = db_size_bytes // 1024**2 + 1 + overhead

    return Kraken_db_size


rule kraken_pe:
    input:
        reads=expand(
            "Intermediate/qc/reads/trimmed/{{sample}}_{fraction}.fastq.gz",
            fraction=["R1","R2"],
        ),
        db=ancient(Kraken_db_folder),
    output:
        reads=expand("QC/reads/{{sample}}_{fraction}.fastq.gz", fraction=FRACTIONS),
    log:
        "logs/qc/decontamination/{sample}.log",
    benchmark:
        "logs/benchmark/kraken2_human/{sample}.tsv"
    conda:
        "../envs/kraken.yaml"
    resources:
        mem_mb=calculate_kraken_memory,
        time_min=config["time_short"] * 60,
    threads: config["threads_default"]
    shell:
        " kraken2 "
        " --db {input.db} "
        " --threads {threads} "
        " --output - "
        " --unclassified-out {resources.tmpdir}/{wildcards.sample}#.fastq "
        " --paired "
        " {input.reads} "
        " &> {log} "
        "; \n"
        " pigz -p{threads} -c {resources.tmpdir}/{wildcards.sample}_1.fastq > {output.reads[0]}  2>> {log} ; \n "
        " pigz -p{threads} -c {resources.tmpdir}/{wildcards.sample}_2.fastq > {output.reads[1]}  2>> {log} ; \n "




localrules: kraken_stats
rule kraken_stats:
    input:
        expand("logs/qc/decontamination/{sample}.log",sample=SAMPLES)
    output:
        "Reports/decontamination_stats.csv"
    log:
        "logs/qc/summarize_decontamination.log",
    script:
        "../scripts/parse_kraken_output.py"