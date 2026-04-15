rule deepsomatic_paired:
    input:
        tumor = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['tumor']}.bam",
        normal = lambda w: f"{MARKDUP_OUT}/{PAIRED_SAMPLES[str(w.sample)]['normal']}.bam"
    output:
        vcf = f"{DEEPSOMATIC_OUT}/{{sample}}/{{sample}}.vcf.gz"
    params:
        bin_version = "1.10.0",
        sample_tumor = "{sample}_TUMOR",   
        sample_normal = "{sample}_NORMAL",
        ref_dir = "/mnt/data/gdata/gatk/hg38/v0"
        ref = config["gatk"]["ref"]
    threads: 48
    container: "docker://google/deepsomatic:1.10.0"
    shell:
        """
        # Get the absolute path of the current Snakemake working directory
        WORKDIR=$(pwd)
        
        # Snakemake creates the parent output dir, but DeepSomatic needs the specific sub-folders
        OUTDIR=$(dirname {output.vcf})
        mkdir -p $OUTDIR/intermediate_results_dir
        mkdir -p $OUTDIR/logs

        # Run docker using Snakemake inputs/outputs
        docker run --rm \
            -v $WORKDIR:$WORKDIR \
            -v {params.ref_dir}:{params.ref_dir} \
            -w $WORKDIR \
            google/deepsomatic:{params.bin_version} \
            run_deepsomatic \
            --model_type=WES \
            --ref={params.ref} \
            --reads_normal={input.normal_bam} \
            --reads_tumor={input.tumor_bam} \
            --output_vcf={output.vcf} \
            --sample_name_tumor={params.sample_tumor} \
            --sample_name_normal={params.sample_normal} \
            --num_shards={threads} \
            --logging_dir=$OUTDIR/logs \
            --intermediate_results_dir=$OUTDIR/intermediate_results_dir
        """


rule deepsomatic_pass_norm_paired:
    input:
        vcf = f"{DEEPSOMATIC_OUT}/{{sample}}.vcf.gz"
    output:
        vcf = f"{DEEPSOMATIC_OUT}/{{sample}}.pass.vcf.gz",
        tbi = f"{DEEPSOMATIC_OUT}/{{sample}}.pass.vcf.gz.tbi"
    params:
        ref = config["bwa"]["idx"],
        buff = 10000,
        multi_allele = "-",
        check_ref = "s"
    shell:
        """
        bcftools view --types 'snps' -f 'PASS' {input.vcf} | \
        bcftools norm --force -c {params.check_ref} -m {params.multi_allele} -w {params.buff} -f {params.ref} | \
        bcftools view -Oz -o {output.vcf} && bcftools index -t {output.vcf}
        """
