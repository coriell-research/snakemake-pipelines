rule bwa:
    input:
        r1 = f"{FASTP_OUT}/{{pu}}.trimmed.1.fq.gz",
        r2 = f"{FASTP_OUT}/{{pu}}.trimmed.2.fq.gz",
    output:
        bam = f"{BWA_OUT}/{{pu}}.sorted.bam",
        bai = f"{BWA_OUT}/{{pu}}.sorted.bam.bai"
    params:
         pid = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "ID"].item(),
         sm = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "SM"].item(),
         pl = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "PL"].item(),
         lb = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "LB"].item(),
         pu = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "PU"].item(),
         idx = config["bwa"]["idx"],
         gb = 4
    threads:
        8
    log:
        f"{BWA_OUT}/{{pu}}.log"
    shell:
        """
        bwa mem -t {threads} -R '@RG\\tID:{params.pid}\\tSM:{params.sm}\\tPL:{params.pl}\\tLB:{params.lb}\\tPU:{params.pu}' {params.idx} {input.r1} {input.r2} | \
        samtools sort -@{threads} -m{params.gb}g -o {output.bam} - && samtools index {output.bam}
        """