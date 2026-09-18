## Genome resource generation snakemake pipeline

This is a snakemake pipeline for downloading and building the shared genome resources
(annotation, sequence, and aligner indices). 

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

The same recipe is built for all three GENCODE genome builds configured (human GRCh38, mouse
GRCm39/M38, mouse GRCm38-mm10/M25):

1. Download the basic gene annotation GTF, transcript sequences, and primary assembly genome
   FASTA from GENCODE (human also gets promoter windows).
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
3. Download the excludable/blacklist regions BED file (`excluderanges.bed`) directly from
   [bedbase.org](https://bedbase.org), via each species' `excluderanges.bed_url` in `config.yaml`.
4. Build the `chrom.sizes` file via UCSC's `faSize` (genome + ERCC + GFP entries).

### Notes

- The index-build rules (`star_index`, `bowtie2_index`, etc.) are written once and parameterized
  over `{assembly}`/`{release}` Snakemake wildcards rather than duplicated per species, since
  directory and genome-stem naming is uniform across all three builds
  (`<resources_dir>/<assembly>/GENCODE/<release>/...`,
  `<assembly>.primary_assembly.genome[.fa[.gz]]`).
- The decompressed, plain-text copies of the genome/annotation/transcript FASTA/GTF needed to
  build most indices are transient (`temp()`) - the persisted downloads stay gzipped, matching
  the existing resource layout on disk.
- Bismark and bwa-meth accept gzipped FASTA directly, so their rules concatenate the
  still-gzipped genome + lambda downloads rather than decompressing first (the same trick
  `rrbs-pe`'s `merge_lanes` rule uses for multi-lane FASTQs).
- STAR/Bowtie2/bwa-mem2/minimap2/`minibwa` all index a single, materialized genome+ERCC+GFP
  FASTA per species (built once by `rule combine_with_spikes`) rather than being piped a
  concatenated stream or handed multiple separate file arguments. Salmon builds its own
  materialized `gentrome.fa` instead, since ERCC/GFP need to land in its target section rather
  than its decoy section.
- The ERCC92, GFP, and lambda phage spike-in FASTAs have no canonical public source, so they're
  downloaded from this repo's own `generate-resources/data/` directory (see `spike_ins` in
  `config.yaml`) into `<resources_dir>/spike_ins/`, and are shared across all three species
  (the same physical spike-in/lambda preps are used regardless of the organism sequenced).
