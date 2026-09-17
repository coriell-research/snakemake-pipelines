## Paired-end ATAC-seq snakemake pipeline

This a simple snakemake pipeline for processing ATAC-seq data.

The pipeline  assumes that you are running it on Coriell's  server, meaning paths to pre-generated 
genome indeces are available. Each rule resolves its own tool (`fastp`, `bowtie2`, `samtools`, `Genrich`, `bedGraphToBigWig`, `deeptools`, `subread`, `MultiQC`) via a pinned conda environment in `envs/`, 
built automatically by Snakemake when run with `--use-conda`.

### Usage

1. Copy the Snakefile and config.yaml into your working directory
2. Create a 'samples.csv' file in your working directory. The samples.csv file is
a simple 3 column file. The first column should be called 'sample_name' and 
list the basename of the samples to be analyzed. Columns 2 and 3 should be 
named 'read1' and 'read2', respectively, and contain the full path to the 
raw fastq.gz files on your system. If a sample was sequenced across multiple 
lanes, add one row per lane using the same 'sample_name' — the corresponding 
read1/read2 files will be merged automatically before trimming.
3. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores 32`

By default, the pipeline outputs directories in a folder called ../data (i.e. 
one level up from the current working directory - the default output location can be 
changed by editing the Snakefile).

### Overview

1. `fastp` using paired-end adapter detection
2. `Bowtie2` alignment with bowtie2 -> fixmate -> markdup -> position sorted BAMs
3. `Genrich` peak calling in ATAC-seq mode
4. `bedGraphToBigWig` to create raw signal files from Genrich bedGraph-ish output
