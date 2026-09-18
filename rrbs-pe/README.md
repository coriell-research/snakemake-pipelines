## Paired-end RRBS methylation-calling snakemake pipeline

This is a simple snakemake pipeline for processing paired-end RRBS (Reduced Representation
Bisulfite Sequencing) data.

The pipeline assumes that you are running it on Coriell's server, meaning paths to pre-generated 
genome indeces are available. Each rule resolves its own tool via a pinned conda environment in 
`envs/`, built automatically by Snakemake when run with `--use-conda`.

### Usage

1. Clone the repository and `cd` into `rrbs-pe`:
   ```
   git clone https://github.com/coriell-research/snakemake-pipelines.git
   cd snakemake-pipelines/rrbs-pe
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

By default, the pipeline outputs directories in a folder called ../data (i.e.
one level up from the current working directory - the default output location can be
changed via `work_dir` in config.yaml).

### Overview

1. [Trim Galore](https://github.com/FelixKrueger/TrimGalore) in `--rrbs --paired --fastqc` mode
   trims adapters/quality and MspI end-repair artifacts, then runs Trim Galore's bundled FastQC
   engine on the trimmed reads
2. [Bismark](https://github.com/FelixKrueger/Bismark) alignment against a pre-built Bisulfite genome index
3. `bismark_methylation_extractor` (`--paired-end --gzip --cytosine_report --CX`) for per-cytosine
   methylation calls, plus a genome-wide cytosine report (`*_pe.CX_report.txt.gz`) for downstream
   tools (methylKit, DSS, dmrseq, etc.)
4. `bismark2report` for a per-sample HTML alignment/extraction summary
5. [MultiQC](https://github.com/MultiQC/MultiQC) to aggregate pipeline results (FastQC, Trim Galore,
   Bismark alignment, methylation extraction) across samples
