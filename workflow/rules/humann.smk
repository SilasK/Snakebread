
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





include: "rules/qc.smk"





rule humann:
    input:
        reads= get_concatenated_reads,
        nucleotide_db=Path(config["database_dir"]) / "chocophlan",
        protein_db=Path(config["database_dir"]) / "uniref",
    output:
        # output_dir = directory("Humann/{sample}"),
        # "Humann/{sample}/humann2_genefamilies.tsv",
        # "Humann/{sample}/humann2_pathabundance.tsv",
        sam="Humann/{sample}/{sample}.sam.bz2",
        bowtie2out="Humann/{sample}/{sample}.bowtie2.out",
        biom= temp("Humann/{sample}/{sample}.biom"),
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/humann/{sample}.log",
    params:
        output_dir="Humann/{sample}" #lambda wc, output: Path(output[0]).parent,
        humann_params=config["humann_params"],
        tax_lev="s",
    threads: 16
    resources:
        mem_mb=64000,
    shell:
        "cat {input} > {resources.temp_dir}/humann_{wildcards.sample}.fastq.gz "
        " ; "
        "humann "
        "-i {resources.temp_dir}/humann_{wildcards.sample}.fastq.gz "
        " -o {params.output_dir} "
        " --threads {threads} "
        " {params.humann_params} "
        " --nucleotide-database {input.nucleotide_db} "
        " --protein-database {input.protein_db} "





rule humann_renorm_table:
    input:
        rules.merge_tsv.output,
    output:
        "Output/humann3_{type}_cpm.tsv"
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/renorm/{type}.log",
    params:
        unit ="cpm"
    threads: 1
    resources:
        mem_mb=1000,
    shell:
        "humann_renorm_table --input {input} --output {output} --units {params.unit} &>  {log} "




rule merge_tsv:
    input:
        expand("Humann/{sample}/humann3_{type}.tsv", sample=SAMPLES)
    output:
        "Output/humann3_{type}.tsv"
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/post_process/merge_tsv/{type}.log",
    params:
        Search_dir="Humann"
    threads:
        1
    resources:
        mem_mb=1000,
    shell:
        " humann_join_tables -i {params.Search_dir} --search-subdirectories -o {output} --file_name {wildcards.type} "

