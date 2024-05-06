# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************

# **** Variables ****


configfile: "config.yaml"


rule download_metaphlan:
    output:
        multiext(str(METPHLAN_DB_FOLDER/"{metaphlan_version}"),
            ".tar",
            ".md5",
            "_marker_info.txt.bz2",
        ),
    threads: 1,
    resources:
        mem_mb= 10*1024
    run:
        import requests


        # Define the base URL
        base_url = "http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/"
        # Define the files to download
        files_to_download = [Path(path).name for path in output] + ["mpa_latest"]
        print("Download files: ",", ".join(files_to_download))
        output_folder= Path(output[0]).parent

        # Download each file
        for file in files_to_download:
            print(f"Downloading file: {file}")
            response = requests.get(base_url + file)

            # Save the file
            with open(output_folder/ file, "wb") as f:
                f.write(response.content)
                print(f"File {file} downloaded and saved to {output_folder/ file}")


rule install_metaphlan:
    output:
        touch(METPHLAN_DB_FOLDER/"{version}_installed"),
    log:
        "logs/metaphlan/install_{version}.log",
    params:
        db_folder=METPHLAN_DB_FOLDER,
    shadow:
        "minimal"
    threads: 1,
    resources:
        mem_mb= 50*1024
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
        db=METPHLAN_DB_FOLDER / (config["metaphlan_version"]+"_installed"),
    output:
        bt="Intermediate/metaphlan/output/{sample}_bowtie2.bz2",
        profile="Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt",
        viral = "Intermediate/metaphlan_virus/rel_ab_w_read_stats/{sample}.txt",
    log:
        "logs/metaphlan/main/{sample}.log",
    params:
        input= lambda wildcards, input: ','.join(input.reads),
        version=config["metaphlan_version"],
        db_folder=METPHLAN_DB_FOLDER,
    shadow:
        "minimal"
    threads: 8,
    resources:
        mem_mb= 50*1024
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

ruleorder: rerun_metaphlan > metaphlan

rule rerun_metaphlan:
    input:
        bt="Intermediate/metaphlan/output/{sample}_bowtie2.bz2",
    output:
        profile="Intermediate/metaphlan/{type}/{sample}.txt",
    log:
        "logs/metaphlan/{type}/{sample}.log",
    shadow:
        "minimal"
    threads: 2,
    resources:
        mem_mb= 10*1024
    params:
        version=config["metaphlan_version"],
        db_folder=METPHLAN_DB_FOLDER,
    conda:
        "../envs/metaphlan.yaml"
    shell:
        "metaphlan "
        " -t {wildcards.type} "
        " --unclassified_estimation "
        " {input} "
        " --index {params.version} "
        " --bowtie2db {params.db_folder} "
        " --sample_id {wildcards.sample} "
        " --input_type bowtie2out "
        " --nproc {threads} "
        " --offline "
        " -o {output.profile} &> {log}"


#         " --offline "

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


rule merge_profiles:
    input:
        expand("Intermediate/metaphlan/rel_ab_w_read_stats/{sample}.txt", sample=SAMPLES),
    output:
        abundance= "Profile/metaphlan_relab.tsv",
        taxonomy= "Profile/metaphlan_taxonomy.tsv",
        profiling_stats = "Profile/metaphlan_stats.tsv",
    script:
        "../scripts/merge_metaphlan_tables.py"





# rule sgb_to_GTDB:
#     input:
#         sg="Intermediate/metaphlan/{sample}_profile.txt",
#     output:
#         gtdb="Intermediate/metaphlan/GTDB/{sample}_profile.txt",
#     conda:
#         "../envs/metaphlan.yaml"
#     shell:
#         "sgb_to_gtdb_profile.py  -i {input.sg} -o {output.gtdb}"



# rule mergeprofiles_relab:
#     input:
#         rules.mergeprofiles.input,
#     output:
#         o1="Intermediate/metaphlan/merged_abundance_table_relab.txt",
#         o2="Intermediate/metaphlan/merged_abundance_table_species_relab.txt",
#     params:
#         script=snakemake_dir / "utils/merge_metaphlan_tables_relab.py",
#     conda:
#         "../envs/metaphlan.yaml"
#     shell:
#         """
#            python {params.script} {input} > {output.o1}
#            grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)|(UNCLASSIFIED)" {output.o1} | grep -v "t__"  > {output.o2}
#            """


# use rule mergeprofiles as mergeprofiles_GTDB with:
#     input:
#         expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES),
#     output:
#         o1="Intermediate/merged_abundance_table_GTDB.txt",
#         o2="Intermediate/merged_abundance_table_species_GTDB.txt",


# use rule mergeprofiles_relab as mergeprofiles_relab_GTDB with:
#     input:
#         expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES),
#     output:
#         o1="Intermediate/merged_abundance_table_GTDB_relab.txt",
#         o2="Intermediate/merged_abundance_table_species_GTDB_relab.txt",
