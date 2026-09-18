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

0. Resource bundle download from GATK resources cloud bucket
1. Read trimming with [fastp](https://github.com/OpenGene/fastp)
2. Alignment with `bwa mem` using the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/bwa/mem.html)
3. If needed, `Picard MergeSamFiles` using the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/mergesamfiles.html)
4. `Picard MarkDuplicates` using the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/markduplicates.html)
5. Short variant calling and filtering using [Mutect2](https://gatk.broadinstitute.org/hc/en-us/articles/360037593851-Mutect2) with the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/meta-wrappers/bio/gatk_mutect2_calling.html)
6. Short variant calling and filtering using [MuSE2](https://github.com/wwylab/MuSE) based on the [snakemake rule](https://github.com/wwylab/MuSE/blob/master/MuSE.Snakemake/rules/muse2.smk)
7. Short variant calling and filtering using [Strelka2](https://github.com/Illumina/strelka) using the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/strelka/somatic.html)
9. Short variant calling using [DeepSomatic](https://github.com/google/deepsomatic)
8. Consensus variant calling on 'PASS' variants using `bcftools isec`
9. Variant annotation using [VEP](https://github.com/Ensembl/ensembl-vep) [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/vep/annotate.html)
10. Copy number estimation using [CNVkit](https://cnvkit.readthedocs.io/en/stable/) [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/cnvkit/batch.html)
11. Rapid (kind of) genotyping of known somatic variants from the tumor BAM files with [somaticfreq](https://github.com/PoisonAlien/somaticfreq)

