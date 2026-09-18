[![works on my machine badge](https://cdn.jsdelivr.net/gh/nikku/works-on-my-machine@v0.4.0/badge.svg)](https://github.com/nikku/works-on-my-machine)

# `snakemake` workflows developed for Coriell Bioinformatics 

For full tranparency, I have used Claude for code assistance in the development of these workflows. 

## Current Workflows:

- Genome generation: A single workflow for generating pre-computed genome indeces and genomic resources
- Paired-end RNA-seq processing and quantification
- Paired-end ATAC-seq processing, peak calling with Genrich, and promoter abundance estimation
- Paired-end RRBS processing, methylation calling, and extraction
- De novo transcript assembly and quantification
- Estimation of bacterial read abundance from sequencing data using Kraken2 and Braken
- Somatic variant calling from tumor-normal WES/WGS data (work-in-progress)

## Caveats

All of the workflows assume you're working on Coriell's bioinformatics servers which means
paths to pre-generated genome indeces and system resources will not work on your machine. I have 
tried to keep these workflows as simple as possible. Most take only a single samples.csv file
as input and generate opinionated sets of output files. Modify the config.yaml files with the 
desired paths to your own pre-generated genome indeces. 
