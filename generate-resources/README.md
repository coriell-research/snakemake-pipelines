## Genome resource generation snakemake pipeline

This is a snakemake pipeline for downloading and building the shared genome resources
(annotation, sequence, and aligner indices) that `atacseq-pe`, `rnaseq-pe`, and `rrbs-pe`
point their own configs at. 

Each rule resolves its own tool via a pinned conda environment in `envs/`, built automatically 
by Snakemake when run with `--use-conda`. Several env pins are deliberately matched to the exact 
tool version another pipeline in this repo already uses to consume the corresponding index 
(see the comments in `envs/*.yaml`) rather than to the newest available release.

### Usage

1. Clone the repository and `cd` into `generate-resources`:
   ```
   git clone git@github.com:coriell-research/snakemake-pipelines.git
   cd snakemake-pipelines/generate-resources
   ```
2. Review `config.yaml`: `resources_dir` (where everything is written), the GENCODE release
   URLs for human/mouse, and `spike_ins`
3. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores <N>`

Everything is written under `<resources_dir>/<assembly>/GENCODE/<release>/...`, matching the
paths already hardcoded into `atacseq-pe/config.yaml`, `rnaseq-pe/config.yaml`, and
`rrbs-pe/config.yaml`.

### Overview

**Human (GRCh38, GENCODE release configured via `human.release`)**

1. Download the basic gene annotation GTF, promoter windows, transcript sequences, and primary
   assembly genome FASTA from GENCODE.
2. Build, from the genome FASTA (+ ERCC92 + GFP spike-ins, except where noted):
   - [STAR](https://github.com/alexdobin/STAR) index, optimized for 150bp reads
   - [Bowtie2](https://github.com/BenLangmead/bowtie2) index
   - [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2) index
   - [Salmon](https://salmon.readthedocs.io/) index (decoy-aware, transcripts + ERCC + GFP as
     targets, genome as the decoy)
   - [minimap2](https://github.com/lh3/minimap2) index
   - [Bismark](https://github.com/FelixKrueger/Bismark) index (genome + lambda phage genome,
     *no* ERCC/GFP - Bismark recommends against non-bisulfite spike-ins here)
   - [bwa-meth](https://github.com/brentp/bwa-meth) index (genome + lambda phage genome)
   - `minibwa` index
3. Build the excludable/blacklist regions BED file via Bioconductor's `AnnotationHub`
   (`excluderanges`).
4. Build the `chrom.sizes` file via UCSC's `faSize` (genome + ERCC + GFP entries).

**Mouse (GRCm39/M38 and GRCm38-mm10/M25)**

### Notes

- The decompressed, plain-text copies of the genome/annotation/transcript FASTA/GTF needed to
  build most indices are transient (`temp()`) - the persisted downloads stay gzipped, matching
  the existing resource layout on disk.
- Bismark and bwa-meth accept gzipped FASTA directly, so their rules concatenate the
  still-gzipped genome + lambda downloads rather than decompressing first (the same trick
  `rrbs-pe`'s `merge_lanes` rule uses for multi-lane FASTQs).
