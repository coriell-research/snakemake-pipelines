## Paired-end ATAC-seq snakemake pipeline

This a simple snakemake pipeline for processing ATAC-seq data.

The pipeline assumes that you are running it on Coriell's server, meaning paths to pre-generated 
genome indeces are available. Each rule resolves its own tool (`fastp`, `bowtie2`, `samtools`, 
`Genrich`, `bedGraphToBigWig`, `deeptools`, `subread`, `MultiQC`) via a pinned conda environment 
in `envs/`, built automatically by Snakemake when run with `--use-conda`.

### Usage

1. Clone the repository and `cd` into `atacseq-pe`:
   ```
   git clone https://github.com/coriell-research/snakemake-pipelines.git
   cd snakemake-pipelines/atacseq-pe
   ```
2. Create a 'samples.csv' file in this directory. The samples.csv file is
a simple 3 column file. The first column should be called 'sample_name' and
list the basename of the samples to be analyzed. Columns 2 and 3 should be
named 'read1' and 'read2', respectively, and contain the full path to the
raw fastq.gz files on your system. If a sample was sequenced across multiple
lanes, add one row per lane using the same 'sample_name', the corresponding
read1/read2 files will be merged automatically before trimming.
3. Ensure paths to genome indeces are correctly configured in config.yaml
4. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores <N>`

By default, the pipeline outputs directories in a folder called `results` (inside the pipeline directory; the output location can be
changed via `work_dir` in config.yaml).

### Overview

1. `fastp` using paired-end adapter detection
2. `Bowtie2` alignment with bowtie2 -> fixmate -> markdup -> position sorted BAMs
3. `filter_bam`: keeps proper pairs, drops unmapped/secondary/QC-fail reads and MAPQ < `filter.min_mapq` (default 10); duplicates stay flagged in the BAM
4. `Genrich` peak calling in ATAC-seq mode (`-r` removes PCR duplicates)
5. `bedGraphToBigWig` to create raw signal files from Genrich bedGraph-ish output
