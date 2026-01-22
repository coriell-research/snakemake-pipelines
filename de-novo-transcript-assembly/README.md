## Paired-end De Novo Transcript Assembly and Quantification

This a simple snakemake pipeline for aligning paired-end reads using STAR, performing de novo 
transcript assembly with stringtie3, and quantifying transcript counts with Salmon. The de novo
transcript assembly pipeline assumes RNA-seq data were generated from a stranded total RNA 
(rRNA depletion) protocol. 

**This workflow does not account for samples from multiple lanes at the moment**. If you have 
samples that are split across multiple lanes you can cat them together prior to running this 
pipeline.

### Usage

1. Copy the Snakefile and config.yaml into your working directory
2. Create a 'samples.csv' file in your working directory. The samples.csv file is
a simple 3 column file. The first column should be called 'sample_name' and 
list the basename of the samples to be analyzed. Columns 2 and 3 should be 
named 'read1' and 'read2', respectively, and contain the full path to the 
raw fastq.gz files on your system. An example 'samples.csv' file is in this repo.
3. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores 32`

By default, the pipeline outputs directories in a folder called ../data (i.e. 
one level up from the current working directory - the default output location can be 
changed by editing the Snakefile).

### Overview

1. `fastp` using paired-end adapter detection
2. `STAR` 2-PASS alignment of trimmed reads
3. `stringtie3` de novo transcript discovery on alignments
4. `Salmon` quantification on the assembled consensus transcript sequences
