

localrules: download_chocophlan,download_uniref
rule download_chocophlan:
    output:
        directory( Path(config["database_dir"]) / "chocophlan" ),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/download/download_chocophlan.log"
    shell:
        "humann_databases --update-config yes "
        " --download chocophlan full {config[database_dir]} &> {log}"


rule download_uniref:
    output:
        directory( Path(config["database_dir"]) / "uniref" ),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/download/download_uniref.log"
    shell:
        "humann_databases --update-config yes "
        " --download uniref uniref90_diamond {config[database_dir]} &> {log}"

#        " --download utility_mapping full {config[database_dir]} "





rule join_metaphlan_profiles_for_human:
    input:
        expand("Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt", sample=SAMPLES),
    output:
        max_profile= "Profile/metaphlan_max_profile.tsv",
    script:
        "../scripts/merge_metaphlan_tables_for_humann.py"


# humann --input $SAMPLE_1.fastq --output $OUTPUT_DIR --taxonomic-profile max_taxonomic_profile.tsv
# The folder $OUTPUT_DIR/$SAMPLE_1_humann_temp/ 


localrules:create_temp_fastq, join_metaphlan_profiles_for_human
rule create_temp_fastq:
    output:
        temp("Intermediate/Humann/test.fastq")
    run:
        import random
        with open(output[0],"w") as f:
            f.write(f"@M00001:1:0:0:1\n{''.join(random.choices('ATCG', k=100))}\n+\n{'!' * 100}")



rule create_custom_chocophlan_db:
    input:
        fastq= rules.create_temp_fastq.output[0],
        nucleotide_db=ancient(Path(config["database_dir"]) / "chocophlan"),
        protein_db= ancient(Path(config["database_dir"]) / "uniref"),
        max_profile = rules.join_metaphlan_profiles_for_human.output.max_profile
    output:
        custom_db= "Intermediate/Humann/db/test/test_humann_temp"
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/humann/create_custom_db.log"
    params:
        output_dir=lambda wildcards, output: Path(output[0]).parent,
        humann_params=config["humann_params"],
    shadow:
        "minimal"
    threads: 6
    resources:
        mem_mb=64000,
    shell:
        "humann "
        " --output-basename test "
        " -i {input.fastq} "
        " -o {params.output_dir} "
        " --threads {threads} "
        " --taxonomic-profile {input.max_profile} "
        " {params.humann_params} "
        " --nucleotide-database {input.nucleotide_db} "
        " --protein-database {input.protein_db} "
        " &> {log} "




rule humann:
    input:
        reads= get_qc_reads,
        nucleotide_db= rules.create_custom_chocophlan_db.output.custom_db,
        protein_db= ancient(Path(config["database_dir"]) / "uniref"),
    output:
        multiext("Intermediate/Humann/output/{sample}_","genefamilies.tsv","pathcoverage.tsv","pathabundance.tsv")
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/humann/{sample}.log", "Intermediate/Humann/output/{sample}.log"
    params:
        output_dir=lambda wc, output: Path(output[0]).parent,
        humann_params=config["humann_params"],
    threads: 16
    resources:
        mem_mb=64000,
    shell:
        "cat {input} > {resources.temp_dir}/humann_{wildcards.sample}.fastq.gz "
        " ; "
        "humann "
        "-i {resources.temp_dir}/humann_{wildcards.sample}.fastq.gz "
        " -o {params.output_dir} "
        " --output-basename {wildcards.sample} "
        " --threads {threads} "
        " {params.humann_params} "
        " --bypass-nucleotide-index --nucleotide-database {input.nucleotide_db} "
        " --protein-database {input.protein_db} "
        " &> {log} "





rule humann_renorm_table:
    input:
        "Intermediate/Humann/output/{sample}_{type}.tsv"
    output:
        "Intermediate/Humann/output/{sample}_{type}_cpm.tsv"
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/renorm/{type}/{sample}.log",
    params:
        unit ="cpm"
    threads: 1
    resources:
        mem_mb=1000,
    shell:
        "humann_renorm_table --input {input} --output {output} --units {params.unit} &>  {log} "




rule merge_tsv:
    input:
        expand("Intermediate/Humann/output/{sample}_{{type_and_norm}}.tsv", sample=SAMPLES)
    output:
        "Output/humann_{type_and_norm}.tsv"
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/merge_tsv/{type_and_norm}.log",
    params:
        Search_dir="Humann"
    threads:
        1
    resources:
        mem_mb=1000,
    shell:
        " humann_join_tables -i {params.Search_dir} -o {output} --file_name {wildcards.type_and_norm} "

