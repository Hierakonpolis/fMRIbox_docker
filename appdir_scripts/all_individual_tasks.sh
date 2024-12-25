#!/bin/bash
subject=$1
session=$2

mag1_file=$(find /fmap -type f -name "sub-*_ses-*_acq-*_magnitude1.nii.gz")
mag1_file=$(basename "$mag1_file")
mag2_file=$(find /fmap -type f -name "sub-*_ses-*_acq-*_magnitude2.nii.gz")
mag2_file=$(basename "$mag2_file")
phasediff_file=$(find /fmap -type f -name "sub-*_ses-*_acq-*_phasediff.nii.gz")
phasediff_file=$(basename "$phasediff_file")
AP_file=$(find /fmap -type f -name "sub-*_ses-*_acq-*_dir-AP_epi.nii.gz")
AP_file=$(basename "$AP_file")
PA_file=$(find /fmap -type f -name "sub-*_ses-*_acq-*_dir-PA_epi.nii.gz")
PA_file=$(basename "$PA_file")

anat_file=$(find /anat -type f -name "sub-*_ses-*_acq-*_T1w.nii.gz")
anat_file=$(basename "$anat_file")

for func_task in /func/*.nii.gz; do
  func_file=$(basename "$func_task")
  ./one_task_correction.sh -f "${func_file}" -a "${anat_file}"
  ./one_task_correction.sh -f "${func_file}" -a "${anat_file}" -b "${mag1_file}" -c "${mag2_file}" -s "${phasediff_file}"
  ./one_task_correction.sh -f "${func_file}" -a "${anat_file}" -l "${AP_file}" -r "${PA_file}"
  ./all_to_anat.sh "$subject" "$session"
  done
