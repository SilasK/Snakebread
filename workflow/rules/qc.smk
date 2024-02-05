
rule kneaddata:
    input:
        reads=rules.trim_galore_pe.output.reads,
        db=Path(config["kneaddata_db_base"]) / config["host"],
    output:
        reads=pipe(
            expand(
                "QC/QCreads/{{sample}}_kneaddata_{suffix}",
                suffix=[
                    "paired_1.fastq",
                    "paired_2.fastq",
                    "unmatched_1.fastq",
                    "unmatched_2.fastq",
                ],
            )
        ),
    params:
        output_dir=lambda wc, output: Path(output[0]).parent,
    conda:
        "../envs/biobakery.yaml"
    log:
        "logs/qc/kneaddata/{sample}.log",
    threads: 8
    resources:
        mem_mb=32000,
    shell:
        "kneaddata "
        " --input {input.reads[0]} --input {input.reads[1]} "
        " -o {resources.temp_dir}/kneadata_{wildcards.sample}/ "
        " -db {input.db} "
        " --output-prefix {wildcards.sample} "
        " --remove-intermediate-output "
        ' --trimmomatic-options "{config[trimmomatic_options]}" '
        " -t {threads} "
        " --log {log} "


rule kneadata_gzip:
    input:
        reads=rules.kneaddata.output.reads,
    output:
        expand("QC/QCreads/{{sample}}_QC_{fraction}.gz", fraction=["R1", "R2", "se"]),
    threads: 3
    log:
        "logs/qc/kneaddata/gzip_{sample}.log",
    shell:
        "gzip -c {input[0]} > {output[0]} 2>> {log} & ; "
        "gzip -c {input[1]} > {output[1]} 2>> {log} & ; "
        "gzip -c {input[2]} > {output[2]} 2>> {log} & ; "
        "gzip -c {input[3]} >> {output[2]} 2>> {log} & ; "
        "wait"
