#!/bin/bash
subject=$1

anat_file=$(find /anat -type f -name "sub-*_T1w.nii.gz")
anat_file=$(basename "$anat_file")

for func_task in /func/*.nii.gz; do
  func_file=$(basename "$func_task")
  ./one_task_correction.sh -f "${func_file}" -a "${anat_file}" -t /stfile/slice_order.txt
done
