#!/bin/bash

anatomical=/anat/T1w1_denoise.nii.gz
regdir=/anat/newreg
func_ref_all="/func/func_ref.nii.gz"
func_ref_all_in_T1="/func/func_ref_to_anat.nii.gz"
func_ref_all_in_T1_mat="/func/func_ref_to_anat.mat"
anat_ref=/anat/T1w1_denoise_n4.nii.gz
anat_ref_ss=/anat/T1w1_denoise_n4_ss.nii.gz
#                          -v "${session_dir}"/anat:/anat:ro \
#                          -v "${session_dir}"/func:/func:ro \
#                          -v "${derivatives_folder}":/out \
#                          -v "${session_dir}"/fmap:/fmap:ro \

if [ ! -f "${anat_ref_ss}" ]; then
  N4BiasFieldCorrection -d 3 -i "${anatomical}" -o "${anat_ref}" -s 4
  /usr/local/AFNIbin/3dSkullStrip -input "${anat_ref}" -prefix "${anat_ref_ss}" -smooth_final 2 -overwrite
fi

for func_subdir in /func/*/; do
  func_ss_ref="${func_subdir}func_minimal/example_func_brain.nii.gz"
  func_mc="${func_subdir}func_minimal/func_mc.nii.gz"
  to_fref_mat="${func_subdir}to_fref.mat"
  to_fref_vol="${func_subdir}to_fref.nii.gz"
  if [ ! -f "${func_ref_all}" ]; then
    cp "$func_ss_ref" "$func_ref_all"
  fi
  # From func to fref
  flirt -in "$func_ss_ref" -ref "$func_ref_all" -out "${to_fref_vol}" \
              -omat "${to_fref_mat}" -dof 6
done

# From fref to anat
flirt -in "$func_ref_all" -ref "$anat_ref_ss" -out "${func_ref_all_in_T1}" \
            -omat "${func_ref_all_in_T1_mat}" -dof 6