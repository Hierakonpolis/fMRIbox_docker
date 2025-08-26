#!/bin/bash
bids_dir="/media/storage2/EMOATT/BIDS"
final_out_dir=/media/storage3/derivatives/neurobox_MNI_topup
derivatives_folder=${bids_dir}/derivatives/neurobox_topup
max_slots=5
mkdir -p "$derivatives_folder"
mkdir -p "$final_out_dir"
tsp tsp -S $max_slots
# Loop through all subjects
for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir" ]]; then
        subject=$(basename "$subject_dir")

        # Loop through all sessions for the current subject
        for session_dir in "$subject_dir"/ses-*; do
          if [[ -d "$session_dir/func" ]]; then
            session=$(basename "$session_dir")
            prev_job_id=$(tsp docker run  \
                          -v "${session_dir}"/anat:/anat:ro \
                          -v "${session_dir}"/func:/func:ro \
                          -v "${derivatives_folder}":/out \
                          -v "${session_dir}"/fmap:/fmap:ro \
                          --rm neurobox:latest \
                          sequence_level_tasks.sh "$subject" "$session" topup)
            tsp -D $prev_job_id docker run  \
                 -v "${session_dir}"/anat:/anat:ro \
                 -v "${session_dir}"/func:/func:ro \
                 -v "${derivatives_folder}":/out \
                 -v "${session_dir}"/fmap:/fmap:ro \
                 --rm neurobox:latest \
                 prepare_func_to_T1w.sh "$subject" "$session"
          fi
        done
    fi
done

template_job_id=$(tsp -N $max_slots docker run  \
                      -v "${session_dir}"/anat:/anat:ro \
                      -v "${session_dir}"/func:/func:ro \
                      -v "${derivatives_folder}":/out \
                      -v "${session_dir}"/fmap:/fmap:ro \
                      --rm neurobox:latest \
                      make_study_templates.sh)

for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir" ]]; then
        subject=$(basename "$subject_dir")

        # Loop through all sessions for the current subject
        for session_dir in "$subject_dir"/ses-*; do
          if [[ -d "$session_dir/func" ]]; then
            session=$(basename "$session_dir")

            tsp -D $template_job_id docker run   \
                 -v "${session_dir}"/anat:/anat:ro \
                 -v "${session_dir}"/func:/func:ro \
                 -v "${derivatives_folder}":/out \
                 -v "${session_dir}"/fmap:/fmap:ro \
                 -v "${final_out_dir}":/final_out \
                 --rm neurobox:latest \
                 all_to_MNI.sh "$subject" "$session"
          fi
        done
    fi
done
