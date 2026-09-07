#!/usr/bin/env bash
set -euo pipefail

# Root placeholder (update to your environment)
ROOT="/.../path_to_files/bioinformatics/ATAC-Seq/ATAC-sequences"
ALIGN_DIR="${ROOT}/alignments_bowtie2_single"
THREADS="${SLURM_CPUS_PER_TASK:-8}"

cd "$ALIGN_DIR"

for bam in *_sorted.bam; do
  [[ -e "$bam" ]] || continue
  prefix="${bam%_sorted.bam}"
  outbam="${prefix}_sorted_filtered_sambamba.bam"
  [[ -f "$outbam" ]] && { echo "$outbam exists, skipping."; continue; }

  echo "Filtering $bam ..."
  sambamba view \
    -h \
    -f bam \
    -F "[XS] == null and not unmapped and not duplicate and mapping_quality >= 30" \
    -t "$THREADS" \
    "$bam" \
    -o "$outbam"
  echo "Done $outbam"

done

# Optional: exclude mtDNA reads (uncomment to enable)
# for fbam in *_sorted_filtered_sambamba.bam; do
#   echo "Excluding mtDNA from $fbam ..."
#   samtools idxstats "$fbam" | cut -f1 \
#     | grep -v -E 'NC_012920.1|chrM|MT' \
#     | xargs samtools view -b "$fbam" > "${fbam%.bam}_noMT.bam"
# done

echo "All filtering jobs completed."