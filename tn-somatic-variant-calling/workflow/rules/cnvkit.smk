rule cnvkit:
    input:
        tumors = expand(f"{MARKDUP_OUT}/{{sample}}_tumor.bam", sample=PAIRED_SAMPLES.keys()),
        normals = expand(f"{MARKDUP_OUT}/{{sample}}_normal.bam", sample=PAIRED_SAMPLES.keys())
    output:
        cnn = f"{CNVKIT_OUT}/reference.cnn"
    params:
        baits = config["cnvkit"]["baits"],
        ref = config["bwa"]["idx"],
        out_dir = CNVKIT_OUT,
        method = "hybrid"
    threads:
        8
    conda:
        "cnvkit"
    shell:
        """
        cnvkit.py batch {input.tumors} \
            --normal {input.normals} \
            --targets {params.baits} \
            --fasta {params.ref} \
            --output-reference {output.cnn} \
            --output-dir {params.out_dir} \
            --processes {threads} \
            --method {params.method} \
            --drop-low-coverage \
            --diagram \
            --scatter
        """
