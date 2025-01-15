#!/bin/bash

#  Print commands and their arguments as they are executed.
set -x
# ./all_to_MNI.sh sub-024 ses-day3
mni_template=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz
mni_template_2mm=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz
t1_template=/out/template/T1w_bc_template.nii.gz
subfolder=$1
sesfolder=$2
filter_str=$3
anat_t1w=($(find "/out/${subfolder}/${sesfolder}/anat" -type f -name '*_bc.nii.gz'))
processedfolder="/out/${subfolder}/${sesfolder}/processed" # change this for final output paths
output_folder="/final_out/${subfolder}/${sesfolder}/processed"
coregdir="/out/${subfolder}/${sesfolder}/coregistration"
transform_dir="/out/${subfolder}/${sesfolder}/space-anat/transforms"
template_transforms_dir=/out/template/template_transforms
template_transform_prefix="$template_transforms_dir/${subfolder}_${sesfolder}_to_template"
mkdir -p "$transform_dir"

# Step 1: Categorize files into lists
#files=($(find "$processedfolder" -type f -name '*.nii.gz'))
if [[ -n "$filter_str" ]]; then
    files=($(find "$processedfolder" -type f -name '*.nii.gz' -name "*$filter_str*"))
else
    files=($(find "$processedfolder" -type f -name '*.nii.gz'))
fi

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


# Step 2: Register all sequences in each group to T1w
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
#         applywarp -i "$vol" -r "$mni_template" -o "$vol" -w "$transform"
          if ! applywarp -i "$vol" -r "$mni_template" -o "$vol" -w "$transform"; then
            echo "Error: applywarp failed for $vol" >&2
            exit 1
          fi
          flirt -in "$vol" -ref "${mni_template_2mm}" -applyxfm -usesqform -out "$vol"

    done

    echo "Merging transformed volumes back into 4D timeseries..."
    fslmerge -t "$output_4d" "$temp_dir"/vol_*.nii.gz

    echo "Cleaning up temporary files..."
    rm -r "$temp_dir"
}

mkdir -p "$output_folder"
mkdir -p "$template_transforms_dir"

if [ ! -f "${template_transform_prefix}_warpfield.nii.gz" ];
then
  flirt -in $anat_t1w -ref "$t1_template" -out "${template_transform_prefix}_affine.nii.gz" -omat "${template_transform_prefix}_affine.mat"
  fnirt -v --ref="$t1_template" --in="${template_transform_prefix}_affine.nii.gz" --fout="${template_transform_prefix}_warpfield.nii.gz" --iout="${template_transform_prefix}_warped.nii.gz"
fi
for file in ${files[@]}; do
    output="${output_folder}/$(basename "$file" .nii.gz)_space-MNI.nii.gz"
    echo "Source"
    echo "$file"
    echo "Dest"

      echo "Registering $file..."
      file_ref="${coregdir}/$(basename "$file")"
      transform_file="${transform_dir}/$(basename "$file" .nii.gz)_to_T1w.mat"

      if [ ! -f "$transform_file" ];
      then
      fslroi "$file" "$file_ref" 20 1
      flirt -in "$file_ref" -ref "$anat_t1w" -out "${transform_dir}/$(basename "$file" .nii.gz)_template_space-T1w.nii.gz" \
            -omat "$transform_file" -dof 6
      fi

      full_transform_file="${transform_dir}/$(basename "$file" .nii.gz)_to_MNI.nii.gz"
      full_transform_inverse="${transform_dir}/MNI_to_$(basename "$file" .nii.gz).nii.gz"
      pre_affine_file="${transform_dir}/$(basename "$file" .nii.gz)_to_T1template_affine.mat"
      if [ ! -f "$output" ];
      then
      convert_xfm -omat "$pre_affine_file" -concat "${template_transform_prefix}_affine.mat" "${transform_file}"
      convertwarp -r "${mni_template}" -o "${full_transform_file}" -m "$pre_affine_file" -w "${template_transform_prefix}_warpfield.nii.gz" --midmat=/out/template/T1wRef_to_MNI1mm_affine.mat --warp2=/out/template/T1wRef_to_MNI1mm_warpfield.nii.gz
      invwarp -w "${full_transform_file}" -o "${full_transform_inverse}" -r "$file"
      apply_transform_to_timeseries "$file" "${mni_template}" "$full_transform_file" "$output"

      fi
done

