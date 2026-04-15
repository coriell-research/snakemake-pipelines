rule fastp:
    input:
        r1 = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "read1"].item(),
        r2 = lambda w: SAMPLES.loc[SAMPLES["PU"] == w.pu, "read2"].item()
    output:
        r1_out = temp(f"{FASTP_OUT}/{{pu}}.trimmed.1.fq.gz"),
        r2_out = temp(f"{FASTP_OUT}/{{pu}}.trimmed.2.fq.gz"),
        html = f"{FASTP_OUT}/{{pu}}.fastp.html",
        json = f"{FASTP_OUT}/{{pu}}.fastp.json"
    log:
        f"{FASTP_OUT}/{{pu}}_fastp.log"
    params:
        extra = config["fastp"]["extra_params"]
    shell:
        "fastp -i {input.r1} -I {input.r2} -o {output.r1_out} -O {output.r2_out} "
        "{params.extra} --html {output.html} --json {output.json} &> {log}"