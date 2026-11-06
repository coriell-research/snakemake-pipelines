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
   URLs for human/mouse, the Ensembl *Drosophila* URLs under `drosophila`, and `spike_ins`
3. Run the pipeline: `mamba activate snakemake && snakemake --use-conda --cores <N>`

   The workflow profile in `profiles/default` is picked up automatically and points job
   scratch space (`$TMPDIR`) at `./tmp` rather than `/tmp`, since the index builds (STAR,
   Bismark, etc.) can exceed the free space on `/tmp`.

   The profile also runs the index builds one at a time (`resources: index_jobs=1`), since
   each can take 50-250 GB of RAM (bwa-mem2 ~130 GB and bwa-meth ~250 GB for GRCh38) and
   running them together gets them OOM-killed. Downloads and other small jobs still run
   alongside. Multi-threaded index builds use the thread counts under `threads` in
   `config.yaml`, scaled down to `--cores` if that's lower. To allow more concurrent builds
   on a large-memory server, pass e.g. `--resources index_jobs=2`.

Everything is written under `<resources_dir>/<assembly>/GENCODE/<release>/...` (the
*Drosophila* downloads go to `<resources_dir>/BDGP6.54/Ensembl/114/`). The other
pipelines' configs (`atacseq-pe`, `rnaseq-pe`, `rrbs-pe`, `de-novo-transcript-assembly`, `ttseq-pe`)
expect this tree at the shared location `/mnt/data/references`, and default to the spike-in
indices (ERCC + GFP, lambda for Bismark, or the host + dm6 index for `ttseq-pe`).

`/mnt/data/references` is not writable by regular users. To add resources there, build them into
a directory you can write to and have an admin copy them in (see *Building only the human +
Drosophila resources* below).

### Building only the human + Drosophila resources

The `dm6` target builds just the host + *Drosophila* resources (and the 6 downloads they need)
instead of every index. Since `/mnt/data/references` is read-only for regular users, build them
into a directory you can write to:

```
snakemake --use-conda --cores 32 dm6 --config resources_dir=/path/to/my/references
```

The STAR index build needs ~35 GB RAM. Then either have an admin copy the new files into the
shared tree (only these paths are new; nothing existing is overwritten):

```
/path/to/my/references/BDGP6.54/                                   -> /mnt/data/references/BDGP6.54/
/path/to/my/references/GRCh38/GENCODE/v48/STAR_dm6_idx/           -> /mnt/data/references/GRCh38/GENCODE/v48/
/path/to/my/references/GRCh38/GENCODE/v48/gencode.v48.basic.annotation.with_dm6.gtf.gz
/path/to/my/references/GRCh38/GENCODE/v48/GRCh38.primary_assembly.genome.fa.dm6.chrom_sizes
/path/to/my/references/GRCh38/GENCODE/v48/excluderanges.with_dm6.bed.gz
```

or point `star.index_dir` and `annotation_gtf` in `ttseq-pe/config.yaml` at your copy.

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

   **E. coli index** (species-independent, for CUT&RUN spike-in scaling):
   - Bowtie2 index of E. coli K-12 MG1655 (`spike_ins/bt2_ecoli_idx/`)

3. Download the excludable/blacklist regions BED file (`excluderanges.bed.gz`, kept gzipped) directly from
   [bedbase.org](https://bedbase.org), via each species' `excluderanges.bed_url` in `config.yaml`.

4. Build **two `chrom.sizes` files** via UCSC's `faSize`:
   - `<assembly>.primary_assembly.genome.fa.chrom_sizes` - primary genome only
   - `<assembly>.primary_assembly.genome.fa.ercc_gfp.chrom_sizes` - includes ERCC + GFP entries

5. Build a **host + *Drosophila* spike-in reference** (for TT-seq, see `ttseq-pe`) for each
   assembly in `drosophila.hosts` (only GRCh38 for now; mouse is not built). The *Drosophila
   melanogaster* genome and annotation come from Ensembl (BDGP6.54, release 114 to match
   GENCODE v48; the BDGP6 sequence is the UCSC dm6 assembly). Every fly contig, `gene_id` and
   `transcript_id` is prefixed with `dm6_` (e.g. `dm6_2L`, `dm6_FBgn0038189`) so nothing collides
   with the host names, and the fly GTF's `transposable_element` entries (multi-copy FBti
   insertions) are dropped and `gene_biotype`/`transcript_biotype` are renamed to GENCODE's
   `gene_type`/`transcript_type`. From the prefixed files:
   - STAR index of genome + dm6 (`STAR_dm6_idx/`)
   - Combined annotation (`gencode.v48.basic.annotation.with_dm6.gtf.gz`)
   - `<assembly>.primary_assembly.genome.fa.dm6.chrom_sizes` - includes the `dm6_` contigs
   - `excluderanges.with_dm6.bed.gz` - host excluderanges plus the Boyle-lab dm6 excludable
     regions (renamed `chr*` -> `dm6_*`), both cut to BED3

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
├── minibwa_ercc_gfp_idx/      # With ERCC + GFP
│
│   # Host + Drosophila (GRCh38 only, see drosophila.hosts)
├── STAR_dm6_idx/              # Genome + dm6_-prefixed fly genome
├── gencode.v*.basic.annotation.with_dm6.gtf.gz
├── <assembly>.primary_assembly.genome.fa.dm6.chrom_sizes
└── excluderanges.with_dm6.bed.gz

<resources_dir>/BDGP6.54/Ensembl/114/
├── Drosophila_melanogaster.BDGP6.54.dna.toplevel.fa.gz           # Ensembl download
├── Drosophila_melanogaster.BDGP6.54.dna.toplevel.dm6_prefixed.fa.gz
├── Drosophila_melanogaster.BDGP6.54.114.gtf.gz                   # Ensembl download
├── Drosophila_melanogaster.BDGP6.54.114.dm6_prefixed.gtf.gz
└── excluderanges.bed.gz                                          # dm6 excludable (UCSC names)
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
  decompressed files are the genome, genome+ERCC+GFP and genome+dm6 FASTAs and the (combined) GTFs
  that STAR needs (STAR can't read gzip), and those are `temp()`, so they're deleted once the STAR
  indices are built.
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
- The `dm6_` prefix on *Drosophila* contigs/genes is fixed (`FLY_PREFIX` in the Snakefile) because
  `ttseq-pe` relies on it (its `spike_prefix`) to split host and spike-in reads and genes. The
  combined genome FASTA (`*.with_dm6.fa.gz`) and the plain copies STAR reads are `temp()`; the
  prefixed fly FASTA/GTF are kept, so the combination can be rebuilt cheaply.
