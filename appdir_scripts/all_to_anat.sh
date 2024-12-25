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
topup_files=($(find "$processedfolder" -type f -name '*topup*'))
fugue_files=($(find "$processedfolder" -type f -name '*fugue*'))
nofc_files=($(find "$processedfolder" -type f ! -name '*topup*' ! -name '*fugue*'))

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

# Step 2: Select one sequence per group to build the functional template
declare -A templates
declare -A template_files
declare -A template_to_t1
for group in "topup_files" "fugue_files" "nofc_files"; do
    selected_file=$(select_highest_acq "${!group}")
    if [[ -n $selected_file ]]; then
        # Create a functional template
#        subject_id=$(basename "$selected_file" | cut -d'_' -f1)  # Adjust as per BIDS format
        subject_id=$subjectID
        template="${outputfolder}/${subject_id}_${sessionID}_${group}_functemplate"
#        template="${outputfolder}/${subject_id}_$(basename "$selected_file" .nii.gz)_template.nii.gz"

        echo "Creating functional template for $selected_file..."
        fslroi "$selected_file" "${outputfolder}/temp_20_30.nii.gz" 20 10
        fslmaths "${outputfolder}/temp_20_30.nii.gz" -Tmean "$template"
        templates[$group]="$template"
        group_string=${group/_files/}
        template_transform="${outputfolder}/${subject_id}_${sessionID}_${group_string}_functemplate_to_T1w"
        flirt -in "$template" -ref "$anat_t1w" -out "${template_transform}.nii.gz" \
              -omat "${template_transform}.mat" -dof 6
        template_to_t1[$group]="$template_transform"

        rm "${outputfolder}/temp_20_30.nii.gz"
    fi
done

# Step 3: Register all sequences in each group to their respective template
declare -A group_transforms
for group in "topup_files" "fugue_files" "nofc_files"; do
    template="${templates[$group]}"
    transform_dir="${outputfolder}/transforms_${group}"
    mkdir -p "$transform_dir"
    group_transforms[$group]="$transform_dir"

    for file in "${!group}"; do
        echo "Registering $file to template $template..."
        file_ref="${coregdir}/$(basename "$file")"
        fslroi "$file" "$file_ref" 20 1
        flirt -in "$file_ref" -ref "$template" -out "${transform_dir}/$(basename "$file" .nii.gz)_registered.nii.gz" \
              -omat "${transform_dir}/$(basename "$file" .nii.gz)_to_template.mat" -dof 6
    done
done

# Step 4: Combine transformations for direct interpolation to T1w space
declare -A composite_transforms
for group in "topup_files" "fugue_files" "nofc_files"; do
    template_transform="${template_to_t1[$group]}"
    transform_dir="${group_transforms[$group]}"

    echo "Creating composite transform for $group..."
    for file in "${!group}"; do
        template_mat="${transform_dir}/$(basename "$file" .nii.gz)_to_template.mat"
        composite_mat="${transform_dir}/$(basename "$file" .nii.gz)_to_T1w_composite.mat"

        convert_xfm -omat "$composite_mat" -concat "$template_transform" "$template_mat"
        composite_transforms[$file]="$composite_mat"
    done
done

# Step 5: Apply composite transforms to interpolate directly to T1w space
for group in "topup_files" "fugue_files" "nofc_files"; do
    for file in "${!group}"; do
        composite_mat="${composite_transforms[$file]}"
        output="${processedfolder}/$(basename "$file" .nii.gz)_space-T1w.nii.gz"
#        output="${outputfolder}/$(basename "$file" .nii.gz)_final_interpolated.nii.gz"

        echo "Applying composite transform directly to T1w space for $file..."
        apply_transform_to_timeseries "$file" "$anat_t1w" "$composite_mat" "$output"
    done
done
