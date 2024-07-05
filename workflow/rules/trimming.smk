



rule quality_trimming:
    input:
        sample=get_raw_reads,
    output:
        trimmed=temp(
            expand(
                "Intermediate/qc/reads/trimmed/{{sample}}_{fraction}.fastq.gz",
                fraction=FRACTIONS,
            )
        ),
        html="Intermediate/reports/quality_trimming/{sample}.html",
        json="Intermediate/reports/quality_trimming/{sample}.json",
    log:
        "logs/qc/quality_trimming/{sample}.log",
    params:
        extra=f"--qualified_quality_phred {config['trim_base_phred']} "
        " --dedup "
        " --dup_calc_accuracy 5 "
        f" --length_required {config['trim_min_length']} "
        " --low_complexity_filter"
        " --detect_adapter_for_pe "
        " --correction "
        " --overrepresentation_analysis "
        " --cut_tail "
        " --cut_front "
        '--report_title "Quality trimming" '
        f" --cut_mean_quality {config['trim_mean_quality']} "
        f" {config['quality_trim_extra']} ",
    threads: config["threads_default"]
    benchmark:
        "logs/benchmark/quality_trimming/{sample}.tsv"
    resources:
        mem_mb=config["mem_default"] * 1024,
    wrapper:
        "v3.3.3/bio/fastp"


rule multiqc_fastp:
    input:
        expand(rules.quality_trimming.output.json, sample=SAMPLES),
    output:
        "Reports/quality_trimming/multiqc.html",
        directory("Reports/quality_trimming/multiqc_data"),
    params:
        extra="--data-dir --fn_as_s_name ",
    log:
        "logs/multiqc/quality_trimming.log",
    threads: 1
    resources:
        mem_mb=config["mem_default"] * 1024,
    wrapper:
        "v3.3.3/bio/multiqc"
