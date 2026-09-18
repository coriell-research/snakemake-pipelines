## Overview

Somatic variant calling pipeline that can incorporate tumor-normal paired data and accomodate 
whole-exome-sequencing data as well as whole-genome-sequencing data.

### Input

The input "samples.csv" file has the following required columns:

**patient** : Custom patient ID; designates the patient/subject; must be unique for each patient, but one patient can have multiple samples (e.g. normal and tumor).
**status** : Normal/tumor status of sample; can be one of 'normal' or 'tumor' 
**sample** : Custom sample ID for each tumor and normal sample; more than one tumor sample for each subject is possible, i.e. a tumor and a relapse; samples can have multiple lanes for which the same ID must be used to merge them later (see also lane). Sample IDs must be unique for unique biological samples
**lane** : Lane ID, used when the sample is multiplexed on several lanes. Must be unique for each lane in the same sample (but does not need to be the original lane name), and must contain at least one character.
**read1** : Full path to FastQ file for Illumina short reads 1. File has to be gzipped and have the extension .fastq.gz or .fq.gz.
**read2** : Full path to FastQ file for Illumina short reads 2. File has to be gzipped and have the extension .fastq.gz or .fq.gz.

### Rules

1. Read trimming with `fastp` with `--detect_adapter_for_pe` added as a param
2. Alignment with `bwa mem2` using the Snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/bwa-mem2/mem.html
3. If needed, `Picard AddReplaceReadGroups` using the Snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/addorreplacereadgroups.html
4. If needed, `Picard MergeSamFiles` using the Snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/mergesamfiles.html
5. `Picard MarkDuplicates` using the snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/markduplicates.html
6. Short variant calling and filtering using Mutect2 with the snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/meta-wrappers/bio/gatk_mutect2_calling.html
7. Short variant calling and filtering using MuSE2 based on the snakemake rule: https://github.com/wwylab/MuSE/blob/master/MuSE.Snakemake/rules/muse2.smk
8. Short variant calling and filtering using Strelka2 using the snakemake wrapper: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/strelka/somatic.html
9. Consensus variant calling on 'PASS' variants using `bcftools isec`
10. Variant annotation using VEP: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/vep/annotate.html
11. Copy number estimation using CNVkit: https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/cnvkit/batch.html

