#!/bin/bash

#  Print commands and their arguments as they are executed.
set -x

#  Sets MNI project to true by default
mni_project=false


#    Getopts is used by shell procedures to parse positional parameters.
#    Check for the optional flags that were provided in the pd_dockerParallelized.sh script

while getopts f:a:j:c:b:s:l:r:p:o:n:m: flag
do
        case "${flag}" in
                f) # -f flag was used to provide the functional MRI image file
			func_file=${OPTARG}
			func_filepath=/func/${func_file}
			;;
                a) # -a flag was used to provide the anatomical MRI image file
			anat_file=${OPTARG}
			anat_filepath=/anat/${anat_file}
			;;
                c) # -c flag was used to provide the magnitude 2 image
			biasmag2_file=${OPTARG}
			biasmag2_filepath=/fmap/${biasmag2_file}
			;;
                b) # -b flag was used to provide the magnitude 1 image
			biasmag1_file=${OPTARG}
			biasmag1_filepath=/fmap/${biasmag1_file}
			;;
                s) # -s flag was used to provide the phase difference image
			phasediff_file=${OPTARG}
			phasediff_filepath=/fmap/${phasediff_file}
			;;
                l) # -l flag was used to provide the left-right spin echo fieldmap file
			spin1_file=${OPTARG}
			spin1_filepath=/fmap/${spin1_file}
			;;
                r) # -r flag was used to provide the right-left spin echo fieldmap file
			spin2_file=${OPTARG}
			spin2_filepath=/fmap/${spin2_file}
			;;
                o) # -o flag was used to provide the output directory for the processed images
			out_filepath=${OPTARG}
			;;
                n) # -n flag was used to indicate not putting subject into MNI space
			mni_project=${OPTARG}
			;;
        esac
done


# Print file names to the console how they were parsed into script
echo "func_file : ${func_file}"
echo "anat_file : ${anat_file}"
echo "json_file : ${json_file}"
echo "phasediff_filepath : ${phasediff_filepath}"
echo "biasmag1_filepath : ${biasmag1_filepath}"
echo "biasmag2_filepath : ${biasmag2_filepath}"
echo "spin1_filepath : ${spin1_filepath}"
echo "spin2_filepath : ${spin2_filepath}"
echo "out_filepath : ${out_filepath}"
echo "mni_project :  ${mni_project}"


# Extract the subject ID from the functional run's file name and capture it in a variable to use later
subjectID=$(echo "$func_file" | grep -oP "sub-[^_]+")
sessionID=$(echo "$func_file" | grep -oP "ses-[^_]+")

echo "subjectID is ${subjectID}"
echo "sessionID is ${sessionID}"

# Location of the temporary filesystem in the singularity container
tmpfs=/out

# Location on cluster mounted into sif container for final processed image
outputMount="${tmpfs}/${subjectID}/${sessionID}"

# Capture the start time of the script to measure benchmark time
start=`date +%s`

#Sets path for ROBEX (For Skullstripping)
export PATH=$PATH:/usr/lib/ROBEX:/usr/lib/ants

#Sets path for ANTs tools (for normalization workflow)
export ANTSPATH=/usr/lib/ants

#Sets additional paths for AFNI and FSL
export AFNIbinPATH=/usr/local/AFNIbin
PATH=${AFNIbinPATH}:${PATH}
PATH=${FSLDIR}/bin:${PATH}
export FSLDIR PATH
. ${FSLDIR}/etc/fslconf/fsl.sh

template=/opt/fsl/data/standard/MNI152_T1_2mm_brain.nii.gz
templatemask=/opt/fsl/data/standard/MNI152_T1_2mm_brain_mask.nii.gz

#Create directory for subject intermediate derivative files
mkdir -p $outputMount



# Sets locations of intermediate file directories
mocodir=${outputMount}/motion
coregdir=${outputMount}/coregistration
procdir=${outputMount}/processed
anatdir=${outputMount}/anat
funcdir=${outputMount}/func
fmapdir=${outputMount}/fmap
biasdir=${outputMount}/bias_field
sbrefdir=${outputMount}/SBRef

# Non-destructively creates intermediate file directories
mkdir -p ${coregdir}
mkdir -p ${mocodir}
mkdir -p ${procdir}
mkdir -p ${anatdir}
mkdir -p ${funcdir}
mkdir -p ${fmapdir}

