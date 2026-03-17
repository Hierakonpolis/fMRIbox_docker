preproc_dir=/mnt/data0/natview/preproc_data

tsp -S 30
for subject_dir in "${preproc_dir}"/sub-*/; do
  for session_dir in "${subject_dir}"ses-*/; do
    for run_dir in "${session_dir}"func/*/; do
      run_name=$(basename "${run_dir}")

      tsp docker run \
        -v "${session_dir}anat":/anat \
        -v "${session_dir}func":/func \
        --rm neurobox:latest \
        NATVIEW_minimal_sess.sh "${run_name}"

    done
  done
done