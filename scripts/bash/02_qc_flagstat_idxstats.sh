#!/usr/bin/env bash
set -euo pipefail

ROOT="/.../path_to_files/bioinformatics/ATAC-Seq/ATAC-sequences"
BAMDIR="${ROOT}/alignments_bowtie2_single"
QCOUT="${BAMDIR}/qc_reports"
mkdir -p "$QCOUT"

out="${QCOUT}/combined_mapping_summary.tsv"
echo -e "Sample\tTotal_in_BAM\tMapped_in_BAM\tProperlyPaired\tDuplicates\tSingletons\tMTreads\tMTfrac" > "$out"

shopt -s nullglob
for bam in "${BAMDIR}"/SRR*_sorted_filtered_sambamba.bam; do
  base=$(basename "$bam" _sorted_filtered_sambamba.bam)

  # ensure index
  [[ -f "${bam}.bai" || -f "${bam%.bam}.bai" ]] || samtools index -@ 4 "$bam"

  fs="${QCOUT}/${base}.flagstat.txt"
  [[ -f "$fs" ]] || samtools flagstat -@ 4 "$bam" > "$fs"

  total_in_bam=$(awk '/in total/ {print $1; exit}' "$fs")
  mapped_in_bam=$(awk '/mapped \(/ {print $1; exit}' "$fs")
  properly_paired=$(awk '/properly paired/ {print $1; exit}' "$fs")
  duplicates=$(awk '/duplicates/ {print $1; exit}' "$fs")
  singletons=$(awk '/singletons/ {print $1; exit}' "$fs")

  idx="${QCOUT}/${base}.idxstats.tsv"
  samtools idxstats "$bam" > "$idx"

  total_idx=$(awk '{sum+=$3}END{print sum+0}' "$idx")
  mt=$(awk '($1=="MT"||$1=="chrM"||$1=="NC_012920.1"){sum+=$3}END{print sum+0}' "$idx")
  if [[ "$total_idx" -gt 0 ]]; then
    mtfrac=$(awk -v m=$mt -v t=$total_idx 'BEGIN{printf "%.6f", (t? m/t : 0)}')
  else
    mtfrac="NA"
  fi

  echo -e "${base}\t${total_in_bam}\t${mapped_in_bam}\t${properly_paired}\t${duplicates}\t${singletons}\t${mt}\t${mtfrac}" >> "$out"
done

echo "Wrote summary to: $out"