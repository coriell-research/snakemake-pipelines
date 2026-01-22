## WES Somatic Variant Calling Pipeline (Paired-end)

**This pipeline is currently a work in progress**. 

The Snakemake pipeline follows GATK best practices for [Somatic Variant Calling](https://gatk.broadinstitute.org/hc/en-us/articles/360035894731-Somatic-short-variant-discovery-SNVs-Indels) with 
one exception, **BQSR step is skipped**. After GATK pre-processing has been performed, somatic 
variant calling is performed using MUsE2, VarScan2, and Mutect2 on tumor-normal pairs. 

## Set up

A 'samples.csv' file must be specified in order to run the pipeline. It is assumed that sequencing 
runs have been performed as paired-end. To create the 'samples.csv' file, a separate column must be 
created specifying the [read group](https://gatk.broadinstitute.org/hc/en-us/articles/360035890671-Read-groups) 
flags for each sequencing run. The required read group flags are as follows:

- **ID** : This tag identifies which read group each read belongs to, so each read group's ID 
must be unique. It is referenced both in the read group definition line in the file header 
(starting with @RG) and in the RG:Z tag for each read record. Note that some Picard tools have the 
ability to modify IDs when merging SAM files in order to avoid collisions. In Illumina data, read 
group IDs are composed using the flowcell name and lane number, making them a globally unique 
identifier across all sequencing data in the world. Use for BQSR: ID is the lowest denominator 
that differentiates factors contributing to technical batch effects: therefore, a read group is 
effectively treated as a separate run of the instrument in data processing steps such as base 
quality score recalibration (unless you have PU defined), since they are assumed to share the 
same error model.
- **PU**: The PU holds three types of information, the {FLOWCELL_BARCODE}.{LANE}.{SAMPLE_BARCODE}. 
The {FLOWCELL_BARCODE} refers to the unique identifier for a particular flow cell. The {LANE} 
indicates the lane of the flow cell and the {SAMPLE_BARCODE} is a sample/library-specific identifier. 
Although the PU is not required by GATK but takes precedence over ID for base recalibration if it 
is present.
- **SM** : The name of the sample sequenced in this read group. GATK tools treat all read groups 
with the same SM value as containing sequencing data for the same sample, and this is also the 
name that will be used for the sample column in the VCF file. Therefore it is critical that the 
SM field be specified correctly. When sequencing pools of samples, use a pool name instead of an 
individual sample name. 
- **PL** : This constitutes the only way to know what sequencing technology was used to generate 
the sequencing data. Valid values: ILLUMINA, SOLID, LS454, HELICOS and PACBIO.
- **LB** : MarkDuplicates uses the LB field to determine which read groups might contain molecular 
duplicates, in case the same DNA library was sequenced on multiple lanes.

In addition to the read group flags above, additional columns are needed specifying the 
absolute file paths to each sequencing run, named **read1** and **read2**, respectively, as well as
for the patient/sampling unit (**sample_name**) and whether or not the sample is from a tumor or 
normal (**tumor_normal**)

A final formatted samples.csv file should have the following format:

sample_name | tumor_normal | read1 | read2 | ID | PU | SM | PL | LB
------------|--------------|-------|-------|----|----|----|----|----
52171 | normal | DNA_WB_52171_CKDN250007070-1A_22JC23LT4_L3_1.fq.gz | DNA_WB_52171_CKDN250007070-1A_22JC23LT4_L3_2.fq.gz | 22JC23LT4.L3 | DNA_WB_52171_CKDN250007070-1A_22JC23LT4_L3 | 52171_normal | ILLUMINA | CKDN250007070-1A
52171 | tunor | DNACCRL52171_CKDN250007064-1A_22JC23LT4_L3_1.fq.gz | DNACCRL52171_CKDN250007064-1A_22JC23LT4_L3_2.fq.gz | 22JC23LT4.L3 | DNACCRL52171_CKDN250007064-1A_22JC23LT4_L3 | 52171_tumor | ILLUMINA | CKDN250007064-1A

NOTE: multiple sequencing runs are supported and may simply be listed as additional rows. See the example "samples.csv" file for a full, working example.

## Running the pipeline

1. Clone Snakefile and config.yaml into working directory and create a samples.csv file as specified
above.
2. Activate the `snakemake` environment: `mamba activate snakemake`
3. Run using `snakemake --cores 8 --use-conda`
