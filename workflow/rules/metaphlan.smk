

# ************************************
# * Snakefile for metaphlan pipeline *
# ************************************

# **** Variables ****

configfile: "config.yaml"


rule download_metaphlan:
output:
    multiext( METPHLAN_DB_FOLDER / "{metaphlan_version}" ,".tar" , ".md5","_marker_info.txt.bz2")
run:

    import requests


    # Define the base URL
    base_url = "http://cmprod1.cibio.unitn.it/biobakery4/metaphlan_databases/"

    # Define the files to download
    files_to_download = [Path(path).name for path in input] +["mpa_latest"]

    # Download each file
    for file in files_to_download:
        response = requests.get(base_url + file)

        # Save the file
        with open(os.path.join(METPHLAN_DB_FOLDER, file), 'wb') as f:
            f.write(response.content)

rule metaphlan:
    input:
        reads = get_concatenated_reads,
        db= METPHLAN_DB_FOLDER / "{config[metaphlan_version]}.tar",
    output:
        bt = "Intermediate/metaphlan/output/{sample}_bowtie2.bz2",
        profile = "Intermediate/metaphlan/output/{sample}_profile.txt"
    log:
        "logs/metaphlan/{sample}.log"
    params: 
        db_folder = METPHLAN_DB_FOLDER,
        version = config["metaphlan_version"],
        type="rel_ab_w_read_stats"
	threads:  config["threads"]	
    conda: "../envs/metaphlan.yaml"
    shell:
            "metaphlan "
            " -t {params.type} "
            " --unclassified_estimation "
            " {input.reads} "
            " --index {params.version} "
            " --sample_id {wildcards.sample} "
            " --input_type fastq "
            " --bowtie2db {params.db_folder} "
            " --bowtie2out {output.bt} "
            " --nproc {threads} "
            " -o {output.profile} &> {log}"


# sgb_to_gtdb_profile.py is a python script that is available with metaphlan4
rule sgb_to_GTDB:
    input:
         sg="Intermediate/metaphlan/{sample}_profile.txt"
    output:
         gtdb="Intermediate/metaphlan/GTDB/{sample}_profile.txt"
    conda: "utils/envs/metaphlan4.yaml"
    shell:
            "sgb_to_gtdb_profile.py  -i {input.sg} -o {output.gtdb}"




rule mergeprofiles:
    input: expand("Intermediate/metaphlan/{sample}_profile.txt", sample=SAMPLES)
    output: o1="Intermediate/metaphlan/merged_abundance_table.txt",
            o2="Intermediate/metaphaln/merged_abundance_table_species.txt"
    params:
        script = snakemake_dir/"utils/merge_metaphlan_tables.py"
    conda: "../envs/metaphlan.yaml"
    shell: """
           python {params.script} {input} > {output.o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)|(UNCLASSIFIED)" {output.o1} | grep -v "t__"  > {output.o2}
           """
rule mergeprofiles_relab:
    input: rules.mergeprofiles.input
    output: o1="Intermediate/metaphlan/merged_abundance_table_relab.txt",
            o2="Intermediate/metaphlan/merged_abundance_table_species_relab.txt"
    params:
        script = snakemake_dir/"utils/merge_metaphlan_tables_relab.py"
    conda: "../envs/metaphlan.yaml"
    shell: """
           python {params.script} {input} > {output.o1}
           grep -E "(s__)|(^ID)|(clade_name)|(UNKNOWN)|(UNCLASSIFIED)" {output.o1} | grep -v "t__"  > {output.o2}
           """


use rule mergeprofiles as mergeprofiles_GTDB with:
    input: expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES)
    output: o1="Intermediate/merged_abundance_table_GTDB.txt",
            o2="Intermediate/merged_abundance_table_species_GTDB.txt"

use rule mergeprofiles_relab as mergeprofiles_relab_GTDB with:
    input: expand("Intermediate/metaphlan/GTDB/{sample}_profile.txt", sample=SAMPLES)
    output: o1="Intermediate/merged_abundance_table_GTDB_relab.txt",
            o2="Intermediate/merged_abundance_table_species_GTDB_relab.txt"