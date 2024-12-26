#!/bin/bash

#  Print commands and their arguments as they are executed.
set -x
# ./all_to_anat.sh sub-024 ses-day3
subfolder=$1
sesfolder=$2
anat_t1w=($(find "/out/${subfolder}/${sesfolder}/anat" -type f -name '*_bc.nii.gz'))
processedfolder="/out/${subfolder}/${sesfolder}/processed"
coregdir="/out/${subfolder}/${sesfolder}/coregistration"
outputfolder="/out/${subfolder}/${sesfolder}/space-anat"
mkdir -p "$outputfolder"

subjectID=$(echo "$subfolder" | grep -oP "sub-[^_]+")
sessionID=$(echo "$sesfolder" | grep -oP "ses-[^_]+")

# Step 1: Categorize files into lists
files=($(find "$processedfolder" -type f -name '*.nii.gz'))

# Function to find the file with the highest acq value
select_highest_acq() {
    local files=("$@")
    local max_acq_file=""
    local max_acq=0

    for file in "${files[@]}"; do
        if [[ $file =~ acq-([0-9]+) ]]; then
            acq_val=${BASH_REMATCH[1]}
            if ((acq_val > max_acq)); then
                max_acq=$acq_val
                max_acq_file=$file
            fi
        fi
    done

    echo "$max_acq_file"
}

apply_transform_to_timeseries() {
    local input_4d="$1"
    local ref="$2"
    local transform="$3"
    local output_4d="$4"
    local temp_dir=$(mktemp -d)

    echo "Splitting $input_4d into 3D volumes..."
    fslsplit "$input_4d" "$temp_dir/vol_" -t

    echo "Applying transform to each volume..."
    for vol in "$temp_dir"/vol_*.nii.gz; do
        flirt -in "$vol" -ref "$ref" -applyxfm -init "$transform" -out "$vol"
    done

    echo "Merging transformed volumes back into 4D timeseries..."
    fslmerge -t "$output_4d" "$temp_dir"/vol_*.nii.gz

    echo "Cleaning up temporary files..."
    rm -r "$temp_dir"
}


# Step 2: Register all sequences in each group to T1w
#declare -A group_transforms

transform_dir="${outputfolder}/transforms"
mkdir -p "$transform_dir"


for file in ${files[@]}; do
    output="${processedfolder}/$(basename "$file" .nii.gz)_space-T1w.nii.gz"
    echo "Source"
    echo "$file"
    echo "Dest"
    echo "$output"
    if [ ! -f "$output" ];
    then

      echo "Registering $file..."
      file_ref="${coregdir}/$(basename "$file")"
      fslroi "$file" "$file_ref" 20 1
      transform_file="${transform_dir}/$(basename "$file" .nii.gz)_to_T1w.mat"
      flirt -in "$file_ref" -ref "$anat_t1w" -out "${transform_dir}/$(basename "$file" .nii.gz)_template_space-T1w.nii.gz" \
            -omat "$transform_file" -dof 6
      apply_transform_to_timeseries "$file" "$anat_t1w" "$transform_file" "$output"
    fi

done
