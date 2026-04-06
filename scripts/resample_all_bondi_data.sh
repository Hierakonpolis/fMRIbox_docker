#!/bin/bash

fmri_dir=/mnt/data0/Bondi/preprocessed_fmri
dir_2mm=${fmri_dir}/2mm
mkdir -p "$dir_2mm"

max_slots=20
prev_slots=$(tsp -S)

tsp -S $max_slots

for scan in "${fmri_dir}"/*.nii; do
  scan_name=$(basename "$scan")
  out_name="${scan_name%.nii}_2mm.nii.gz"

      tsp docker run \
        -v "${dir_2mm}":/out \
        -v "${fmri_dir}":/func \
        --rm neurobox:latest \
        flirt \
          -in "/func/${scan_name}" \
          -ref "/opt/fsl/data/standard/MNI152_T1_2mm.nii.gz" \
          -out "/out/${out_name}" \
          -applyxfm \
          -usesqform
done

tsp tsp -S $prev_slots
