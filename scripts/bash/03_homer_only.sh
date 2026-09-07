#!/usr/bin/env bash
set -euo pipefail

ROOT="/.../path_to_files/bioinformatics/ATAC-Seq/ATAC-sequences"
SAMPLE="${1:-SRR13959143}"
MACS2_OUT="${ROOT}/macs2_out/${SAMPLE}"
HOMER_OUTDIR="${ROOT}/homer_annot/${SAMPLE}"
HOMER_GENOME="hg38"

module purge 2>/dev/null || true
module load homer/4.11.1 2>/dev/null || true

mkdir -p "$HOMER_OUTDIR/annotation" "$HOMER_OUTDIR/motifs"

PEAKS="${MACS2_OUT}/${SAMPLE}_ATAC_peaks.narrowPeak"
SUMMITS="${MACS2_OUT}/${SAMPLE}_ATAC_summits.bed"

[[ -f "$PEAKS" ]] || { echo "Peaks not found: $PEAKS"; exit 1; }
annotatePeaks.pl "$PEAKS" "$HOMER_GENOME" > "${HOMER_OUTDIR}/annotation/${SAMPLE}.annotatePeaks.txt"

[[ -f "$SUMMITS" ]] || { echo "Summits not found: $SUMMITS"; exit 1; }
summit_window_bed="${MACS2_OUT}/${SAMPLE}_summits_200bp.bed"
awk '{s=int(($2+$3)/2); st=(s-100<0?0:s-100); en=s+100; print $1"\t"st"\t"en}' "$SUMMITS" > "$summit_window_bed"
findMotifsGenome.pl "$summit_window_bed" "$HOMER_GENOME" "${HOMER_OUTDIR}/motifs" -size given -len 8,10,12

echo "HOMER annotation + motifs completed for ${SAMPLE}"