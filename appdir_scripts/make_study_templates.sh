#!/bin/bash

mni_template=$FSLDIR/data/standard/MNI152_T1_1mm.nii.gz
t1_template=/out/template/T1w_bc_template.nii.gz
mkdir -p /out/template/bc
if [ ! -f "${t1_template}" ];
then
cd /out/template/bc
ln /out/sub-*/ses-*/anat/sub-*_ses-*_acq-*_bc.nii.gz .
buildtemplateparallel.sh -c 2 -j $(nproc) -n 0 -r 1 -d 3 -o T1w_bc_ sub-*_ses-*_acq-*_bc.nii.gz
rm sub-*_ses-*_acq-*_bc.nii.gz
cp T1w_bc_template.nii.gz ${t1_template}
fi
cd /out/template/

if [ ! -f T1wRef_to_MNI1mm.nii.gz ];
then
  echo "Running FLIRT"
  flirt -v -in T1w_bc_template.nii.gz -ref "$mni_template" -out T1wRef_to_MNI1mm_affine.nii.gz -omat T1wRef_to_MNI1mm_affine.mat
  echo "RUNNING FNIRT"
  fnirt -v --ref="$mni_template" --in=T1wRef_to_MNI1mm_affine.nii.gz --fout=T1wRef_to_MNI1mm_warpfield.nii.gz
  echo "APPLYING WARP TO MNI SPACE"
  applywarp -v -i T1w_bc_template.nii.gz -r "$mni_template" -o T1wRef_to_MNI1mm.nii.gz -w T1wRef_to_MNI1mm_warpfield.nii.gz --premat=T1wRef_to_MNI1mm_affine.mat
fi
echo "All ok"
exit 0