
rule muse_call_paired:
    input:
        tumor = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        normal = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.bam"
    output:
        txt = f"{MUSE_OUT}/{{sample}}.MuSE.txt"
    log:
        f"{MUSE_OUT}/{{sample}}.call.log"
    params:
        ref = config["bwa"]["idx"],
        out_prefix = f"{MUSE_OUT}/{{sample}}"
    threads: 
        8
    conda:
        "muse"
    shell:
        """
        MuSE call \
            -O {params.out_prefix} \
            -f {params.ref} \
            -n {threads} \
            {input.tumor} {input.normal} \
            2> {log}
        """


rule muse_sump_paired:
    input:
        txt = f"{MUSE_OUT}/{{sample}}.MuSE.txt"
    output:
        vcf = f"{MUSE_OUT}/{{sample}}.vcf"
    log:
        f"{MUSE_OUT}/{{sample}}.sump.log"
    params:
        dbsnp = config["muse"]["dbsnp"],
        mode = "-E"
    threads:
        8
    conda:
        "muse"
    shell:
        """
        MuSE sump \
            -I {input.txt} \
            {params.mode} \
            -n {threads} \
            -O {output.vcf} \
            -D {params.dbsnp} \
            2> {log}
        """


rule muse_pass_norm_paired:
    input:
        vcf = f"{MUSE_OUT}/{{sample}}.vcf"
    output:
        vcf = f"{MUSE_OUT}/{{sample}}.pass.vcf.gz",
        tbi = f"{MUSE_OUT}/{{sample}}.pass.vcf.gz.tbi"
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