rule consensus_calls:
    input:
        varscan_vcf = f"{VARSCAN_OUT}/{{sample}}.pass.vcf.gz",
        muse_vcf = f"{MUSE_OUT}/{{sample}}.pass.vcf.gz",
        mutect_vcf = f"{MUTECT_OUT}/{{sample}}.pass.vcf.gz",
        deepsomatic_vcf = f"{DEEPSOMATIC_OUT}/{{sample}}.pass.vcf.gz"
    output:
        vcf = f"{CONSENSUS_OUT}/{{sample}}/{{sample}}.vcf.gz"
    params:
        prefix_dir = f"{CONSENSUS_OUT}/{{sample}}",
        ref = config["bwa"]["idx"]
    shell:
        """
        # Get the consensus (3/4 callers)
        bcftools isec -p {params.prefix_dir} -n+3 -c none {input.varscan_vcf} {input.muse_vcf} {input.mutect_vcf} {input.deepsomatic_vcf}
        
        # Sometimes AD TAGs are messed up, remove them before merge
        bcftools annotate -x FORMAT/AD -o {params.prefix_dir}/0000.vcf.gz {params.prefix_dir}/0000.vcf
        bcftools annotate -x FORMAT/AD -o {params.prefix_dir}/0001.vcf.gz {params.prefix_dir}/0001.vcf
        bcftools annotate -x FORMAT/AD -o {params.prefix_dir}/0002.vcf.gz {params.prefix_dir}/0002.vcf
        bcftools annotate -x FORMAT/AD -o {params.prefix_dir}/0003.vcf.gz {params.prefix_dir}/0003.vcf

        # Index before merge
        bcftools index {params.prefix_dir}/0000.vcf.gz
        bcftools index {params.prefix_dir}/0001.vcf.gz
        bcftools index {params.prefix_dir}/0002.vcf.gz
        bcftools index {params.prefix_dir}/0003.vcf.gz
        
        # Merge into consensus
        bcftools merge --force-samples -m any {params.prefix_dir}/0000.vcf.gz {params.prefix_dir}/0001.vcf.gz {params.prefix_dir}/0002.vcf.gz {params.prefix_dir}/0003.vcf.gz -o {output.vcf}
        bcftools index -t {output.vcf}
        """