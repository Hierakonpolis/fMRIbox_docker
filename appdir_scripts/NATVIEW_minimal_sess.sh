#!/bin/bash

mni_template_2mm=$FSLDIR/data/standard/MNI152_T1_2mm.nii.gz

func_subdir="/func/${1}/"
func_to_anat_mat="${func_subdir}func_reg/example_func2highres.mat"
func_ref="${func_subdir}func_minimal/func_mc.nii.gz"
func_to_mni="${func_subdir}func_minimal/func_mc_to_mni.nii.gz"

applywarp --interp=spline --ref="${mni_template_2mm}" --in="${func_ref}" --out="$func_to_mni" --warp=/anat/reg/highres2standard_warp --premat="${func_to_anat_mat}"