fmri_name=$(basename "$func_filepath" | sed -E 's/\.(nii|nii\.gz)$//')
fmap_basename=$(basename "$spin1_file" | sed -E 's/\.(nii|nii\.gz)$//')
bmap_basename=$(basename "$biasmag2_filepath" | sed -E 's/\.(nii|nii\.gz)$//')
phasediff_basename=$(basename "$phasediff_filepath" | sed -E 's/\.(nii|nii\.gz)$//')

json_file="${fmri_name}.json"
json_filepath="/func/${json_file}"

params_filepath="${fmapdir}/${fmap_basename}_params.txt"
merged_path="${fmapdir}/${fmap_basename}_Merged.nii.gz"
topup_results="${fmapdir}/${fmap_basename}_TOPUP"
topup_fmap="${fmapdir}/${fmap_basename}_TOPUP_FIELDMAP.nii.gz"
topup_corr="${fmapdir}/${fmap_basename}_TOPUP_CORRECTION.nii.gz"
func_file_params_path="${funcdir}/${fmri_name}_params.txt"
fieldmap_rads_path="${fmapdir}/${bmap_basename}_fmap_rads.nii.gz"

/app/functions/get_params_spin.sh "${func_filepath}" > "${func_file_params_path}"

# (Bias Correction for voxel intensity distortions) Calls the AFNI linux utilities to prepare de-baised fMRI and SBREF subject data
function fieldmap_set() {

  if [ ! -f "${fieldmap_rads_path}" ]; then
  old_dir=$PWD
  cd /ROBEX
  ./ROBEX "$biasmag2_filepath" "${fmapdir}/${bmap_basename}_ss.nii.gz" "${fmapdir}/${bmap_basename}_mask.nii.gz"
  cd $old_dir

  rm "${fmapdir}/${bmap_basename}_TEMP.nii.gz"
  fslmaths "${fmapdir}/${bmap_basename}_mask.nii.gz" -kernel boxv 5 -ero "${fmapdir}/${bmap_basename}_mask_ero.nii.gz"
  fslmaths "$phasediff_filepath" -mul "${fmapdir}/${bmap_basename}_mask_ero.nii.gz" "${fmapdir}/${bmap_basename}_ss.nii.gz"

	# Prepare fieldmap
	json_file_phase="/fmap/${phasediff_basename}.json"
	echo_time1=$(jq -r '.EchoTime1' "$json_file_phase")
  echo_time2=$(jq -r '.EchoTime2' "$json_file_phase")

  difference_ms=$(echo "($echo_time2 - $echo_time1) * 1000" | bc)
  fsl_prepare_fieldmap SIEMENS "${phasediff_filepath}" "${fmapdir}/${bmap_basename}_ss.nii.gz" "${fieldmap_rads_path}" $difference_ms
  fugue --loadfmap="${fieldmap_rads_path}" --despike --savefmap="${fieldmap_rads_path}"
  fugue --loadfmap="${fieldmap_rads_path}" -m --savefmap="${fieldmap_rads_path}"
  fi
# Apply correction
  dwell_time=$(jq -r '.EffectiveEchoSpacing' "$json_filepath")
  if [ ! -f "${2}" ]; then
  fugue -i $1 --dwell="${dwell_time}" --loadfmap="${fieldmap_rads_path}" --unwarpdir=y- -u "$2"
  fi
}

