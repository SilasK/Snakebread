
HUMANN_DB_DIR = DB_DIR / "Humann"


localrules:
    download_chocophlan,
    download_uniref,


rule download_chocophlan:
    output:
        directory(HUMANN_DB_DIR / "nucleotide"),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/download/download_chocophlan.log",
    shell:
        "humann_databases --update-config yes "
        " --download chocophlan full {output} &> {log}"


rule download_uniref:
    output:
        directory(HUMANN_DB_DIR / "protein"),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/download/download_uniref.log",
    shell:
        "humann_databases --update-config yes "
        " --download uniref uniref90_diamond {output} &> {log}"


#        " --download utility_mapping full {config[database_dir]} "



rule humann:
    input:
        reads=get_qc_reads,
        nucleotide_db=ancient(HUMANN_DB_DIR / "nucleotide"),
        protein_db=ancient(HUMANN_DB_DIR / "protein"),
    output:
        multiext(
            "Intermediate/humann/output/{sample}_",
            "genefamilies.tsv",
            "pathcoverage.tsv",
            "pathabundance.tsv",
        ),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/humann/{sample}.log",
        "Intermediate/humann/output/{sample}.log",
    params:
        output_dir=lambda wc, output: Path(output[0]).parent,
        humann_params=config["humann_params"],
    threads: config["threads_default"]
    resources:
        mem_mb=config["mem_default"] * 1024,
    shell:
        "cat -v {input} > {resources.tmpdir}/humann_{wildcards.sample}.fastq.gz 2> {log}"
        " ; "
        "humann "
        "-i {resources.tmpdir}/humann_{wildcards.sample}.fastq.gz "
        " -o {params.output_dir} "
        " --output-basename {wildcards.sample} "
        " --threads {threads} "
        " {params.humann_params} "
        " --nucleotide-database {input.nucleotide_db}/chocophlan "
        " --protein-database {input.protein_db}/uniref "
        " &>> {log} "


rule humann_renorm_table:
    input:
        "Intermediate/humann/output/{sample}_{type}.tsv",
    output:
        "Intermediate/humann/output/{sample}_{type}_cpm.tsv",
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/renorm/{type}/{sample}.log",
    params:
        unit="cpm",
    threads: 1
    resources:
        mem_mb=config["mem_simple"] * 1024,
    shell:
        "humann_renorm_table --input {input} --output {output} --units {params.unit} &>  {log} "


rule merge_tsv:
    input:
        expand(
            "Intermediate/humann/output/{sample}_{{type_and_norm}}.tsv", sample=SAMPLES
        ),
    output:
        "Functions/humann_{type_and_norm}.tsv",
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/merge_tsv/{type_and_norm}.log",
    params:
        Search_dir="Humann",
    threads: 1
    resources:
        mem_mb=config["mem_default"] * 1024,
    shell:
        " humann_join_tables -i {params.Search_dir} -o {output} --file_name {wildcards.type_and_norm} "
