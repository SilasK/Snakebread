# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************


METPHLAN_DB_FOLDER = DB_DIR / "metaphlan_databases"


rule install_metaphlan:
    output:
        touch(METPHLAN_DB_FOLDER / "{version}_installed"),
    log:
        "logs/metaphlan/install_{version}.log",
    params:
        db_folder=METPHLAN_DB_FOLDER,
    shadow:
        "minimal"
    threads: 1
    resources:
        mem_mb=config["mem_simple"] * 1024,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan --install "
        " --bowtie2db {params.db_folder} "
        " --index {wildcards.version} "
        " --nproc {threads} "
        " &> {log}"


rule metaphlan:
    input:
        reads=get_qc_reads,
        db=METPHLAN_DB_FOLDER / (config["metaphlan_version"] + "_installed"),
    output:
        bt="Intermediate/metaphlan/mapresults/{sample}_bowtie2.bz2",
        profile="Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt",
        viral="Intermediate/metaphlan_virus/rel_ab_w_read_stats/{sample}.txt",
    log:
        "logs/metaphlan/main/{sample}.log",
    params:
        input=lambda wildcards, input: ",".join(input.reads),
        version=config["metaphlan_version"],
        db_folder=METPHLAN_DB_FOLDER,
    shadow:
        "minimal"
    threads: config["threads_default"]
    resources:
        mem_mb=config["mem_default"] * 1024,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan "
        " -t rel_ab_w_read_stats "
        " --unclassified_estimation "
        " --profile_vsc "
        " --vsc_out {output.viral} "
        " {params.input} "
        " --index {params.version} "
        " --sample_id {wildcards.sample} "
        " --input_type fastq "
        " --bowtie2db {params.db_folder} "
        " --bowtie2out {output.bt} "
        " --nproc {threads} "
        " --offline "
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


ruleorder: rerun_metaphlan > metaphlan

rule rerun_metaphlan:
    input:
        bt="Intermediate/metaphlan/mapresults/{sample}_bowtie2.bz2",
    output:
        # viral output needs fastq input
        profile="Intermediate/metaphlan/{analysis_type}/{sample}.txt",
    wildcard_constraints:
        # constrain analysis_type to the allowed values, exclude 'rel_ab_w_read_stats' as this is already produced by the main run.
        analysis_type="(rel_ab|reads_map|clade_profiles|marker_ab_table|marker_counts|marker_pres_table|clade_specific_strain_tracker)",
    log:
        "logs/metaphlan/{analysis_type}/{sample}.log",
    shadow:
        "minimal"
    threads: config["threads_default"]
    resources:
        mem_mb=config["mem_default"] * 1024,
    params:
        version=config["metaphlan_version"],
        db_folder=METPHLAN_DB_FOLDER,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan "
        " -t {wildcards.analysis_type} "
        " --unclassified_estimation "
        " {input} "
        " --index {params.version} "
        " --bowtie2db {params.db_folder} "
        " --sample_id {wildcards.sample} "
        " --input_type bowtie2out "
        " --nproc {threads} "
        " --offline "
        " -o {output.profile} &> {log}"


# sgb_to_gtdb_profile.py is a python script that is available with metaphlan4


# my script of merging profiles needs the rel_ab_w_read_stats type
rule merge_profiles:
    input:
        expand(
            "Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt", sample=SAMPLES
        ),
    output:
        abundance="Profile/metaphlan_relab.tsv",
        taxonomy="Profile/metaphlan_taxonomy.tsv",
        profiling_stats="Profile/metaphlan_stats.tsv",
    script:
        "../scripts/merge_metaphlan_tables.py"


rule merge_viral_profiles:
    input:
        expand(
            "Intermediate/metaphlan_viral/rel_ab_w_read_stats/{sample}.txt",
            sample=SAMPLES,
        ),
    output:
        abundance="Profile/viral_abundance.tsv",
        taxonomy="Profile/viral_taxonomy.tsv",
        profiling_stats=temp("Profile/viral_stats.tsv"),
    script:
        "../scripts/merge_metaphlan_tables.py"
