## Overview

Germline short variant (SNV/indel) calling from paired-end RNA-seq data. It follows
[GATK's RNA-seq short variant discovery best practices](https://gatk.broadinstitute.org/hc/en-us/articles/360035531192-RNAseq-short-variant-discovery-SNPs-Indels)
and adds two more callers, [DeepVariant](https://github.com/google/deepvariant) (RNA-seq model)
and `bcftools mpileup`/`call`. The workflow writes per-caller calls and a consensus call set,
all annotated with VEP. Samples are called one at a time; there is no joint genotyping.

### Usage

1. `cd rnaseq-variant-calling` and fill in `samples.csv` (see *Input*)
2. Review `config.yaml`
3. Run the workflow: `mamba activate snakemake && snakemake --use-conda --cores <N>`

`singularity` must be on `PATH` for DeepVariant. All reference resources are downloaded and built
the first time they're needed. To fetch and build them up front, run
`snakemake --use-conda --cores <N> download_resources`.

### Input

The input `samples.csv` file has the following required columns:

- **sample** : Sample ID. Must be unique for each biological sample. Lanes of the same sample share
  this ID and are aligned together (see *lane*). It is used as the read group SM tag, so it can't
  contain whitespace, commas or slashes.
- **lane** : Lane ID, used when a sample is sequenced on several lanes. Must be unique within a
  sample (it does not need to be the original lane name) and must contain at least one character.
  The same character restrictions as *sample* apply.
- **read1** : Full path to the FASTQ file for Illumina read 1. The file must be gzipped with the
  extension `.fastq.gz` or `.fq.gz`.
- **read2** : Full path to the FASTQ file for Illumina read 2. Same requirements as *read1*.

### Rules

0. Resource download and preparation (into `resources/`):
   - GENCODE v48 primary assembly genome and GTF
   - GATK hg38 bundle known sites (dbSNP 138, Mills/1000G indels, known indels)
   - `samtools faidx`, and Picard `CreateSequenceDictionary` with the
     [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/createsequencedictionary.html)
   - STAR genome index with the
     [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/star/index.html)
   - Exon and CDS BEDs from the GTF with [gffread](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/gffread.html) + bedtools
   - Exon calling intervals with Picard `BedToIntervalList`
   - The VEP cache
1. Read trimming with [fastp](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/fastp.html), per lane
2. Two-pass alignment (`--twopassMode Basic`) with STAR using the
   [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/star/align.html).
   All lanes of a sample are aligned together, with one read group per lane.
3. Picard `MarkDuplicates` using the [snakemake wrapper](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/picard/markduplicates.html)
4. GATK `SplitNCigarReads`, then base quality score recalibration (`BaseRecalibrator`, `ApplyBQSR`), using the
   [snakemake wrappers](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/gatk.html)
5. Variant calling with GATK `HaplotypeCaller`, restricted to exons
   (`--dont-use-soft-clipped-bases --standard-min-confidence-threshold-for-calling 20`).
   Then `VariantFiltration` hard filters: `FS > 30.0`, `QD < 2.0`, and SNP clusters of 3 within 35 bp.
6. Coverage with [mosdepth](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/mosdepth.html):
   per-exon depth, plus a quantized track used to build the DeepVariant calling regions
7. Variant calling with DeepVariant `--model_type=RNASEQ` (via singularity) on the MarkDuplicates BAM.
   By default it calls only CDS bases with at least 3x coverage, as in the
   [DeepVariant RNA-seq case study](https://github.com/google/deepvariant/blob/r1.10/docs/deepvariant-rnaseq-case-study.md).
8. Variant calling with `bcftools mpileup` + `call -m`, restricted to exons, on the recalibrated BAM.
   Calls are soft-filtered with `bcftools filter` (`QUAL<20 || INFO/DP<10 || FMT/GQ<20`, SnpGap 3). All
   steps use the [snakemake wrappers](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/bcftools/mpileup.html).
9. `PASS` calls from each caller are normalized with `bcftools norm` (multiallelics split, REF checked)
10. Consensus: sites PASSed by at least 2 of the 3 callers (`bcftools isec`). Genotypes come from the first
    caller with the site, in the order HaplotypeCaller, DeepVariant, bcftools. `INFO/CALLERS` records which
    callers made the call, as a bitmask in that order.
11. Annotation of each caller's PASS set and the consensus with [VEP](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/vep/annotate.html)
12. QC summary with `bcftools stats` and [MultiQC](https://snakemake-wrappers.readthedocs.io/en/stable/wrappers/bio/multiqc.html)

### Outputs (under `results/`)

| Path | Contents |
|---|---|
| `recal/{sample}.bam` | Analysis-ready BAM (split + recalibrated) |
| `markdup/{sample}.bam` | Duplicate-marked STAR BAM (input to DeepVariant) |
| `haplotypecaller/`, `deepvariant/`, `bcftools/` | Raw / filtered per-caller VCFs |
| `pass/{caller}/{sample}.vcf.gz` | Normalized PASS calls per caller |
| `consensus/{sample}.vcf.gz` | Consensus calls |
| `vep/{callset}/{sample}.vcf.gz` | VEP-annotated calls (`callset` is one of the callers or `consensus`) |
| `mosdepth/` | Coverage summaries |
| `multiqc/multiqc_report.html` | QC report |

### Notes

- **Reference.** The GENCODE primary assembly has no ALT/HLA contigs, so STAR doesn't turn reads in
  ALT-homologous regions into multimappers. The GATK known-sites VCFs use the same names and lengths
  for chr1-22/X/Y/M. Known sites on unplaced scaffolds are ignored, because the scaffold names differ.
- **Reusing local copies.** EBI downloads can be slow. To skip them, symlink existing files into
  `resources/` under the names in `config.yaml`, e.g. from `/mnt/data/references/GRCh38/GENCODE/v48/`.
  You can also point `star.index` at an existing index, but only if it was built from the same fasta
  and GTF with STAR 2.7.11b. The `STAR_idx` there was built from the *basic* GTF, not the primary
  assembly GTF used here.
- **STAR and AVX2.** Recent bioconda STAR 2.7.11b builds require AVX2. Our servers' Xeon E5 v2 CPUs
  don't have it, and those builds fail with "Illegal instruction". The STAR rules therefore override
  the wrapper environments with `envs/star.yaml`, which pins an earlier build.
- **MAPQ.** STAR gives uniquely mapped reads MAPQ 255. `SplitNCigarReads` resets that to 60, as
  HaplotypeCaller drops MAPQ 255 reads and bcftools would treat them as MAPQ 20. DeepVariant reads the
  MarkDuplicates BAM directly; its RNA-seq model keeps reads with MAPQ ≥ 40, so 255 passes.
- **Allele-specific expression, RNA editing (e.g. A-to-I) and mapping artifacts** at splice
  junctions all affect RNA-based calls. Treat heterozygous calls in lowly expressed genes, and
  A>G/T>C changes, with caution.
- The consensus threshold, DeepVariant regions (`CDS` or `exon`, minimum coverage, or genome-wide)
  and all filter thresholds are set in `config.yaml`.
