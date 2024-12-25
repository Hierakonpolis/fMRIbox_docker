#!/bin/bash

mkdir -p /out/template/bc
cd /out/template/bc
ln /out/sub-*/ses-*/anat/sub-*_ses-*_acq-*_bc.nii.gz .
buildtemplateparallel.sh -c 2 -j $(nproc) -n 0 -r 1 -d 3 -o T1w_bc_ sub-*_ses-*_acq-*_bc.nii.gz
rm sub-*_ses-*_acq-*_bc.nii.gz

mkdir -p /out/template/bc_ss
cd /out/template/bc_ss
ln /out/sub-*/ses-*/anat/sub-*_ses-*_acq-*_bc_ss.nii.gz .
buildtemplateparallel.sh -c 2 -j $(nproc) -n 0 -r 1 -d 3 -o T1w_bc_ss_ sub-*_ses-*_acq-*_bc_ss.nii.gz
rm sub-*_ses-*_acq-*_bc_ss.nii.gz
