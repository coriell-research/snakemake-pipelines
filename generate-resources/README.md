## Genome resource generation snakemake pipeline

This is a snakemake pipeline for downloading and building the shared genome resources
(annotation, sequence, and aligner indices).

Each aligner index is built with its [Snakemake wrapper](https://snakemake-wrappers.readthedocs.io/)
(pinned to `v9.17.1`, except `minibwa`, whose wrapper first appears in `v9.18.0`). Each wrapper
brings its own pinned conda environment, built automatically by Snakemake when run with
`--use-conda`. The only local environments left in `envs/` are `ucsc.yaml` (`faSize`, which has no
wrapper) and `salmon.yaml`, which overrides the salmon wrapper's own env so that the index matches
the salmon 1.10.0 that `rnaseq-pe` uses to read it (the wrapper ships the salmon 2.x rewrite).

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

2. Build **two sets of indices** for each aligner:

   **Primary-only indices** (genome only, no spike-ins):
   - [STAR](https://github.com/alexdobin/STAR) index (`STAR_idx/`)
   - [Bowtie2](https://github.com/BenLangmead/bowtie2) index (`bt2_idx/`)
   - [BWA](https://github.com/lh3/bwa) index (`bwa_idx/`)
   - [bwa-mem2](https://github.com/bwa-mem2/bwa-mem2) index (`bwa-mem2_idx/`)
   - [Salmon](https://salmon.readthedocs.io/) index (`salmon_idx/`) - decoy-aware with genome as decoy
   - [minimap2](https://github.com/lh3/minimap2) index (`mm2_idx/`)
   - [Bismark](https://github.com/FelixKrueger/Bismark) index (`bismark_idx/`)
   - [bwa-meth](https://github.com/brentp/bwa-meth) index (`bwa-meth_idx/`)
   - `minibwa` index (`minibwa_idx/`)

   **Spike-in indices** (genome + ERCC92 + GFP, or + lambda for bisulfite aligners):
   - STAR index (`STAR_ercc_gfp_idx/`)
   - Bowtie2 index (`bt2_ercc_gfp_idx/`)
   - BWA index (`bwa_ercc_gfp_idx/`)
   - bwa-mem2 index (`bwa-mem2_ercc_gfp_idx/`)
   - Salmon index (`salmon_ercc_gfp_idx/`) - transcripts + ERCC + GFP as targets, genome as decoy
   - minimap2 index (`mm2_ercc_gfp_idx/`)
   - Bismark index (`bismark_lambda_idx/`) - genome + lambda phage
   - bwa-meth index (`bwa-meth_lambda_idx/`) - genome + lambda phage
   - `minibwa` index (`minibwa_ercc_gfp_idx/`)

3. Download the excludable/blacklist regions BED file (`excluderanges.bed.gz`, kept gzipped) directly from
   [bedbase.org](https://bedbase.org), via each species' `excluderanges.bed_url` in `config.yaml`.

4. Build **two `chrom.sizes` files** via UCSC's `faSize`:
   - `<assembly>.primary_assembly.genome.fa.chrom_sizes` - primary genome only
   - `<assembly>.primary_assembly.genome.fa.ercc_gfp.chrom_sizes` - includes ERCC + GFP entries

### Directory Structure

```
<resources_dir>/<assembly>/GENCODE/<release>/
├── <assembly>.primary_assembly.genome.fa.gz          # Primary genome (gzipped)
├── <assembly>.primary_assembly.genome.with_lambda.fa.gz  # Genome + lambda (Bismark reads this)
├── <assembly>.primary_assembly.genome.fa.chrom_sizes # Chrom sizes (primary only)
├── <assembly>.primary_assembly.genome.fa.ercc_gfp.chrom_sizes  # Chrom sizes (with spikes)
├── gencode.v*.basic.annotation.gtf.gz
├── gencode.v*.transcripts.fa.gz
├── excluderanges.bed.gz
│
├── STAR_idx/                  # Primary only
├── STAR_ercc_gfp_idx/         # With ERCC + GFP
│
├── bt2_idx/                   # Primary only
├── bt2_ercc_gfp_idx/          # With ERCC + GFP
│
├── bwa_idx/                   # Primary only
├── bwa_ercc_gfp_idx/          # With ERCC + GFP
│
├── bwa-mem2_idx/              # Primary only
├── bwa-mem2_ercc_gfp_idx/     # With ERCC + GFP
│
├── salmon_idx/                # Primary only (genome decoy)
├── salmon_ercc_gfp_idx/       # With ERCC + GFP
│
├── mm2_idx/                   # Primary only
├── mm2_ercc_gfp_idx/          # With ERCC + GFP
│
├── bismark_idx/               # Primary only
├── bismark_lambda_idx/        # With lambda phage
│
├── bwa-meth_idx/              # Primary only
├── bwa-meth_lambda_idx/       # With lambda phage
│
├── minibwa_idx/               # Primary only
└── minibwa_ercc_gfp_idx/      # With ERCC + GFP
```

### Notes

- The index-build rules are written once and parameterized over `{assembly}`/`{release}` Snakemake
  wildcards rather than duplicated per species, since directory and genome-stem naming is uniform
  across all three builds (`<resources_dir>/<assembly>/GENCODE/<release>/...`,
  `<assembly>.primary_assembly.genome[.fa[.gz]]`).
- Every download stays gzipped. Bowtie2, BWA, bwa-mem2, minimap2, `minibwa`, Salmon, Bismark,
  bwa-meth and `faSize` all read the `.gz` files directly. Combined FASTAs are built by
  concatenating the gzipped files (`cat a.fa.gz b.fa.gz > c.fa.gz`, which is a valid gzip file),
  the same trick `rrbs-pe`'s `merge_lanes` rule uses for multi-lane FASTQs. The only
  decompressed files are the genome, genome+ERCC+GFP FASTA and GTF that STAR needs (STAR can't
  read gzip), and those are `temp()`, so they're deleted once the STAR indices are built.
- `rule combine_with_lambda` builds the genome + lambda FASTA used by Bismark and bwa-meth.
  That combined FASTA is kept (not
  `temp()`), because the Bismark wrapper places a relative symlink to its input FASTA inside the
  index directory, and Bismark reads that FASTA again at alignment time. For the same reason,
  `bismark_idx/` holds a symlink to the downloaded genome rather than a copy.
- `rule bwameth_reference` copies the reference FASTA into `bwa-meth[_lambda]_idx/`, because
  bwa-meth's aligner expects the reference next to its `.bwameth.c2t*` index files and the
  wrapper only writes the index files. The bwa-meth wrapper builds the index in the system temp
  directory before moving it into place, so set `TMPDIR` if `/tmp` is small.
- The Bismark wrapper runs `--parallel threads/2` (one half for each conversion), so
  `threads.bismark_genome_preparation` is the total thread count for that job.
- STAR/Bowtie2/BWA/bwa-mem2/minimap2/`minibwa` spike-in indices all use a single, materialized
  genome+ERCC+GFP FASTA per species (`<assembly>.primary_assembly.genome.with_spikes.fa.gz`,
  built once by `rule combine_with_spikes` as a `temp()` file). Salmon gets its own materialized
  `gentrome[_ercc_gfp].fa.gz` and `decoys.txt` (both `temp()`) instead, since
  ERCC/GFP need to land in its target section rather than its decoy section.
- The ERCC92, GFP, and lambda phage spike-in FASTAs have no canonical public source, so they're
  downloaded from this repo's own `generate-resources/data/` directory (see `spike_ins` in
  `config.yaml`) into `<resources_dir>/spike_ins/`, and are shared across all three species
  (the same physical spike-in/lambda preps are used regardless of the organism sequenced).
