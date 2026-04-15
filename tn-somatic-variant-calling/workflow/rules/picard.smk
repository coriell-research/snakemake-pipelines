rule merge_bam:
    input:
        get_replicates_for_merge
    output:
        f"{MERGE_OUT}/{{sample}}.bam"
    params:
        bams = lambda w, input: " ".join([f"-I {f}" for f in input]),
        java_args = config["java"]["java_args"]
    log:
        f"{MERGE_OUT}/{{sample}}.log"
    shell:
        "java {params.java_args} -jar /usr/local/programs/picard.jar MergeSamFiles "
          "{params} "
          "--OUTPUT {output} "
          "--ASSUME_SORTED true "
          "--CREATE_INDEX true "
          "--SORT_ORDER coordinate"


rule mark_duplicates:
    input:
        f"{MERGE_OUT}/{{sample}}.bam"
    output:
        bam = f"{MARKDUP_OUT}/{{sample}}.bam",
        metrics = f"{MARKDUP_OUT}/{{sample}}.metrics.txt"
    params:
        java_args = config["java"]["java_args"]
    log:
        f"{MARKDUP_OUT}/{{sample}}.log",
    shell:
        "java {params.java_args} -jar /usr/local/programs/picard.jar MarkDuplicates "
          "-I {input} "
          "-O {output.bam} "
          "-M {output.metrics} "
          "--ASSUME_SORT_ORDER coordinate "
          "--CREATE_INDEX true "