#!/usr/bin/env bash
set -euo pipefail

# Root placeholder (update to your environment)
ROOT="/.../path_to_files/bioinformatics/ATAC-Seq/ATAC-sequences"
REF="${ROOT}/RG_GRCh38/GRCh38_p14"          # bowtie2 index basename
TRIMDIR="${ROOT}/trimmed"                   # input FASTQs
OUTDIR="${ROOT}/alignments_bowtie2_single"  # output dir
THREADS="${SLURM_CPUS_PER_TASK:-4}"
SAMTOOLS_SORT_MEM="3G"

mkdir -p "${OUTDIR}" "${OUTDIR}/tmp"

echo "Aligning all *_1.trim_tg.fastq.gz in ${TRIMDIR} with Bowtie2 -> sorted BAMs in ${OUTDIR}"

for R1 in "${TRIMDIR}"/*_1.trim_tg.fastq.gz; do
  [[ -e "$R1" ]] || continue
  base=$(basename "$R1" "_1.trim_tg.fastq.gz")
  R2="${TRIMDIR}/${base}_2.trim_tg.fastq.gz"
  SORTED="${OUTDIR}/${base}_sorted.bam"
  [[ -f "$SORTED" ]] && { echo "Skipping ${base} (exists)"; continue; }

  echo "Aligning ${base}..."
  bowtie2 --no-unal -p "$THREADS" -x "$REF" -1 "$R1" -2 "$R2" \
    | samtools view -@ "$THREADS" -b - \
    | samtools sort -@ "$THREADS" -m "$SAMTOOLS_SORT_MEM" -o "$SORTED" -
  echo "Done ${SORTED}"
done

echo "All alignments complete."