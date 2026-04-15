rule mosdepth:
    input:
        bam = f"{MARKDUP_OUT}/{{sample}}.bam",
        bai = f"{MARKDUP_OUT}/{{sample}}.bai"
    output:
        dist = f"{MOSDEPTH_OUT}/{{sample}}.mosdepth.global.dist.txt",
        summary = f"{MOSDEPTH_OUT}/{{sample}}.mosdepth.summary.txt",
        per_base = f"{MOSDEPTH_OUT}/{{sample}}.per-base.bed.gz",
        regions = f"{MOSDEPTH_OUT}/{{sample}}.regions.bed.gz"
    params:
        prefix = f"{MOSDEPTH_OUT}/{{sample}}",
        by = config["mosdepth"]["by"],
        include_flag = config["mosdepth"]["include_flag"], 
        extra_params = config["mosdepth"]["extra_params"],
        thresholds = config["mosdepth"]["thresholds"]
    log:
        f"{MOSDEPTH_OUT}/{{sample}}.mosdepth.log"
    threads:
        4
    shell:
        """
        mosdepth \
          --threads {threads} \
          --by {params.by} \
          --include-flag {params.include_flag} \
          --thresholds {params.thresholds} \
          {params.extra_params} \
          {params.prefix} \
          {input.bam} &> {log}
        """