# (TOPUP Correction for Geometric Distortions)
function topup_set() {
	# acqparams is a 4xN matrix : first three cols are xyz phase encoding directions, last col is readout time, stored in a text file provided by user
	# N is number of volumes in ${fmapdir}/${subjectID}_3T_Phase_Map.nii.gz	 (created as output from FSL merge function below)
	# See here for more information: https://web.mit.edu/fsl_v5.0.10/fsl/doc/wiki/topup(2f)TopupUsersGuide.html#A--datain

  echo "" > "${params_filepath}"
	/app/functions/loop_get_spins.sh "${spin1_filepath}" "${params_filepath}"
	/app/functions/loop_get_spins.sh "${spin2_filepath}" "${params_filepath}"

      if [ ! -f "${topup_corr}" ]; then
        # Concatenates left-right and right-left spin echo fieldmaps into one fieldmap
        fslmerge -t "${merged_path}" "${spin1_filepath}" "${spin2_filepath}"
        # Estimates the geometric susceptibility fieldmap using the LR/RL fieldmap and acquisition parameters matrix
        topup --imain="${merged_path}" --datain="$params_filepath" --out="${topup_results}" --fout="${topup_fmap}" --iout="${topup_corr}" --config=b02b0.cnf -v
      fi

	# Applies the estimated geometric susceptibility fieldmap [to the de-biased fMRI data created from function afni_set (as a background process) - not yet]
	if [ ! -f "${func_topup_corr}.nii.gz" ]; then
      	applytopup --imain="${1}" --datain="${func_file_params_path}" --inindex=1 --topup="${topup_results}" --out="${2}" --method=jac -v
  fi

        echo 'finished topup'
}

anat_bc_name=$(basename "$anat_filepath" | sed -E 's/\.(nii|nii\.gz)$//')_bc.nii.gz
anat_bc_ss_name=$(basename "$anat_filepath" | sed -E 's/\.(nii|nii\.gz)$//')_bc_ss.nii.gz
anat_bc_path="${anatdir}/${anat_bc_name}"
anat_bc_ss_path="${anatdir}/${anat_bc_ss_name}"
function skullstrip() {
    anatdir=$1
    #Performs the N3/4 Bias correction on the T1 and Extracts the Brain
    if [ ! -f "${anat_bc_ss_path}" ]; then
    N3BiasFieldCorrection 3 "$anat_filepath" "${anat_bc_path}"

    N4BiasFieldCorrection -d 3 -i "${anat_bc_path}" -o "${anat_bc_path}" -s 10
    N4BiasFieldCorrection -d 3 -i "${anat_bc_path}" -o "${anat_bc_path}" -s 8
    N4BiasFieldCorrection -d 3 -i "${anat_bc_path}" -o "${anat_bc_path}" -s 6
    N4BiasFieldCorrection -d 3 -i "${anat_bc_path}" -o "${anat_bc_path}" -s 4
    N3BiasFieldCorrection 3 "${anat_bc_path}" "${anat_bc_path}"
    N4BiasFieldCorrection -d 3 -i "${anat_bc_path}" -o "${anat_bc_path}" -s 2

    /usr/local/AFNIbin/3dSkullStrip -input "${anat_bc_path}" -prefix "${anat_bc_ss_path}" -smooth_final 2 -overwrite
    fi
#    cd /ROBEX
#
#    ./ROBEX "${anat_bc_path}" ${anatdir}/T1_bc_ss.nii.gz
}

