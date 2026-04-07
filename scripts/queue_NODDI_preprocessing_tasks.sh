#!/bin/bash
data_dir="/mnt/data0/NODDI/fMRI"
derivatives_folder="/mnt/data0/NODDI/derivatives/neurobox_NODDI"
final_out_dir="/mnt/data0/NODDI/derivatives/neurobox_MNI_NODDI"
stfile_dir="/mnt/data0/NODDI/derivatives"
max_slots=20
prev_slots=$(tsp -S)

mkdir -p "$derivatives_folder"
mkdir -p "$final_out_dir"
tsp -S $max_slots

for subject_dir in "$data_dir"/*/; do
    subject=$(basename "$subject_dir")

    # Phase 0: Fix EPI header — writes EPI_fixed.nii.gz into subject directory
    epi_file=$(basename "$(find "${subject_dir}" -name "*_nw_mepi_rest_with_cross.nii.gz" -type f)")
    fix_job_id=$(tsp docker run \
                     -v "${subject_dir}":/subj \
                     --rm neurobox:latest \
                     python3 /app/NODDI_fix_EPI.py \
                     "/subj/${epi_file}" \
                     /subj/EPI_fixed.nii.gz)

    # Phase 1: Sequence-level preprocessing (skull strip, despike, slice timing, moco)
    prev_job_id=$(tsp -D $fix_job_id docker run \
                          -v "${subject_dir}":/anat:ro \
                          -v "${subject_dir}":/func:ro \
                          -v "${derivatives_folder}":/out \
                          -v "${stfile_dir}":/stfile:ro \
                          --rm neurobox:latest \
                          sequence_level_tasks_NODDI.sh "$subject")

    # Phase 2: Functional-to-T1w registration (depends on phase 1)
    tsp -D $prev_job_id docker run \
             -v "${subject_dir}":/anat:ro \
             -v "${subject_dir}":/func:ro \
             -v "${derivatives_folder}":/out \
             --rm neurobox:latest \
             prepare_func_to_T1w.sh "$subject" ""
done

# Phase 3: Build study template (waits for all subjects to finish)
template_job_id=$(tsp -N $max_slots docker run \
                      -v "${derivatives_folder}":/out \
                      --rm neurobox:latest \
                      make_study_templates_NODDI.sh)

# Phase 4: Warp to MNI 2mm (depends on template)
for subject_dir in "$data_dir"/*/; do
    subject=$(basename "$subject_dir")
    tsp -D $template_job_id docker run \
             -v "${subject_dir}":/anat:ro \
             -v "${subject_dir}":/func:ro \
             -v "${derivatives_folder}":/out \
             -v "${final_out_dir}":/final_out \
             --rm neurobox:latest \
             all_to_MNI.sh "$subject" ""
done
tsp -N $max_slots tsp -S $prev_slots
