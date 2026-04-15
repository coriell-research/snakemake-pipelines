
rule varscan_paired:
    input:
        tumor = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        normal = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.bam"
    output:
        snp_vcf = f"{VARSCAN_OUT}/{{sample}}.snp.vcf",
        indel_vcf = f"{VARSCAN_OUT}/{{sample}}.indel.vcf"
    log:
        f"{VARSCAN_OUT}/{{sample}}.somatic.log"
    params:
        max_depth = 100000,
        min_mapq = 20,
        ref = config["bwa"]["idx"],
        out_prefix = f"{VARSCAN_OUT}/{{sample}}",
        min_cov = 10,
        min_var_freq = 0.05,
        somatic_p = 0.05,
        strand_filter = 1
    shell:
        """
        samtools mpileup \
            -d {params.max_depth} \
            -q {params.min_mapq} \
            --no-BAQ \
            -f {params.ref} \
            {input.normal} {input.tumor} |
        java -jar /usr/local/programs/VarScan.jar somatic \
            - \
            {params.out_prefix} \
            --mpileup 1 \
            --output-vcf 1 \
            --min-coverage {params.min_cov} \
            --min-var-freq {params.min_var_freq} \
            --somatic-p-value {params.somatic_p} \
            --strand-filter {params.strand_filter} \
            --output-snp {output.snp_vcf} \
            --output-indel {output.indel_vcf} \
            2> {log}
        """


rule varscan_filter_paired:
    input:
        snp_vcf = f"{VARSCAN_OUT}/{{sample}}.snp.vcf",
        indel_vcf = f"{VARSCAN_OUT}/{{sample}}.indel.vcf",
    output:
        vcf_filtered = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.vcf"
    log:
        f"{VARSCAN_OUT}/{{sample}}.filter.log"
    params:
        min_cov = 10,
        min_reads = 4,
        min_strands = 1,
        min_var_freq = 0.05,
        p_value = 0.05
    shell:
        """
        java -jar /usr/local/programs/VarScan.jar somaticFilter \
            {input.snp_vcf} \
            --min-coverage {params.min_cov} \
            --min-reads2 {params.min_reads} \
            --min-strands2 {params.min_strands} \
            --min-var-freq {params.min_var_freq} \
            --p-value {params.p_value} \
            --indel-file {input.indel_vcf} \
            --output-file {output.vcf_filtered} \
            2> {log}
        """

# Extracts only SNV positions from VarScan somatic hc calls for use in bam-readcounts
rule get_site_list:
    input:
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.vcf"
    output:
        site_list = f"{VARSCAN_OUT}/{{sample}}.sitelist"
    shell:
        """
        awk 'BEGIN{{FS=OFS="\t"}} !/^#/ {{print $1, $2, $2}}' {input.vcf} > {output.site_list}
        """

# Used for VarScan fpfilter
rule bam_readcounts:
    input:
        tumor_bam = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.vcf",
        site_list = f"{VARSCAN_OUT}/{{sample}}.sitelist"
    output:
        readcounts = f"{VARSCAN_OUT}/{{sample}}.readcounts"
    log:
        f"{VARSCAN_OUT}/{{sample}}.readcounts.log"
    params:
        ref = config["bwa"]["idx"],
        max_depth = 100000,
        min_mapq = 20
    conda:
        "bam-readcount"
    shell:
        """
        bam-readcount \
          --min-mapping-quality {params.min_mapq} \
          --max-count {params.max_depth} \
          --reference-fasta {params.ref} \
          --site-list {input.site_list} \
          {input.tumor_bam} > {output.readcounts}
        """


rule varscan_fpfilter_paired:
    input:
        readcounts = f"{VARSCAN_OUT}/{{sample}}.readcounts",
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.vcf"
    output:
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.vcf"
    log:
        f"{VARSCAN_OUT}/{{sample}}.fpfilter.log"
    params:
        min_var_count = 3,
        min_var_freq  = 0.05,
        min_read_pos  = 0.10,
        min_strandedness = 0
    shell:
        """
        java -jar /usr/local/programs/VarScan.jar fpfilter \
            {input.vcf} \
            {input.readcounts} \
            --output-file {output.vcf} \
            --min-var-count {params.min_var_count} \
            --min-var-freq {params.min_var_freq} \
            --min-read-pos {params.min_read_pos} \
            --min-strandedness {params.min_strandedness} \
            2> {log}
        """

# Needed because VarScan does not add contigs to header
rule varscan_rehead_vcf:
    input:
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.vcf"
    output:
        vcf_gz = temp(f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.vcf.gz"),
        vcf_tbi = temp(f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.vcf.gz.tbi"),
        rehead = temp(f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.rehead.vcf.gz"),
        rehead_tbi = temp(f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.rehead.vcf.gz.tbi")
    params:
        fai = config["bwa"]["fai"]
    shell:
        """
        bcftools view -Oz -o {output.vcf_gz} {input.vcf} && bcftools index -t {output.vcf_gz} 
        bcftools reheader -f {params.fai} -o {output.rehead} {output.vcf_gz} && \
        bcftools index -t {output.rehead}
        """


rule varscan_pass_norm_paired:
    input:
        vcf = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.rehead.vcf.gz",
        vcf_tbi = f"{VARSCAN_OUT}/{{sample}}.snp.Somatic.hc.fpfilter.rehead.vcf.gz.tbi",
    output:
        vcf = f"{VARSCAN_OUT}/{{sample}}.pass.vcf.gz",
        tbi = f"{VARSCAN_OUT}/{{sample}}.pass.vcf.gz.tbi"
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
