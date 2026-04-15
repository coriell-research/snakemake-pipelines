rule strelka_paired:
    input:
        tumor = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        normal = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.bam"
    output:
        outdir = directory(f"{STRELKA_OUT}/{{sample}}"),
    params:
        ref = config["gatk"]['ref']
    threads:
        12
    shell:
        """
        # configuration
        /usr/local/programs/strelka-2.9.10.centos6_x86_64/bin/bin/configureStrelkaSomaticWorkflow.py \
            --normalBam {input.normal} \
            --tumorBam {input.tumor} \
            --referenceFasta {params.ref} \
            --runDir {output.outdir}

        # execution on a single local machine 
        {output.outdir}/runWorkflow.py --exome -m local -j {threads}
        """