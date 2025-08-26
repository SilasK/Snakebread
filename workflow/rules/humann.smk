#raise Exception(
#    "HUMAnN currently is only compatible with the MetaPhlAn vJan21 database and not yet the latest vOct22 database"
#)

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


rule join_metaphlan_profiles_for_human:
    input:
        expand(
            "Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt", sample=SAMPLES
        ),
    output:
        max_profile="Intermediate/humann/metaphlan_max_profile.tsv",
    script:
        "../scripts/merge_metaphlan_tables_for_humann.py"


# humann --input $SAMPLE_1.fastq --output $OUTPUT_DIR --taxonomic-profile max_taxonomic_profile.tsv
# The folder $OUTPUT_DIR/$SAMPLE_1_humann_temp/


localrules:
    create_temp_fastq,
    join_metaphlan_profiles_for_human,


rule create_temp_fastq:
    output:
        temp("Intermediate/humann/test.fastq"),
    run:
        import random

        with open(output[0], "w") as f:
            f.write(
                f"@M00001:1:0:0:1\n{''.join(random.choices('ATCG', k=100))}\n+\n{'!' * 100}"
            )


rule create_custom_chocophlan_db:
    input:
        fastq=rules.create_temp_fastq.output[0],
        nucleotide_db=ancient(HUMANN_DB_DIR / "nucleotide"),
        protein_db=ancient(HUMANN_DB_DIR / "protein"),
        max_profile=rules.join_metaphlan_profiles_for_human.output.max_profile,
        #max_profile= "Intermediate/metaphlan/rel_ab/sample1.txt" # HACK: As a test I use here sample 1 !!!
    output:
        custom_db=directory("Intermediate/humann/db/test/test_humann_temp"),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/humann/create_custom_db.log",
    params:
        output_dir=lambda wildcards, output: Path(output[0]).parent,
        humann_params=config["humann_params"],
    shadow:
        "minimal"
    threads: config["threads_simple"]
    resources:
        mem_mb=config["mem_default"] * 1024,
    shell:
        "humann "
        " --output-basename test "
        " -i {input.fastq} "
        " -o {params.output_dir} "
        " --threads {threads} "
        " --taxonomic-profile {input.max_profile} "
        " {params.humann_params} "
        " --nucleotide-database {input.nucleotide_db}/chocophlan "
        " --protein-database {input.protein_db}/uniref "
        " &> {log} "


rule humann:
    input:
        reads=get_qc_reads,
        nucleotide_db=rules.create_custom_chocophlan_db.output.custom_db,
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
        bash="logs/humann/{sample}.log",
        humann="Intermediate/humann/output/{sample}.log",
    params:
        output_dir=lambda wc, output: Path(output[0]).parent,
        concatenator=lambda wc, input: "zcat" if all(Path(file).suffix == '.gz' for file in input.reads) else "cat",
        humann_params=config["humann_params"],
    threads: config["threads_default"]
    resources:
        mem_mb=config["mem_default"] * 1024,
        runtime= config["time_long"] * 60,
        slurm_partition="shared-bigmem" # Partition hard-coded, can be changed with snakemake command line arguments
    shell:
        ' TMP_FILE="{resources.tmpdir}/humann_{wildcards.sample}.fastq" ;\n'
        "{params.concatenator} {input.reads} > $TMP_FILE 2> {log.bash} ;"
        "\n"
        " "
        "humann "
        "-i $TMP_FILE "
        " -o {params.output_dir} "
        " --output-basename {wildcards.sample} "
        " --threads {threads} "
        " {params.humann_params} "
        " --bypass-nucleotide-index --nucleotide-database {input.nucleotide_db}/test_bowtie2_index "
        " --protein-database {input.protein_db}/uniref "
        " &>> {log.bash} "


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
        Search_dir="Intermediate/humann/output",
    threads: 1
    resources:
        mem_mb=config["mem_default"] * 1024,
    shell:
        " humann_join_tables -i {params.Search_dir} -o {output} --file_name {wildcards.type_and_norm} "
