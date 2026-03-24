#!/bin/bash
bids_dir="/mnt/data0/Oddball/ds000116_R2.0.0/uncompressed"
supplementary_dir="/mnt/data0/Oddball/ds000116_R1.0.0/uncompressed/supplementary"
derivatives_folder="/mnt/data0/Oddball/derivatives/neurobox_Oddball"
final_out_dir="/mnt/data0/Oddball/derivatives/neurobox_MNI_Oddball"
max_slots=20
mkdir -p "$derivatives_folder"
mkdir -p "$final_out_dir"
tsp tsp -S $max_slots

for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir/func" ]]; then
        subject=$(basename "$subject_dir")
        prev_job_id=$(tsp docker run \
                          -v "${subject_dir}/anat":/anat:ro \
                          -v "${subject_dir}/func":/func:ro \
                          -v "${derivatives_folder}":/out \
                          -v "${supplementary_dir}":/stfile:ro \
                          --rm neurobox:latest \
                          sequence_level_tasks_Oddball.sh "$subject")
        tsp -D $prev_job_id docker run \
                 -v "${subject_dir}/anat":/anat:ro \
                 -v "${subject_dir}/func":/func:ro \
                 -v "${derivatives_folder}":/out \
                 --rm neurobox:latest \
                 prepare_func_to_T1w.sh "$subject" ""
    fi
done

template_job_id=$(tsp -N $max_slots docker run \
                      -v "${derivatives_folder}":/out \
                      --rm neurobox:latest \
                      make_study_templates_Oddball.sh)

for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir/func" ]]; then
        subject=$(basename "$subject_dir")
        tsp -D $template_job_id docker run \
                 -v "${subject_dir}/anat":/anat:ro \
                 -v "${subject_dir}/func":/func:ro \
                 -v "${derivatives_folder}":/out \
                 -v "${final_out_dir}":/final_out \
                 --rm neurobox:latest \
                 all_to_MNI.sh "$subject" ""
    fi
done
