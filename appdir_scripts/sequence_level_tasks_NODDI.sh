#!/bin/bash
subject=$1

anat_file=$(basename "$(find /anat -name "*_fl3D_t1_sag_fun_defaced.nii.gz" -type f)")
func_file="EPI_fixed.nii.gz"

./one_task_correction.sh -f "${func_file}" -a "${anat_file}" -p "${subject}" \
    -t /stfile/slice_timing_interleaved_ascending_even.txt
