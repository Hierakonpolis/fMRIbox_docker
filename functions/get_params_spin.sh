#!/bin/bash

# Usage: ./get_params.sh file1 [file2] >> params.txt

# Check for at least one input
#if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
#    echo "Usage: $0 file1 [file2]"
#    exit 1
#fi

# Collect the input files
files=("$@")

# Iterate through provided files
for file in "${files[@]}"; do
    # Replace .nii or .nii.gz with .json to find the sidecar file
    json_file="${file%.nii*}.json"

    # Check if the JSON sidecar exists
    if [ ! -f "$json_file" ]; then
        echo "Error: JSON sidecar file not found for $file" >&2
        exit 1
    fi

    # Extract PhaseEncodingDirection and TotalReadoutTime from the JSON file
    phase_encoding_dir=$(jq -r '.PhaseEncodingDirection' "$json_file")
    total_readout_time=$(jq -r '.TotalReadoutTime' "$json_file")

    # Check if both parameters were found
    if [ "$phase_encoding_dir" == "null" ] || [ -z "$phase_encoding_dir" ]; then
        echo "Error: PhaseEncodingDirection missing in $json_file" >&2
        exit 1
    fi
    if [ "$total_readout_time" == "null" ] || [ -z "$total_readout_time" ]; then
        echo "Error: TotalReadoutTime missing in $json_file" >&2
        exit 1
    fi

    # Determine the direction parameter for TOPUP
    case "$phase_encoding_dir" in
        j) direction="0 1 0" ;;
        j-) direction="0 -1 0" ;;
        i) direction="1 0 0" ;;
        i-) direction="-1 0 0" ;;
        k) direction="0 0 1" ;;
        k-) direction="0 0 -1" ;;
        *)
            echo "Error: Unsupported PhaseEncodingDirection $phase_encoding_dir in $json_file" >&2
            exit 1
            ;;
    esac

    # Print the parameter line
    echo "$direction $total_readout_time"
done
