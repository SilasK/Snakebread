# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************

# **** Variables ****


configfile: "config.yaml"


rule install_metaphlan:
    output:
        db_folder= directory(METPHLAN_DB_FOLDER)
    log:
        "logs/download/metaphlan.log",
    params:
        version=config["metaphlan_version"],
    threads: 1,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan "
        " --install "
        " --bowtie2db {output.db_folder} "
        " --index {params.version} "
        " --nproc {threads} "
        " &> {log}"

#marker_pres_table

rule metaphlan:
    input:
        reads=get_qc_reads,
        db_folder=METPHLAN_DB_FOLDER
    output:
        bt="Intermediate/metaphlan/output/{sample}_bowtie2.bz2",
        profile="Intermediate/metaphlan/output/{sample}_profile.txt",
    log:
        "logs/metaphlan/{sample}.log",
    params:
        input= lambda wildcards, input: ','.join(input.reads),
        version=config["metaphlan_version"],
        Type="rel_ab_w_read_stats",
    threads: 8,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan "
        " -t {params.Type} "
        " --unclassified_estimation "
        " {params.input} "
        " --index {params.version} "
        " --offline "
        " --sample_id {wildcards.sample} "
        " --input_type fastq "
        " --bowtie2db {input.db_folder} "
        " --bowtie2out {output.bt} "
        " --nproc {threads} "
        " -o {output.profile} &> {log}"


#   -t ANALYSIS TYPE      Type of analysis to perform:
#                          * rel_ab: profiling a metagenomes in terms of relative abundances
#                          * rel_ab_w_read_stats: profiling a metagenomes in terms of relative abundances and estimate the number of reads coming from each clade.
#                          * reads_map: mapping from reads to clades (only reads hitting a marker)
#                          * clade_profiles: normalized marker counts for clades with at least a non-null marker
#                          * marker_ab_table: normalized marker counts (only when > 0.0 and normalized by metagenome size if --nreads is specified)
#                          * marker_counts: non-normalized marker counts [use with extreme caution]
#                          * marker_pres_table: list of markers present in the sample (threshold at 1.0 if not differently specified with --pres_th
#                          * clade_specific_strain_tracker: list of markers present for a specific clade, specified with --clade, and all its subclades

# sgb_to_gtdb_profile.py is a python script that is available with metaphlan4
rule sgb_to_GTDB:
    input:
        sg="Intermediate/metaphlan/{sample}_profile.txt",
    output:
        gtdb="Intermediate/metaphlan/GTDB/{sample}_profile.txt",
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "sgb_to_gtdb_profile.py  -i {input.sg} -o {output.gtdb}"


rule mergeprofiles:
    input:
        expand("Intermediate/metaphlan/output/{sample}_profile.txt", sample=SAMPLES),
    output:
        o1="Intermediate/metaphlan/merged_abundance_table.txt",
        o2="Intermediate/metaphaln/merged_abundance_table_species.txt",
    params:
        script=snakemake_dir / "utils/merge_metaphlan_tables.py",
    conda:
        "../envs/metaphlan.yaml"
    shell:
        """
           python {params.script} {input} > {output.o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)|(UNCLASSIFIED)" {output.o1} | grep -v "t__"  > {output.o2}
           """


rule mergeprofiles_relab:
    input:
        rules.mergeprofiles.input,
    output:
        o1="Intermediate/metaphlan/merged_abundance_table_relab.txt",
        o2="Intermediate/metaphlan/merged_abundance_table_species_relab.txt",
    params:
        script=snakemake_dir / "utils/merge_metaphlan_tables_relab.py",
    conda:
        "../envs/metaphlan.yaml"
    shell:
        """
           python {params.script} {input} > {output.o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)|(UNCLASSIFIED)" {output.o1} | grep -v "t__"  > {output.o2}
           """


use rule mergeprofiles as mergeprofiles_GTDB with:
    input:
        expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES),
    output:
        o1="Intermediate/merged_abundance_table_GTDB.txt",
        o2="Intermediate/merged_abundance_table_species_GTDB.txt",


use rule mergeprofiles_relab as mergeprofiles_relab_GTDB with:
    input:
        expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES),
    output:
        o1="Intermediate/merged_abundance_table_GTDB_relab.txt",
        o2="Intermediate/merged_abundance_table_species_GTDB_relab.txt",
