import pandas as pd


configfile: "config/config.yaml"

WORK_DIR = "results"
FASTP_OUT = f"{WORK_DIR}/fastp"
BWA_OUT = f"{WORK_DIR}/bwa"
MERGE_OUT = f"{WORK_DIR}/merge"
MARKDUP_OUT = f"{WORK_DIR}/markdup"
VARSCAN_OUT = f"{WORK_DIR}/varscan"
MUSE_OUT = f"{WORK_DIR}/muse"
PILEUP_SUMMARY_OUT = f"{WORK_DIR}/pileup_summary"
CONTAM_OUT = f"{WORK_DIR}/contam"
MUTECT_OUT = f"{WORK_DIR}/mutect2"
CONSENSUS_OUT = f"{WORK_DIR}/isec"
ANNOTATED_OUT = f"{WORK_DIR}/annotated"
CNVKIT_OUT = f"{WORK_DIR}/cnvkit"
MOSDEPTH_OUT = f"{WORK_DIR}/mosdepth"
DEEPSOMATIC_OUT = f"{WORK_DIR}/deepsomatic"
STRELKA_OUT = f"{WORK_DIR}/strelka"

# Define samples and experimental units
SAMPLES = pd.read_csv("samples.csv", sep=",", header=0)
UNITS = SAMPLES["PU"].tolist()

# Extract the PUs that need to be merged into single sample BAMs
PU_BY_SAMPLE = SAMPLES.groupby('SM')['PU'].agg(list).to_dict()

def get_replicates_for_merge(wildcards):
    units = PU_BY_SAMPLE[wildcards.sample]
    return [f"{BWA_OUT}/{u}.sorted.bam" for u in units]


# Extract a dictionary of tumor-normal pairs and single samples
PAIRED_SAMPLES = {}
SINGLE_SAMPLES = {}
for sample_name, group in SAMPLES.groupby("sample_name"):
    sample_id = str(sample_name)
    tumor_sms = group[group["tumor_normal"] == "tumor"]["SM"].unique()
    normal_sms = group[group["tumor_normal"] == "normal"]["SM"].unique()
    
    if len(tumor_sms) > 0:
        tumor_sm = tumor_sms[0]
        if len(normal_sms) > 0:
            normal_sm = normal_sms[0]
            PAIRED_SAMPLES[sample_id] = {"tumor": tumor_sm, "normal": normal_sm}
        else:
            SINGLE_SAMPLES[sample_id] = {"tumor": tumor_sm}