#!/bin/bash
bids_dir="/path/to/bids_dataset"
derivatives_folder=${bids_dir}/derivatives/neurobox
mkdir -p "$derivatives_folder"
slots=$(nproc)
tsp -S "$slots"

# Loop through all subjects
for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir" ]]; then
        subject=$(basename "$subject_dir")

        # Loop through all sessions for the current subject
        for session_dir in "$subject_dir"/ses-*; do
            session=$(basename "$session_dir")
            tsp docker run -v "${session_dir}"/anat:/anat:ro \
                           -v "${session_dir}"/func:/func:ro \
                           -v "${derivatives_folder}":/out \
                           -v "${session_dir}"/fmap:/fmap:ro \
                           --rm fmribox:latest \
                           all_individual_tasks.sh "$subject" "$session"

        done
    fi
done

tsp -N "$slots" docker run -v "${derivatives_folder}":/out \
                           --rm fmribox:latest \
                           make_study_templates.sh