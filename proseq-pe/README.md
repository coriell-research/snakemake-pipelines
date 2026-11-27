## Paired-end PRO-seq snakemake pipeline

A snakemake pipeline for paired-end PRO-seq (precision nuclear run-on sequencing) data with an
optional *Drosophila melanogaster* spike-in. Reads are aligned once to a combined human +
*Drosophila* + human rDNA bowtie2 index. The output is:
- 1-nt, strand-specific bigWigs of RNA polymerase active sites (the RNA 3' end), raw and
  normalized four ways
- count matrices for TSS, promoter-proximal pause and gene-body windows
- a pausing index per gene
- QC in MultiQC

Analysis decisions follow:
- **[Mahat et al. 2016](https://doi.org/10.1038/nprot.2016.086)** (*Nature Protocols*, the PRO-seq
  protocol): library structure, adapters, strand logic, discarding multimappers, rDNA.
- **[Danko lab proseq2.0](https://github.com/Danko-Lab/proseq2.0)** and its
  [tutorial](https://github.com/Danko-Lab/tutorials/blob/master/PRO-seq.md): the rDNA contig in the
  index, dropping rDNA/chrM/unplaced reads from tracks, 1-nt plus/minus tracks of the R1 5' end on
  the opposite strand, raw-count tracks for dREG, and duplicates removed only when there are UMIs.
- **The [Harvard Nascent Transcriptomics Core](https://ntc.hms.harvard.edu/pro-seq)** /
  Adelman lab ([Mimoso & Goldman 2023](https://doi.org/10.1002/cpz1.961),
  [proTSScall](https://github.com/AdelmanLab/proTSScall)):
  - optional dual UMIs (umi_tools)
  - bowtie2 on a combined host + spike index, proper pairs only, then a host / spike-in split
  - dominant TSS per gene from the data
  - pause window TSS..+149 and gene body TSS+250..TES
  - the pausing index
  - spike-in factors and sample correlation QC
- **The lab's earlier analysis scripts:** an R1-only final BAM on standard chromosomes,
  featureCounts at protein-coding TSS ±150, and replicate-averaged tracks.

Most rules resolve their tool through a pinned
[snakemake wrapper](https://snakemake-wrappers.readthedocs.io) (v9.17.1: `fastp`, `bowtie2`,
`featureCounts`, `MultiQC`) or a pinned conda environment in `envs/` (`samtools`, `umi_tools`,
`deepTools`, UCSC `faSize`, `preseq`). Snakemake builds both automatically when run with
`--use-conda`. The annotation, dominant-TSS and size-factor steps are small `pandas`/`numpy`
steps that run in the Snakemake environment itself, so no R is needed.

### Prerequisites

The combined reference is built by `generate-resources` (its `dm6` target). It provides:
- `bt2_dm6_rdna_idx/`: bowtie2 index of GRCh38 plus *Drosophila* BDGP6.54 (dm6, contigs prefixed
  `dm6_`) plus the human 45S rDNA unit (GenBank U13369.1, contig `rDNA_U13369`)
- `gencode.v48.basic.annotation.with_dm6.gtf.gz`: the combined annotation (only host transcripts
  are used here)
- `GRCh38.primary_assembly.genome.fa.gz`: the host genome FASTA (`genome_fasta`), for the host
  contig lengths

`/mnt/data/references` is read-only for regular users. If these files aren't there yet, build them
with `snakemake --use-conda --cores 32 dm6 --config resources_dir=<writable dir>` in
`generate-resources` (see its README). Then either have an admin copy them into
`/mnt/data/references`, or point `bowtie2.index`, `annotation_gtf` and `genome_fasta` in
`config.yaml` at your copy.

### Usage

1. Clone the repository and `cd` into `proseq-pe`.
2. Edit `samples.csv` in this directory. It has the columns:

   | column | description |
   |---|---|
   | `sample_name` | basename of the sample (shared across lanes) |
   | `read1`, `read2` | full paths to the raw fastq.gz files |
   | `group` | optional: condition name; samples of a group get replicate-averaged bigWigs |

   ```
   sample_name,read1,read2,group
   dmso_rep1,/path/dmso_rep1_L001_R1.fq.gz,/path/dmso_rep1_L001_R2.fq.gz,dmso
   dmso_rep1,/path/dmso_rep1_L002_R1.fq.gz,/path/dmso_rep1_L002_R2.fq.gz,dmso
   treat_rep1,/path/treat_rep1_R1.fq.gz,/path/treat_rep1_R2.fq.gz,treat
   ```
   - For multiple lanes, add one row per lane with the same `sample_name` (and the same `group`).
     Lanes are merged before trimming.
   - Leave out the `group` column entirely to skip the group tracks.
   - The `samples.csv` shipped here is only an example with placeholder paths.
3. Check the paths and settings in `config.yaml`, in particular:
   - the `umi` block
   - `filter.remove_duplicates`
   - the `spikein` block
   - `bigwig.negate_minus` and `bigwig.group_bin_size`
4. Run: `mamba activate snakemake && snakemake --use-conda --cores <N>`

Output goes to `results` by default (`work_dir` in `config.yaml`).

### Library structure and strand logic

In PRO-seq, the RNA polymerase adds one biotin-NTP to the nascent RNA, and the library is
sequenced from that RNA 3' end:
- **R1** is the reverse complement of the RNA, starting at its 3' end. The 5'-most base of R1 is
  the polymerase active site, on the *opposite* strand of R1.
- **R2** reads the RNA 5' end in sense orientation.
- **Adapters:** R1 reads through into `TGGAATTCTCGGGTGCCAAGG` (reverse complement of the VRA5
  5' RNA adapter, TruSeq small RNA). R2 reads through into `GATCGTCGGACTGTAGAACTCTGAAC` (the VRA3
  3' RNA adapter).

The pipeline therefore counts and draws each fragment once, at the 5' end of its R1, with the strand
swapped. That is the same as Danko proseq2.0 with `--RNA3=R1_5prime --map5=FALSE`, Mahat et al.'s
`genomecov -5` with swapped strands, and NTC's `bowtie2stdBedGraph.pl -x`. Libraries where R1
holds the RNA 5' end (e.g. Danko leChRO-seq, PRO-cap) are not supported.

proseq2.0 defaults to `--map5=TRUE`. With only `--RNA3=R1_5prime`, as in its paired-end examples, it
writes the RNA *5'* end (the R2 5' end) instead of the polymerase position. Paired-end tracks
processed that way don't overlay these.

### Overview

1. **`umi_extract`** (only with `umi.enabled`): `umi_tools extract` moves the UMIs at the 5' end of
   R1 and R2 into the read name.
2. **`fastp`** (wrapper):
   - Trims the PRO-seq adapters and the Q20 3' ends (as Danko's `cutadapt -q 20`).
   - Keeps reads ≥ 20 nt.
   - Paired-end overlap trimming removes read-through exactly (including the mate's UMI). Most
     PRO-seq inserts are 20–40 nt, shorter than the read.
3. **`bowtie2`** (wrapper):
   - Aligns to the combined human + dm6 + rDNA index with `--very-sensitive --no-mixed
     --no-discordant --dovetail`.
   - Proper pairs only.
4. **Duplicates** → `bam/{sample}.bam` (combined genome, proper pairs, primary alignments; the BAM
   deliverable):
   - Without UMIs: `samtools markdup` marks duplicates, which stay in the BAM.
   - With UMIs: `umi_tools dedup --paired` removes PCR duplicates by position + UMI.
5. **Split** → `bam/r1/{sample}.bam` and `bam/{sample}.fragments.tsv`:
   - The R1-only BAM holds R1 of proper pairs with MAPQ ≥ `filter.min_mapq`, on host contigs
     matching `host_contig_regex` (`chr1–22, X, Y`). It is the input to all counting and tracks.
   - The split also counts fragments (R1s) mapped in total, on host, on spike-in (`dm6_` minus
     the fly rDNA / mitochondrial contigs), on rDNA, and on chrM.
6. **TSS windows** (`annotation/tx/{tss,pause}.saf`): built from host transcripts of the GTF with
   `gene_type` in `annotation.gene_types` (default `protein_coding`).
7. **`featureCounts`** (wrapper) on the R1-only BAM:
   - `-s 2 --read2pos 5 -O`: each R1 is counted once at its 5' base, antisense, in every
     overlapping window.
   - Output: `counts/tx/{tss,pause}.featureCounts`.
8. **Dominant TSS** (`annotation/dominant_tss.{tsv,bed}`, `annotation/genebody.saf`): see
   *Counting windows* below.
9. **featureCounts** on the gene bodies → `counts/genebody.featureCounts`.
10. **Size factors and count matrices** (`size_factors/size_factors.tsv`, `counts/*.tsv`): see
    *Normalization* below.
11. **Strand-specific bigWigs** (`bigwig/{sample}.{raw,depth,cpm,spikein}.{plus,minus}.bw`):
    - Made with deepTools `bamCoverage --Offset 1 --filterRNAstrand`: the 5' base of each R1,
      strands swapped (`forward` keeps R1 on the minus strand, i.e. plus-strand RNA).
    - 1-nt resolution, scaled by 1 / size factor (`--scaleFactor`).
    - With a `group` column, deepTools `bigwigAverage` gives `bigwig/group/{group}.{norm}.{strand}.bw`:
      the mean of the group's normalized tracks in `bigwig.group_bin_size` bins (default 50 nt). The
      `raw` group tracks are the replicates' summed counts at 1 nt instead (dREG input), made with
      `bamCoverage` on the pooled R1 BAMs (`samtools merge`).
    - `bigwig/host.chrom_sizes`: host contig lengths from `genome_fasta` (UCSC `faSize`), for dREG
      and other UCSC tools.
    - **TSS profiles** (`profile/tss.{norm}.{cbind,rbind}.pdf`, `profile.enabled`): deepTools
      `computeMatrix reference-point` at the dominant TSS of active genes (±1500 nt, 10-nt bins),
      on the group tracks (or the sample tracks without a `group` column), one matrix per strand.
      `cbind` plots plus- and minus-strand tracks side by side; `rbind` stacks the two strands into
      one line per track. Matrices are kept (`*.mat.gz`) for replotting with `plotProfile` /
      `plotHeatmap`.
12. **QC**, all collected in MultiQC:
    - fastp (adapter dimers, insert size: degraded libraries have short inserts)
    - bowtie2 alignment
    - duplicates (markdup or umi_tools)
    - featureCounts gene-body assignment
    - preseq library complexity (`preseq.enabled`)
    - a *PRO-seq normalization* general-stats block (spike-in %, rDNA %, chrM %, median pausing
      index, size factors)
    - PCA of gene-body counts
    - Spearman correlation of pause-window counts

### Counting windows and pausing index

All windows are strand-aware and inclusive, set in `windows` in `config.yaml`:

| window | definition | file |
|---|---|---|
| `tss` | TSS −150..+149 per transcript (the lab scripts' `promoters(tx, 150, 150)`) | `counts/tss_tx.tsv` |
| `pause` | TSS..+149, the promoter-proximal pause region (proTSScall) | `counts/pause.tsv` |
| `genebody` | dominant TSS +250 .. TES, genes with a TSS–TES span ≥ 400 | `counts/genebody.tsv` |

Dominant TSS, following proTSScall:
- Pause-window reads are summed over all samples.
- A transcript is active when it has more than `windows.active_min_reads` reads. This threshold
  scales with the number of samples and their depth.
- For each gene, the dominant TSS is the active transcript with the most reads. Ties go to the more
  upstream TSS, then to the longer transcript.

`counts/pause.tsv` and `counts/genebody.tsv` are gene-level (dominant transcript).
`counts/tss_tx.tsv` is transcript-level, for all transcripts.

**Pausing index:** pause-window read density divided by gene-body read density, per gene and
sample. `counts/pause_index.tsv` is NaN where the gene body has no reads. Its per-sample median is
reported in MultiQC. Most active genes in mammalian cells are paused (index > 1, often > 4).

### Normalization

`size_factors/size_factors.tsv` has one row per sample. Its columns are:

| column | description |
|---|---|
| `total_mapped` | R1 of proper pairs, any genome, any MAPQ |
| `host`, `spikein`, `rdna`, `chrM` | fragment (R1) counts per category |
| `spikein_pct` | spikein / (host + spikein) |
| `rdna_pct` | rdna / total_mapped (any MAPQ) |
| `chrM_pct` | chrM / total_mapped |
| `median_pause_index`, `active_genes` | see above |
| `sf_raw` | 1: unscaled counts, Danko proseq2.0 style; the dREG input |
| `sf_depth` | DESeq2 median-of-ratios on gene-body counts |
| `sf_cpm` | host fragments / 1e6, so tracks are in CPM (as the lab's earlier tracks). Danko's `.rpm.bw` divides by all mapped pairs, rDNA and chrM included, so its values are lower when rDNA is abundant |
| `sf_spikein` | spike-in fragments / their geometric mean (Harvard NTC) |

Every factor follows the DESeq2 convention, normalized = raw / sf. The bigWigs use
`scale = 1 / sf`. In DESeq2, load the raw count matrix and set `sizeFactors(dds)`.

Which factor to use:
- **Depth** (`sf_depth`, or CPM for browsing) assumes most transcription is unchanged between
  conditions.
- **Spike-in** is for treatments that may change transcription globally, for example CDK or
  P-TEFb inhibitors, or degrons. It requires a constant number of spike-in cells per sample.
  The Harvard NTC uses depth normalization by default and spike-in normalization when the
  spike-in % differs clearly between samples. That percentage is in the MultiQC general stats.

If the libraries have no spike-in, remove the `spikein` block or set `spikein: enabled: false`.
If spike-in normalization is enabled but a sample's spike-in fragments are below `spikein.min_pct`
(default 0.1%) of host + spike-in, the `size_factors` rule fails with an explanation. A real
spike-in gives about 1–5%; far less usually means no spike-in was added, and so few reads give an
unreliable factor.

### Notes

- **UMIs:** set `umi.enabled: true` and the UMI lengths for libraries with UMI adapters, e.g. the
  Harvard NTC's 6-nt UMIs on both reads. Without UMIs, check that reads start with genomic
  sequence. Adapter dimers then look like `TGGAATTCTCGG...` at position 0 of R1.
- **Duplicates without UMIs:**
  - Promoter-paused RNAs share both ends, so many identical fragments are biological.
  - Removing duplicates by position collapses pause peaks and lowers the pausing index. Mahat et
    al. and the Danko lab don't deduplicate without UMIs, and the NTC says UMIs are needed for
    paused RNAs.
  - `filter.remove_duplicates` is therefore `false` by default. Duplicates stay marked in the BAM.
  - Set it `true` to match the lab's earlier scripts (`samtools markdup -r`). It is ignored when
    UMIs are enabled.
- **rDNA:**
  - Run-on reads from Pol I can be a large share of a library (30–40% in Mahat et al.).
  - The full rDNA unit is in the index, so they land on `rDNA_U13369` instead of mis-mapping. The
    GRCh38 unplaced scaffolds `GL000220.1` and `KI270733.1` also carry rDNA copies, and rRNA reads
    multimap among the three.
  - `rdna_contigs` therefore lists all three. They are counted at any MAPQ for `rdna_pct`, and
    never enter counts or tracks.
- **chrM and unplaced contigs** are left out of counts and tracks (Danko practice); chrM is
  reported as `chrM_pct`.
- **Mapping quality:**
  - `filter.min_mapq: 10` drops bowtie2 multimappers (MAPQ 0–1), as the lab scripts do. The
    Danko lab uses MAPQ ≥ 20 on a different (bwa) scale.
  - It is applied after duplicate marking, not before (unlike `ttseq-pe`), so that rDNA reads can
    be counted at any MAPQ.
- **Minus strand sign:** both strands are positive by default (NTC). Set
  `bigwig.negate_minus: true` for negative minus-strand values (Danko/UCSC convention). dREG accepts
  either sign as long as each strand has one sign only.
- **dREG input:** dREG needs unnormalized read counts at the RNA 3' end, one position per read.
  The per-sample `raw` tracks and the group `raw` tracks (the replicates' summed counts at 1 nt,
  as Danko's `mergeBigWigs.bsh`) both qualify; the normalized and binned tracks do not.
- **Read length:** reads shorter than 20 nt after trimming are dropped. The Danko lab keeps 15 nt,
  but such reads rarely map uniquely to the human genome. Change `--length_required` in
  `fastp.extra_params` if needed.
- **Out of scope:** differential testing (load `counts/genebody.tsv` or `counts/pause.tsv` into
  DESeq2/edgeR with the size factors above), dREG / TSS calling, and gene-length or gene-body metagene
  plots (the dominant-TSS BED and the bigWigs are ready for deepTools `computeMatrix scale-regions`).
