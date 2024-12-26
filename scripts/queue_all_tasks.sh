#!/bin/bash
bids_dir="/media/storage2/EMOATT/BIDS"
derivatives_folder=${bids_dir}/derivatives/neurobox
mkdir -p "$derivatives_folder"

# Loop through all subjects
for subject_dir in "$bids_dir"/sub-*; do
    if [[ -d "$subject_dir" ]]; then
        subject=$(basename "$subject_dir")

        # Loop through all sessions for the current subject
        for session_dir in "$subject_dir"/ses-*; do
          if [[ -d "$session_dir/func" ]]; then
            session=$(basename "$session_dir")
            tsp docker run -v "${session_dir}"/anat:/anat:ro \
                           -v "${session_dir}"/func:/func:ro \
                           -v "${derivatives_folder}":/out \
                           -v "${session_dir}"/fmap:/fmap:ro \
                           --rm fmribox:latest \
                           all_individual_tasks.sh "$subject" "$session"
          fi
        done
    fi
done

#tsp -N "$slots" docker run -v "${derivatives_folder}":/out \
#                           --rm fmribox:latest \
#                           make_study_templates.sh
