#!/bin/bash
#SBATCH --job-name=macs2_homer
#SBATCH --output=macs2_homer_%j.log
#SBATCH --error=macs2_homer_%j.err
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G
#SBATCH --time=24:00:00

set -euo pipefail

# Activate conda env (edit if needed)
source ~/.bashrc 2>/dev/null || true
if [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
  source "$HOME/miniconda3/etc/profile.d/conda.sh"
fi
conda activate atac || true

ROOT="/.../path_to_files/bioinformatics/ATAC-Seq/ATAC-sequences"
BAMDIR="${ROOT}/alignments_bowtie2_single"
MACS2_DIR="${ROOT}/macs2_out"
HOMER_ANNOT_DIR="${ROOT}/homer_annot"
QCOUT="${MACS2_DIR}/qc"
mkdir -p "$MACS2_DIR" "$HOMER_ANNOT_DIR" "$QCOUT"

GENOME="hs"         # MACS2 genome
HOMER_GENOME="hg38" # HOMER genome name
QVAL=0.01
KEEP_DUP="all"

module purge 2>/dev/null || true
module load homer/4.11.1 2>/dev/null || true

for bam in "${BAMDIR}"/SRR*_sorted_filtered_sambamba.bam; do
  [[ -f "$bam" ]] || continue
  base=$(basename "$bam" _sorted_filtered_sambamba.bam)
  outdir="${MACS2_DIR}/${base}"
  mkdir -p "$outdir"

  echo "=== MACS2 callpeak for ${base} ==="
  macs2 callpeak \
    -t "$bam" \
    -f BAMPE \
    -g "$GENOME" \
    -n "${base}_ATAC" \
    --outdir "$outdir" \
    -q "$QVAL" \
    --nomodel \
    --keep-dup "$KEEP_DUP" \
    --call-summits

  echo "MACS2 finished for ${base}."

  # FRiP
  peaks="${outdir}/${base}_ATAC_peaks.narrowPeak"
  if [[ -f "$peaks" ]]; then
    total_mapped=$(samtools view -c -F 4 "$bam")
    in_peaks=$(bedtools intersect -u -abam "$bam" -b "$peaks" | samtools view -c)
    if [[ "$total_mapped" -gt 0 ]]; then
      frip=$(awk -v a="$in_peaks" -v b="$total_mapped" 'BEGIN{printf "%.6f", (b? a/b : 0)}')
    else
      frip="NA"
    fi
    echo -e "${base}\t${total_mapped}\t${in_peaks}\t${frip}" >> "${QCOUT}/frip_summary.tsv"
  else
    echo "WARN: No peaks for ${base}; skipping FRiP" >&2
  fi

  # HOMER annotate and motifs
  if [[ -f "$peaks" ]]; then
    homer_out="${HOMER_ANNOT_DIR}/${base}"
    mkdir -p "$homer_out/annotation" "$homer_out/motifs"
    annotatePeaks.pl "$peaks" "$HOMER_GENOME" > "${homer_out}/annotation/${base}.annotatePeaks.txt"
    summits="${outdir}/${base}_ATAC_summits.bed"
    if [[ -f "$summits" ]]; then
      summit_window_bed="${outdir}/${base}_summits_200bp.bed"
      awk '{s=int(($2+$3)/2); st=(s-100<0?0:s-100); en=s+100; print $1"\t"st"\t"en}' "$summits" > "$summit_window_bed"
      findMotifsGenome.pl "$summit_window_bed" "$HOMER_GENOME" "${homer_out}/motifs" -size given -len 8,10,12
    fi
  fi

done

echo "Pipeline finished."