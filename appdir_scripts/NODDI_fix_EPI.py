#!/usr/bin/env python3

import nibabel as nib
import numpy as np
import sys


def fix_epi(
    in_file,
    out_file,
    voxel_size=(3.28125, 3.28125, 4.0),
    TR=2.16,
):
    img = nib.load(in_file)
    data = img.get_fdata()
    shape = data.shape[:3]

    # --- Build affine (RAS, centered) ---
    affine = np.eye(4)

    # Set voxel scaling
    affine[0, 0] = -voxel_size[0]  # R->L
    affine[1, 1] = voxel_size[1]   # P->A
    affine[2, 2] = voxel_size[2]   # I->S

    # Center the volume in world space
    affine[0, 3] = (shape[0] * voxel_size[0]) / 2.0
    affine[1, 3] = -(shape[1] * voxel_size[1]) / 2.0
    affine[2, 3] = -(shape[2] * voxel_size[2]) / 2.0

    # --- Create new header ---
    new_img = nib.Nifti1Image(data, affine)

    hdr = new_img.header

    # Set spatial resolution
    hdr.set_zooms(voxel_size + ((TR,) if data.ndim == 4 else ()))

    # Set qform and sform properly
    new_img.set_qform(affine, code=1)
    new_img.set_sform(affine, code=1)

    # Save
    nib.save(new_img, out_file)

    print("Saved fixed file:", out_file)
    print("Shape:", data.shape)
    print("Voxel size:", voxel_size)
    print("TR:", TR)
    print("Affine:\n", affine)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: fix_epi.py input.nii.gz output.nii.gz")
        sys.exit(1)

    fix_epi(sys.argv[1], sys.argv[2])
