## Paired-end CUT&RUN snakemake pipeline

A simple snakemake pipeline for processing CUT&RUN data with IgG controls. Trimming and alignment
follow the `atacseq-pe` workflow; peaks are called with Genrich against a paired IgG control, after 
duplicates have been removed.

Each rule resolves its own tool (`fastp`, `bowtie2`, `samtools`, `Genrich`, `bedGraphToBigWig`,
`deeptools`, `MultiQC`) via a pinned conda environment in `envs/`, built automatically by Snakemake
when run with `--use-conda`.

### Usage

1. Clone the repository and `cd` into `cutrun-pe`.
2. Create a `samples.csv` file in this directory with the columns:

   | column | description |
   |---|---|
   | `sample_name` | basename of the sample (shared across lanes) |
   | `type` | `target` or `igg` |
   | `control` | `sample_name` of the IgG sample paired with this target (required for `target`, empty for `igg`) |
   | `read1`, `read2` | full paths to the raw fastq.gz files |

   ```
   sample_name,type,control,read1,read2
   H3K4me3_rep1,target,IgG_rep1,/path/H3K4me3_rep1_1.fq.gz,/path/H3K4me3_rep1_2.fq.gz
   IgG_rep1,igg,,/path/IgG_rep1_1.fq.gz,/path/IgG_rep1_2.fq.gz
   ```
   Multiple lanes: add one row per lane with the same `sample_name`, `type` and `control`; lanes
   are merged before trimming. One IgG may be shared by several targets.
3. Check paths and filtering settings in config.yaml
4. Run: `mamba activate snakemake && snakemake --use-conda --cores <N>`

Output goes to `../data` by default (`work_dir` in config.yaml).

### Overview

1. `fastp` using paired-end adapter detection
2. `Bowtie2` alignment (with `--dovetail`) -> fixmate -> markdup -> position sorted BAMs
3. `filter_bam`: proper pairs only, removes unmapped/secondary/QC-fail/**duplicate** reads and
   alignments with MAPQ < `filter.min_mapq` (default 10). Optional fragment length cap `filter.max_frag`
   (e.g. 120 for transcription factors; 0 = off)
4. `Genrich` peak calling of each target against its IgG (no `-j`, no `-r`)
5. `bedGraphToBigWig` signal tracks from the Genrich pileup (targets only)
6. QC: fragment size distributions (all samples), TSS profile, `plotFingerprint` target vs IgG,
   FRiP and peak counts (MultiQC general stats), fastp and markdup stats in MultiQC

### Optional: E. coli spike-in scaling

CUT&RUN carries over *E. coli* DNA from the pAG-MNase prep, which can be used to scale signal
between samples. When the `spikein` block in config.yaml is enabled, each sample's trimmed reads
are also aligned (end-to-end, `--no-overlap --no-dovetail -I 10 -X 700`) to an E. coli-only
bowtie2 index and the proper-pair fragments (MAPQ >= `spikein.min_mapq`) are counted
**without deduplication**. The scale factor is `scale_constant / E. coli fragments`. Outputs:

- `spikein/{sample}.spikein_mqc.tsv`: E. coli fragments, E. coli %, scale factor (MultiQC general stats; all samples)
- `bg2bw_spikenorm/{sample}.bw`: scaled signal tracks for targets (raw tracks in `bg2bw/` are kept;
  peak calling is unaffected)

Build the index with the `bowtie2_ecoli_index` rule in `generate-resources`. To run **without**
a spike-in (no E. coli index, or libraries with no carry-over), remove the `spikein` block or set
`spikein: enabled: false`; all spike-in rules and outputs are then skipped. If `enabled` but a sample
has no E. coli fragments, its scaled bigWig fails with an explanatory message.

IgG samples are processed through alignment and filtering and used only as controls.
