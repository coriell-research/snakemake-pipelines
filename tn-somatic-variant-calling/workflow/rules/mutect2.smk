
rule mutect2_paired:
    input:
        tumor = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        normal = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.bam"
    output:
        vcf = f"{MUTECT_OUT}/{{sample}}.vcf.gz",
        f1r2 = f"{MUTECT_OUT}/{{sample}}.f1r2.tar.gz"
    params:
        normal_name = lambda w: PAIRED_SAMPLES[str(w.sample)]['normal'],
        ref = config["gatk"]["ref"],
        glr = config["gatk"]["glr"],
        pon = config["gatk"]["pon"],
        sec = config["mutect"]["progress_seconds"],
        java_args = config["java"]["java_args"],
        tmp_dir = MUTECT_OUT
    log:
        f"{MUTECT_OUT}/{{sample}}.log"
    threads:
        4
    shell:
        "gatk --java-options {params.java_args} Mutect2 "
          "-I {input.tumor} "
          "-I {input.normal} "
          "-O {output.vcf} "
          "-R {params.ref} "
          "--tmp-dir {params.tmp_dir} "
          "--normal {params.normal_name} "
          "--germline-resource {params.glr} "
          "--panel-of-normals {params.pon} "
          "--f1r2-tar-gz {output.f1r2} "
          "--seconds-between-progress-updates {params.sec} "
          "--native-pair-hmm-threads {threads} "
          "--create-output-variant-index true  &> {log}"


rule pileup_summary:
    input:
        f"{MARKDUP_OUT}/{{sample}}.bam"
    output:
        f"{PILEUP_SUMMARY_OUT}/{{sample}}.table"
    params:
        common_snps = config["gatk"]["snps"],
        ref = config["gatk"]["ref"],
        sec = 120,
        java_args = config["java"]["java_args"],
        tmp_dir = PILEUP_SUMMARY_OUT
    log:
        f"{PILEUP_SUMMARY_OUT}/{{sample}}.pileupsummary.log"
    shell:
        "gatk --java-options {params.java_args} GetPileupSummaries "
          "-I {input} "
          "-O {output} "
          "-R {params.ref} "
          "-V {params.common_snps} "
          "-L {params.common_snps} "
          "--tmp-dir {params.tmp_dir} "
          "--seconds-between-progress-updates {params.sec} &> {log}"


rule contamination_paired:
    input:
        tumor = lambda w: f"{PILEUP_SUMMARY_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.table",
        normal = lambda w: f"{PILEUP_SUMMARY_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.table"
    output:
        f"{CONTAM_PAIRED_OUT}/{{sample}}.table"
    params:
        java_args = config["java"]["java_args"],
        tmp_dir = CONTAM_PAIRED_OUT
    log:
        f"{CONTAM_PAIRED_OUT}/{{sample}}.log"
    shell:
        """
        gatk --java-options {params.java_args} CalculateContamination \
          --input {input.tumor} \
          --matched-normal {input.normal} \
          --output {output} \
          --tmp-dir {params.tmp_dir} &> {log}
        """


rule filter_mutect_paired:
    input:
        vcf = f"{MUTECT_OUT}/{{sample}}.vcf.gz",
        bias = f"{MUTECT_OUT}/{{sample}}.f1r2.tar.gz",
        contam = f"{CONTAM_PAIRED_OUT}/{{sample}}.table"
    output:
        vcf = f"{MUTECT_OUT}/{{sample}}.filtered.vcf"
    params:
        ref = config["gatk"]['ref'],
        strategy = config["mutect"]['strategy'],
        fdr = config["mutect"]['fdr'],
        alt_reads = config["mutect"]['alt_reads'],
        read_pos = config["mutect"]['read_pos'],
        base_qual = config["mutect"]['base_qual'],
        min_allele = config["mutect"]['min_allele'],
        tmp_dir = MUTECT_OUT,
        java_args = config["java"]["java_args"]
    log:
        f"{MUTECT_OUT}/{{sample}}.log"
    shell:
        "gatk --java-options {params.java_args} FilterMutectCalls "
          "-R {params.ref} "
          "-V {input.vcf} "
          "-O {output.vcf} "
          "--threshold-strategy {params.strategy} " 
          "--false-discovery-rate {params.fdr} "
          "--unique-alt-read-count {params.alt_reads} " 
          "--min-median-read-position {params.read_pos} " 
          "--min-median-base-quality {params.base_qual} "
          "--min-allele-fraction {params.min_allele} "
          "--contamination-table {input.contam} "
          "--tmp-dir {params.tmp_dir} &> {log}"


rule mutect_pass_norm_paired:
    input:
        vcf = f"{MUTECT_OUT}/{{sample}}.filtered.vcf"
    output:
        vcf = f"{MUTECT_OUT}/{{sample}}.pass.vcf.gz",
        tbi = f"{MUTECT_OUT}/{{sample}}.pass.vcf.gz.tbi"
    params:
        ref = config["bwa"]["idx"],
        buff = 10000,
        multi_allele = "-",
        check_ref = "s"
    shell:
        """
        bcftools view --types 'snps' -f 'PASS' {input.vcf} | \
        bcftools norm -c {params.check_ref} -m {params.multi_allele} -w {params.buff} -f {params.ref} | \
        bcftools view -Oz -o {output.vcf} && \
        bcftools index -t {output.vcf}
        """