# Performs slice timing correction and then uses 3dvolreg to align despiked data to one reference volume (first volume)
function moco_sc() {
        epi_in=$1
        ref_vol=$2
	subjectID=$3

    	cd ${mocodir}

	#slice timing correction
	# If json is missing:
        if [ -z "$json_file" ]
        then
                echo "no json file was included in input text file"
		# Get the TR value from the nii header
		TR=$(fslval $func_filepath pixdim4)
		echo "Detected TR: $TR"

		#Get the number of slices from the nii header
		num_slices=$(fslval $func_filepath dim3)

		#Try to extract the slice order from nii header
		slice_order=$(fslval $func_filepath slice_order)
		if [ -z "$slice_order" ]
		then
			slice_order="ascending"
		fi

		# Calcuate the time at which each slice was acquired
		increment=$(echo "scale=6; $TR / $num_slices" | bc)
		case $slice_order in
			"ascending")
				slice_times=($(seq -f "%.4f" 0 $increment $(echo "$TR - $increment" | bc)))
				;;
			"descending")
				slice_times=($(seq 0 $((num_slices-1)) | xargs -I{} echo "scale=6; $increment * {}" | bc))
				;;
			*)
				echo "Error: Unsupported slice order '$slice_order'" >&2
		esac

		echo "${slice_times[@]}" | tr ' ' '\n' > slice_timing_file.txt
		slice_timing_file=slice_timing_file.txt
		slice_duration=$(fslval $func_filepath slice_duration)

		3dDespike -NEW -prefix ${fmri_name}_ds.nii.gz ${epi_in}

		if (( $(echo "$slice_duration < $TR" | bc -l) )); then
    			echo "multiband data detected"
			echo $slice_timing_file
			slicetimer -i ${fmri_name}_ds.nii.gz -o ${mocodir}/${fmri_name}_ds_st.nii.gz --tcustom=$slice_timing_file
		else
    			echo "singleband data detected"
			slicetimer -i ${fmri_name}_ds.nii.gz -o ${mocodir}/${fmri_name}_ds_st.nii.gz -r $TR

		fi

		# Else, if we have the json

        else
                #Metadata extraction from BIDS compliant json sidecar file
                abids_json_info.py -field SliceTiming -json ${json_filepath} | sed 's/[][]//g' | tr , '\n' | sed 's/ //g' > ${fmri_name}_tshiftparams.1D
                #Finds the number where the slice value is 0 in the slice timing
                SliceRef=`cat ${fmri_name}_tshiftparams.1D | grep -m1 -n -- "0$" | cut -d ":" -f1`

                #Pulls the TR from the json file. This tells 3dTshift what the scaling factor is
                TR=`abids_json_info.py -field RepetitionTime -json ${json_filepath}`

		3dDespike -NEW -prefix ${fmri_name}_ds.nii.gz ${epi_in}

		#Timeshifts the data. It's SliceRef-1 because AFNI indexes at 0 so 1=0, 2=1, 3=2, etc
		3dTshift -tzero $(($SliceRef-1)) -tpattern @${fmri_name}_tshiftparams.1D -TR ${TR} -quintic -prefix ${fmri_name}_ds_st.nii.gz ${fmri_name}_ds.nii.gz
        fi

   	#   Rotate all volumes to align with the first volume as a reference
	3dvolreg -verbose -zpad 1 -base ${ref_vol} -heptic -prefix ${fmri_name}_ds_st_mc -1Dfile ${fmri_name}_motion.1D -1Dmatrix_save mat.${fmri_name}.1D ${fmri_name}_ds_st.nii.gz

	echo `ls .`

	if [ -f "${fmri_name}_ds_st_mc+orig.BRIK" ]; then
		3dresample -orient RPI -inset ${fmri_name}_ds_st_mc+orig -prefix ${procdir}/${moco_out}
	else
		3dresample -orient RPI -inset ${fmri_name}_ds_st_mc+tlrc -prefix ${procdir}/${moco_out}
	fi

	echo "moco done"

}

#  Skull Stripped Bias Corrected Anatomical T1 Image
vrefbrain=${anat_bc_ss_path}


#  Bias Corrected Anatomical T1 Image (Head Included)
vrefhead=${anat_bc_path}

#  Suffix for Corregistered Image
vout="${fmri_name}_ts_ds_mc_MNIreg.nii.gz"

epi_orig=$func_filepath


#   Function call to Perform T1 Bias Correction and Skull Strip
skullstrip "${anatdir}"
func_topup_corr="${funcdir}/${fmri_name}_topup"
func_fugue_corr="${funcdir}/${fmri_name}_fugue"

if [[ (-e "$phasediff_filepath") && (-e "$biasmag2_filepath") ]]; then
    # Both phasediff and biasmag2 files exist
    fieldmap_set "$epi_orig" "$func_fugue_corr"
    sc_in=${func_fugue_corr}.nii.gz
    fmri_name="${fmri_name}_fugue"

elif [[ (-e "${spin2_filepath}") && (-e "${spin2_filepath}") ]]; then
    # Both spin echo field maps exist
    topup_set "$epi_orig" "$func_topup_corr"
    sc_in=${func_topup_corr}.nii.gz
    fmri_name="${fmri_name}_topup"

else
    # Neither set of field maps exists
    echo "Neither FUGUE nor TOPUP correction could be performed. Using original EPI."
    sc_in=${epi_orig}
fi

moco_out="${fmri_name}_ds_st_mc.nii.gz"
moco_out_path="${procdir}/${moco_out}"

if [ ! -f "$moco_out_path" ];
then
  /usr/local/AFNIbin/3dcalc -a0 ${epi_orig} -prefix ${coregdir}/${fmri_name}.nii.gz -expr 'a*1'

  moco_sc ${sc_in} ${coregdir}/${fmri_name}.nii.gz ${subjectID}
fi