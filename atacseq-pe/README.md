## Paired-end ATAC-seq snakemake pipeline

This a simple snakemake pipeline for processing ATAC-seq data.

**This workflow does not account for samples from multiple lanes at the moment**. If you have 
samples split across multiple lanes you can concatenate them prior to running this pipeline. The 
pipeline also assumes that you are running it on Coriell's server, meaning dependencies are not 
resolved by the workflow itself and paths to pre-generated genome indeces are available. As such,
ensure `fastp`, `bowtie2`, `Genrich`, and `bedGraphToBigWig` are installed and available on your 
path.  

### Usage

1. Copy the Snakefile and config.yaml into your working directory
2. Create a 'samples.csv' file in your working directory. The samples.csv file is
a simple 3 column file. The first column should be called 'sample_name' and 
list the basename of the samples to be analyzed. Columns 2 and 3 should be 
named 'read1' and 'read2', respectively, and contain the full path to the 
raw fastq.gz files on your system.
3. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores 32`

By default, the pipeline outputs directories in a folder called ../data (i.e. 
one level up from the current working directory - the default output location can be 
changed by editing the Snakefile).

### Overview

1. `fastp` using paired-end adapter detection
2. `Bowtie2` alignment with bowtie2 -> fixmate -> markdup -> position sorted BAMs
3. `Genrich` peak calling in ATAC-seq mode
4. `bedGraphToBigWig` to create raw signal files from Genrich bedGraph-ish output

### TODO

- Add additional peak callers
- Allow for consensus calling across replicates
- `deeptools` normalized BAM coverage and computeMatrix integration