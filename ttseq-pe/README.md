## Paired-end TT-seq snakemake pipeline

A snakemake pipeline for processing paired-end TT-seq (transient transcriptome sequencing, 4sU
labeled nascent RNA) data with a *Drosophila melanogaster* spike-in. Reads are aligned once to a
combined human + *Drosophila* STAR index, and the host signal is normalized two ways: by
sequencing depth and by the spike-in. Each normalization produces strand-specific bigWigs.

The processing follows the
[Pwmski/pipeline-tt-seq](https://github.com/Pwmski/pipeline-tt-seq) scripts and the method of the
[Harvard Nascent Transcriptomics Core](https://ntc.hms.harvard.edu/tt-seq):
- **From Pwmski/pipeline-tt-seq:** STAR alignment, dUTP strand splitting and per-strand bigWigs.
- **From Harvard NTC:**
  - STAR filtering parameters
  - duplicate removal
  - DESeq2 median-of-ratios size factors
  - 4sU-labeled *Drosophila* S2 spike-in

The NTC maps reads to dm6 first and then sends the unmapped reads to the host genome. This
pipeline instead aligns once to a combined index, so reads are never assigned to the spike-in
by a splice-unaware aligner.

Each rule resolves its own tool (`fastp`, `STAR`, `samtools`, `featureCounts`, `deepTools`,
`RustQC`, `MultiQC`) via a pinned conda environment in `envs/`, built automatically by Snakemake
when run with `--use-conda`. The `size_factors` rule is the exception: it is a small
`pandas`/`numpy` step that runs in the Snakemake environment itself, so no R is needed.

### Prerequisites

The combined reference is built by `generate-resources` (the `drosophila` block in its
`config.yaml`). It provides:
- `STAR_dm6_idx/`: STAR index of GRCh38 plus *Drosophila* BDGP6.54 (dm6)
- `gencode.v48.basic.annotation.with_dm6.gtf.gz`: the combined annotation

`/mnt/data/references` is read-only for regular users, so if these files aren't there yet, build
them with `snakemake --use-conda --cores 32 dm6 --config resources_dir=<writable dir>` in
`generate-resources` (see its README) and either have an admin copy them into
`/mnt/data/references` or point `star.index_dir` and `annotation_gtf` in `config.yaml` at them.

All *Drosophila* contigs and gene IDs carry the prefix `dm6_` (`spike_prefix` in `config.yaml`).
This pipeline uses that prefix to separate host reads and genes from spike-in ones.

### Usage

1. Clone the repository and `cd` into `ttseq-pe`.
2. Edit `samples.csv` in this directory. It has the columns:

   | column | description |
   |---|---|
   | `sample_name` | basename of the sample (shared across lanes) |
   | `read1`, `read2` | full paths to the raw fastq.gz files |

   ```
   sample_name,read1,read2
   ctrl_rep1,/path/ctrl_rep1_L001_R1.fq.gz,/path/ctrl_rep1_L001_R2.fq.gz
   ctrl_rep1,/path/ctrl_rep1_L002_R1.fq.gz,/path/ctrl_rep1_L002_R2.fq.gz
   treat_rep1,/path/treat_rep1_R1.fq.gz,/path/treat_rep1_R2.fq.gz
   ```
   For multiple lanes, add one row per lane with the same `sample_name`. Lanes are merged before
   trimming. The `samples.csv` shipped here is only an example with placeholder paths.
3. Check the paths and settings in `config.yaml`:
   - `strandedness`
   - `filter.remove_duplicates`
   - the `spikein` block
4. Run: `mamba activate snakemake && snakemake --use-conda --cores <N>`

Output goes to `results` by default (`work_dir` in `config.yaml`).

### Overview

1. **`fastp`** with paired-end adapter detection. Optionally add a fixed 5' clip, e.g.
   `--trim_front1 13 --trim_front2 13` in `fastp.extra_params`, as Pwmski's scripts do.
2. **`STAR`** alignment to the combined human + dm6 index, using the Harvard NTC TT-seq parameters
   in `star.extra_params`.
3. **`samtools markdup`** (`bam/{sample}.markdup.bam`):
   - Only unique primary alignments (MAPQ 255) are kept, human and fly.
   - Duplicates are **marked**, not removed.
   - This is the BAM deliverable.
4. **Host / spike-in split** (`bam/{sample}.fragments.tsv`):
   - Counts host and spike-in fragments (proper pairs).
   - Writes a temporary host-only BAM for the coverage tracks and RustQC.
   - Reads that map equally well to human and fly are not unique (MAPQ < 255), so they are
     excluded.
5. **`featureCounts`** on the combined annotation, stranded, counting read pairs. It runs at two
   levels:
   - `gene`: the whole gene body, introns included. This is the nascent transcription signal.
   - `exon`: exons only.
6. **Size factors** (`size_factors/size_factors.tsv`): see *Normalization* below. The step also
   splits the count matrices into `counts/{gene,exon}.human.tsv` and
   `counts/{gene,exon}.spikein.tsv`.
7. **Strand-specific bigWigs** (`bigwig/{sample}.{depth,spikein}.{plus,minus}.bw`):
   - deepTools `bamCoverage --filterRNAstrand` on the host-only BAM, at 10 bp bins.
   - Reads are not extended, since the data are spliced.
   - Coverage is divided by the size factor (`--scaleFactor 1/sf`).
   - Minus-strand values are positive.
8. **QC**, all collected in MultiQC:
   - **RustQC** (strandedness via `infer_experiment`, read distribution, duplication)
   - fastp, STAR and markdup stats
   - featureCounts gene-level assignment
   - a *TT-seq normalization* general-stats block (spike-in %, exonic fraction, both size
     factors)
   - a PCA of depth-normalized gene-body counts

### Normalization

`size_factors/size_factors.tsv` has one row per sample. Its columns are:

| column | description |
|---|---|
| `host_fragments`, `spikein_fragments`, `spikein_pct` | fragment counts and spike-in fraction |
| `exon_fraction` | exon-overlapping / gene-body host counts; low for TT-seq (mostly intronic), high for total RNA |
| `sf_depth` | DESeq2 median-of-ratios size factor on host gene-body counts |
| `sf_spikein` | DESeq2 median-of-ratios size factor on spike-in gene-body counts |
| `spikein_method` | `median_of_ratios`, or `total_counts` (see below) |

How the size factors are computed:
- **Spike-in genes used:** fly rRNA genes and genes on the fly mitochondrial and rDNA contigs are
  left out of `sf_spikein`. Their counts mostly track how well rRNA depletion worked, not
  labeling or library prep.
- **Fallback:** if fewer than `spikein.min_genes` spike-in genes have counts in every sample,
  `sf_spikein` falls back to total spike-in gene counts divided by their geometric mean.
- **Scaling convention:** both factors follow the DESeq2 convention, so normalized = raw / sf.

How to use them:
- **In DESeq2:** load the raw count matrix and set `sizeFactors(dds) <- sf_depth` (or
  `sf_spikein`).
- **Which factor:**
  - Use depth normalization when most transcription is unchanged between conditions.
  - Use spike-in normalization when a treatment may shift transcription globally, for example
    inhibitors or degrons.
  - The Harvard NTC uses depth normalization by default and spike-in normalization when the
    spike-in fraction differs clearly between samples. That fraction is shown in the MultiQC
    general stats.

If the libraries have no spike-in, remove the `spikein` block or set `spikein: enabled: false`.
Only depth-normalized factors and bigWigs are then made. If spike-in normalization is enabled
but a sample has no spike-in gene counts, the `size_factors` rule fails with an explanation.

### Notes

- **Strandedness:**
  - `strandedness: reverse` (the default) is for TruSeq Stranded / dUTP libraries, where read 2
    is sense to the RNA. Use `forward` for ligation-based kits.
  - The setting controls featureCounts `-s` and which reads go into the plus and minus bigWigs.
  - Unstranded libraries are not supported.
  - Check RustQC's `infer_experiment` panel in MultiQC: for `reverse`, most reads should be
    explained by `1+-,1-+,2++,2--`.
- **Duplicates:**
  - TT-seq has no UMIs. Short labeling pulses give high coverage of the same nascent fragments,
    so some duplicates are biological.
  - `filter.remove_duplicates: true` (Harvard NTC) drops duplicates from the counts
    (`featureCounts --ignoreDup`), the fragment counts and the bigWigs
    (`bamCoverage --samFlagExclude 1024`). `false` (Pwmski) keeps them.
  - Either way they stay marked in the BAM, and RustQC always sees them.
- **Mapping quality:** `filter.min_mapq` must stay 255, which means STAR unique alignments only.
  featureCounts never counts multimappers, and the bigWigs have to match the counts.
