## Use Kraken2 and Bracken to estimate microbial abundance

### Usage 

The Kraken database path is hardcoded into the rule. The Kraken database should be copied into
shared memory. Shared memory may need to be resized to accommodate the database, which is about
88GB in size.

To resize /dev/shm:
`sudo mount -o remount,size=100G /dev/shm`

Then copy the Kraken database into /dev/shm:
`cp -r /mnt/data/gdata/kraken2/standard /dev/shm`

Then you can run the workflow:

1. Copy the Snakefile into your working directory
2. Create a 'samples.csv' file. The 'samples.csv' file needs one column called 'sample_name'
that describes the basename of the sample to classify, and columns called 'read1' and 'read2', 
which specify the full path to the read1 and read2 fastq.gz files on your system. NOTE, if you
have single-end sequencing then simply omit read2.
3. Run the workflow: `mamba activate snakemake && snakmake --cores 32` 

### Overview

1. Run Kraken2 on the full database to produce estimated species counts
2. Run Bracken to refine species abundance estimates

