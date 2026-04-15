rule annotate_consensus:
    input:
        cons_vcf = f"{CONSENSUS_OUT}/{{sample}}/{{sample}}.vcf.gz"
    output:
        maf = f"{ANNOTATED_OUT}/{{sample}}.maf"
    log:
        f"{ANNOTATED_OUT}/{{sample}}.log"
    params:
        data_source = config["gatk"]["data_source"],
        ref = config["bwa"]["idx"]
    shell:
        """
        gatk Funcotator \
            --data-sources-path {params.data_source} \
            --output {output.maf} \
            --output-file-format MAF \
            --ref-version hg38 \
            --reference {params.ref} \
            --variant {input.cons_vcf} &> {log}
        """