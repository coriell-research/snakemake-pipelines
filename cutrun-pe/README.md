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

IgG samples are processed through alignment and filtering and used only as controls.
