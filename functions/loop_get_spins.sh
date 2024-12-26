#!/bin/bash

nifti_file=$1
outfile=$2


num_volumes=$(fslinfo "$nifti_file" | grep "^dim4" | awk '{print $2}')
echo "Number of volumes: $num_volumes"

for i in $(seq 1 $num_volumes); do
    /app/functions/get_params_spin.sh "$nifti_file" >> "$outfile"
done
