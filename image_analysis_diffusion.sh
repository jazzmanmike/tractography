#!/bin/bash
set -e

# image_analysis_diffusion.sh
#
#
# Michael Hart, St George's University of London, July 2022 (c)

#define
codedir="${HOME}"/Dropbox/Github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make usage function

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

image_analysis_diffusion.sh

(c) Michael Hart, St George's University of London, January 2022

Image analysis pipeline for DBS data

Designed to be run with image_analysis_structural.sh (e.g. for selected registrations & structural processing)

Example:

image_analysis_diffusion.sh --data=diffusion.nii.gz --bvecs=bvecs.txt --bvals=bvals.txt --reverse=reverse_PhaseEncode.nii.gz

Options:

Mandatory
--data          diffusion data (e.g. standard = single B0 as first volume)
--bvecs         bvecs file
--bvals         bvals file

Optional
--reverse       reverse phase encode diffusion image (for make_diffusiondenoise.sh, runs TopUp/Eddy)
--segmentation  additional segmentation template (for segmentation: default is Yeo7)
--parcellation  additional parcellation template (for connectomics: default is AAL90 cortical)
-d              debug: runs whole script but only run analyses not performed yet ('tops up outputs if failed to run')
-o              overwrite (erase & re-do everything)
-h              show this help
-v              verbose

Additional text files (leave in basedir with prespecified names)
-acquisition parameters (for Eddy/TopUp, leave acqparams.txt in basedir)
-diffusion PE directions for Eddy/TopUp, leave index.txt in basedir)
-slice acquisition (for Eddy, leave slspec.txt in basedir)

Pipeline
1.  Baseline image quality control
2.  make_diffusiondenoise (optional, runs TopUp/Eddy, see above notes for additional text files, requires reverse_PhaseEncode)
3.  make_FDT
4.  make_bedpostx
5.  make_xtract
6.  make_segmentation
7.  make_DTI_connectome

Version:    1.0 July 2022

History:

NB: requires Matlab, Freesurfer, FSL, ANTs, and set path to codedir (also see electrode_reconstruction separately)
NNB: currently CPU based - todo: GPU based

=============================================================================================

EOF
exit 1
}


####################
# Run options call #
####################


#unset mandatory files
data=unset
bvecs=unset
bvals=unset
reverse=unset
segmentation=unset
parcellation=unset


# Call getopt to validate the provided input
options=$(getopt -n image_analysis_diffusion.sh -o dohv --long data:,bvecs:,bvals:,segmentation:,parcellation:,reverse: -- "$@")
echo "Options are: ${options}"

# If empty options
if [[ $1 == "" ]]; then
    usage
    exit 1
fi

# If options not valid
valid_options=$?

if [ "$valid_options" != "0" ]; then
    usage
    exit 1
fi

eval set -- "$options"
while :
do
    case "$1" in
    -d)             debug=1             ;   shift   ;;
    -o)             overwrite=1         ;   shift   ;;
    -h)             usage               ;   exit 1  ;;
    -v)             verbose=1           ;   shift   ;;
    --data)         data="$2"           ;   shift 2 ;;
    --bvecs)        bvecs="$2"          ;   shift 2 ;;
    --bvals)        bvals="$2"          ;   shift 2 ;;
    --segmentation) segmentation="$2"   ;   shift 2 ;;
    --parcellation) parcellation="$2"   ;   shift 2 ;;
    --reverse)      reverse="$2"        ;   shift 2 ;;
    --) shift; break ;;
    esac
done



###############
# Run checks #
##############


#check usage

if [[ -z ${data} ]] || [[ -z ${bvecs} ]] || [[ -z ${bvals} ]]
then
    echo "usage incorrect: mandatory inputs not entered"
    usage
    exit 1
fi


#call mandatory images / files

echo "Diffusion data are: ${data}"
echo "bvecs are: ${bvecs}"
echo "bvals are: ${bvals}"


#call non-mandatory options


if [ "${overwrite}" == 1 ] ;
then
    echo "overwrite set on"
else
    echo "overwrite is off"
fi

if [ "${verbose}" == 1 ] ;
then
    echo "verbose set on"
    set -x verbose
else
    echo "verbose set off"
fi

if [ "${debug}" == 1 ] ;
then
    echo "debug set on"
    set -x verbose
else
    echo "debug set off"
fi

echo "options ok"


#check mandatory images / files

echo "Checking mandatory files are ok (data, structural, bvecs, bvals)"

data_test=$(readlink -f "${data}")

if [ $(imtest "${data_test}") == 1 ] ;
then
    echo "diffusion data ok"
else
    echo "Cannot locate data file ${data_test}. Please ensure the ${data_test} dataset is in this directory -> exiting now" >&2
    exit 1
fi

bvecs_test=$(readlink -f "${bvecs}")

if [ -f "${bvecs_test}" ] ;
then
  echo "bvecs are ok"
else
  echo "Cannot locate bvecs file ${bvecs_test}. Please ensure the ${bvecs_test} dataset is in this directory -> exiting now" >&2
  exit 1
fi

bvals_test=$(readlink -f "${bvals}")

if [ -f "${bvals_test}" ] ;
then
  echo "bvals are ok"
else
  echo "Cannot locate bvals file ${bvals_test}. Please ensure the ${bvals_test} dataset is in this directory -> exiting now" >&2
  exit 1
fi

echo "All mandatory files (data, structural, bvecs, bvals) are ok"


#check optional image files

reverse_test=$(readlink -f "${reverse}")

if [ $(imtest "${reverse_test}") == 1 ] ;
then
    echo "reverse_PhaseEncode data ok"
else
    echo "Cannot locate reverse_PhaseEncode ${reverse}. Not running make_diffusiondenoise.sh"
fi

#segmentation atlas

segmentation_test=$(readlink -f "${segmentation}")

if [ $(imtest "${segmentation_test}") == 1 ] ;
then
    echo "Using ${segmentation_test} for segmentation: file is ok"
    segmentation=${segmentation_test}
else
    echo "Cannot locate additional segmentation template file: ${segmentation_test}. Please ensure the ${segmentation_test} is in this directory. Otherwise will continue with default DK (clustering), Yeo7, & kmeans segmentation."
fi

#parcellation template

parcellation_test=$(readlink -f "${parcellation}")

if [ $(imtest "${parcellation_test}") == 1 ] ;
then
    echo "Using ${parcellation_test} for parcellation: file is ok"
    parcellation=${parcellation_test}
else
    echo "Cannot locate additional parcellation template file: ${parcellation_test}. Please ensure the ${parcellation_test} is in this directory. Otherwise will continue with default AAL90 parcellation template."
fi


#make directory structure
if [ ! -d "${basedir}"/diffusion ] ;
then
    echo "making output directory"
    mkdir -p "${basedir}"/diffusion
else
    echo "output directory already exists"
    if [[ "${overwrite}" -eq 1 ]] ;
    then
        echo "overwrite on: making new output directory"
        rm -r "${basedir}"/diffusion
        mkdir -p "${basedir}"/diffusion
    elif [[ "${debug}" -eq 1 ]] ;
    then
        echo "debug on: keeping directory"
    else
        echo "no overwrite permission (or debug) to replace existing output directory -> exiting now"
        exit 1
    fi
fi

echo "basedir is ${basedir}"

outdir="${basedir}"/diffusion

mkdir -p "${outdir}"/QC

echo "outdir is: ${outdir}"


#move & gzip & rename files: use these files & preserve originals
fslchfiletype NIFTI_GZ "${data_test}" "${outdir}"/data #make copies of inputs in diffusion folder
data="${outdir}"/data.nii.gz #this is now working data with standard prefix

fslchfiletype NIFTI_GZ "${reverse_test}" "${outdir}"/reverse
reverse="${outdir}"/reverse.nii.gz

cp "${bvecs_test}" "${outdir}"
bvecs="${outdir}"/"${bvecs}"
cp "${bvals_test}" "${outdir}"
bvals="${outdir}"/"${bvals}"

#check additional text files
[ -f "${basedir}"/acqparams.txt ] && cp acqparams.txt "${outdir}"
[ -f "${basedir}"/index.txt ] && cp index.txt "${outdir}"
[ -f "${basedir}"/slspec.txt ] && cp slspec.txt "${outdir}"


#work in outdir (${basedir}/diffusion)
echo "working in ${outdir}"
cd "${outdir}"

#Start logfile: if already exists (and therefore script previously run) stops here

if [ ! -f "${outdir}"/image_analysis_diffusion_log.txt ] ;
then
    echo "making log file"
    touch image_analysis_diffusion_log.txt
else
    echo "log file already exists - image_analysis.sh has probably been run already"
    if [[ "$overwrite" == 1 ]] ;
    then
        echo "overwrite on: removing log file and making new one"
        rm image_analysis_diffusion_log.txt
        touch image_analysis_diffusion_log.txt
    elif [[ "$debug" == 1 ]] ;
    then
        echo "debug on: keeping log"
    else
        echo "no overwrite permission"
        exit 1
    fi
fi

log=image_analysis_diffusion_log.txt
date >> "${log}"
echo "${0}" >> "${log}"
echo "${@}" >> "${log}"
echo "Starting image_analysis.sh"
echo "" >> "${log}"
echo "Options are: ${options}" >> "${log}"
echo "" >> "${log}"
echo "basedir is ${basedir}" >> "${log}"
echo "outdir is ${outdir}" >> "${log}"
echo "" >> "${log}"


##################
# Main programme #
##################


function imageANALYSISDIFFUSION() {


    ########################


    #1. Base image quality control


    ########################


    echo "" >> "${log}"
    date >> "${log}"
    echo "1. Base image quality control" >> "${log}"


    #diffusion
    fslhd "${outdir}"/data.nii.gz >> "${outdir}"/QC/DTI_header.txt

    fslroi "${data}" B0 0 1
    fslroi "${data}" B1 1 1
    slicer B0.nii.gz -a "${outdir}"/QC/B0_base_image.ppm
    slicer B1.nii.gz -a "${outdir}"/QC/B1_base_image.ppm

    if [ $(imtest "${reverse}") == 1 ] ; then
        fslroi "${reverse}" R0 0 1
        slicer R0.nii.gz -a "${outdir}"/QC/R0_base_image.ppm
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with base image quality control" >> "${log}"
    echo "" >> "${log}"


    #######################

    #2. Advanced de-noising

    #######################


    echo "" >> "${log}"
    date >> "${log}"
    echo "2. Starting make_diffusiondenoise" >> "${log}"


    if [ $(imtest "${reverse}") == 1 ] ; then
        if [ ! -d "${outdir}"/topup ] ; then
            echo "calling make_diffusiondenoise.sh"
            make_diffusiondenoise.sh "${data}" "${reverse}" "${bvecs}" "${bvals}"
        else
            if [[ "${debug}" -eq 1 ]] ; then
                echo "topup exists and debug is on: not calling make_diffusiondenoise.sh again"
            else
                echo "topup exists and debug is off: repeating & overwriting make_diffusiondenoise.sh"
                echo "calling make_diffusiondenoise.sh"
                make_diffusiondenoise.sh "${data}" "${reverse}" "${bvecs}" "${bvals}"
            fi
        fi
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_diffusiondenoise" >> "${log}"
    echo "" >> "${log}"


    ########

    #3. FDT

    ########


    echo "" >> "${log}"
    date >> "${log}"
    echo "3. Starting make_FDT" >> "${log}"


    if [ ! -d "${outdir}"/FDT ] ;
    then
        echo "calling make_FDT.sh"
        #check if make_diffusiondenoise.sh has produced outputs
        if [ -f "${outdir}"/eddy/my_hifi_data.nii.gz ] ; then
            make_FDT.sh "${outdir}"/eddy/my_hifi_data.nii.gz "${outdir}"/eddy/my_hifi_b0_brain_mask "${bvecs}" "${bvals}"
        else
            if [ -f "${basedir}"/structural/registrations/nodif_brain_mask.nii.gz ] ; then
                mask="${basedir}"/structural/registrations/nodif_brain_mask.nii.gz #need to have run image_analysis_structural.sh
            else
                #make nodif_brain mask
                #extract B0 volume
                fslroi "${data}" "${basedir}"/structural/registrations/nodif 0 1
                #create binary brain mask
                bet "${basedir}"/structural/registrations/nodif "${basedir}"/structural/registrations/nodif_brain -m -f 0.2
                mask="${basedir}"/structural/registrations/nodif_brain_mask.nii.gz
            fi
            make_FDT.sh "${data}" "${mask}" "${bvecs}" "${bvals}"
        fi
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "FDT exists and debug is on: not calling make_FDT.sh again"
        else
            echo "FDT exists and debug is off: repeating & overwriting make_FDT.sh"
            if [ -f "${outdir}"/my_hifi_data.nii.gz ] ; then
                make_FDT.sh my_hifi_data.nii.gz my_hifi_b0_brain_mask "${bvecs}" "${bvals}"
            else
                mask="${basedir}"/diffusion/registrations/nodif_brain_mask.nii.gz #need to have run image_analysis_structural.sh
                make_FDT.sh "${data}" "${mask}" "${bvecs}" "${bvals}"
            fi
        fi
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_FDT" >> "${log}"
    echo "" >> "${log}"


    #############

    #4. BedPostX

    #############


    echo "" >> "${log}"
    date >> "${log}"
    echo "4. Starting make_bedpostx" >> "${log}"


    #1 hour
    if [ ! -d ${outdir}/bpx.bedpostX ] ;
    then
        #check if make_diffusiondenoise.sh has produced outputs
        if [ -f "${outdir}"/eddy/my_hifi_data.nii.gz ] ;
        then
            make_bedpostx.sh "${outdir}"/eddy/my_hifi_data.nii.gz "${bvecs}" "${bvals}" "${outdir}"/eddy/my_hifi_b0_brain_mask.nii.gz
        else
            echo "calling make_bedpostx.sh"
            make_bedpostx.sh "${data}" "${bvecs}" "${bvals}" "${basedir}"/structural/registrations/nodif_brain_mask.nii.gz
        fi
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "bpx.bedpostX exists and debug is on: not calling make_bedspotx.sh again"
        else
            echo "bpx.bedpostX exists and debug is off: repeating & overwriting make_bedpostx.sh"
            make_bedpostx.sh "${outdir}"/eddy/my_hifi_data.nii.gz "${bvecs}" "${bvals}" "${outdir}"/eddy/my_hifi_b0_brain_mask.nii.gz
          fi
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_bedpostx" >> "${log}"
    echo "" >> "${log}"


    #################

    #5. Registrations

    #################


    echo "" >> "${log}"
    date >> "${log}"
    echo "5. Starting registrations" >> "${log}"


    #dependency image_analysis_structural.sh
    brain="${basedir}"/structural/structural.anat/T1_biascorr_brain.nii.gz
    head="${basedir}"/structural/structural.anat/T1_biascorr.nii.gz

    #add catch if doesn't exist or use non-topup/eddy corrected
    if [ -f "${outdir}"/eddy/my_hifi_data.nii.gz ] ; then
        diff="${outdir}"/eddy/my_hifi_data.nii.gz
    else
        diff="${data}"
    fi

    echo "brain is: ${brain}"
    echo "head is: ${head}"
    echo "diffusion is: ${diff}"

    #check if make_registrations.sh has produced outputs
    if [ ! -d ${outdir}/registrations ] ;
    then
        make_registrations.sh "${brain}" "${head}" "${diff}"
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "registrations exists and debug is on: not calling make_registrations.sh again"
        else
            echo "registrations exists and debug is off: repeating & overwriting make_registrations.sh"
            make_registrations.sh "${brain}" "${head}" "${diff}"
          fi
    fi

    cp -r "${outdir}"/registrations/* "${outdir}"/bpx.bedpostX/xfms


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with registrations" >> "${log}"
    echo "" >> "${log}"


    ##########

    #6. XTRACT

    ##########


    echo "" >> "${log}"
    date >> "${log}"
    echo "6. Starting make_xtract" >> "${log}"


    #18 hours
    if [ ! -d ${outdir}/dbsxtract ] ;
    then
        echo "calling make_xtract.sh"
        make_xtract.sh
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "dbsxtract exists and debug is on: not calling make_xtract.sh again"
        else
            echo "dbsxtract exists and debug is off: repeating & overwriting make_xtract.sh"
            make_xtract.sh
          fi
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_xtract" >> "${log}"
    echo "" >> "${log}"


    #################

    #6. Segmentation

    #################

    echo "" >> "${log}"
    date >> "${log}"
    echo "10. Starting make_segmentation" >> "${log}"


    #dependency image_analysis_structural.sh

    if [ ! -d ${outdir}/segmentation ] ;
    then
        echo "calling make_segmentation.sh"
        #make_segmentation.sh ${segmentation}
    else
        if [[ "${debug}" -eq 1 ]] ;
        then
            echo "segmentation exists and debug is on: not calling make_segmentation.sh again"
        else
            echo "segmentation exists and debug is off: repeating & overwriting make_segmentation.sh"
            #make_segmentation.sh ${segmentation}
          fi
    fi


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_segmentation" >> "${log}"
    echo "" >> "${log}"


    #################

    #7. Connectomics

    #################


    echo "" >> "${log}"
    date >> "${log}"
    echo "11. Starting make_connectome" >> "${log}"


    #make_connectome.sh ${template}

    #dependency image_analysis_structural.sh
    template=${codedir}/templates/500.sym_4mm.nii.gz
    #make_connectome.sh ${template} #9 hour

    template=${outdir}/segmentation/dkn_volume_MNI_seq.nii.gz
    #make_connectome.sh ${template} #2 hour


    echo "" >> "${log}"
    date >> "${log}"
    echo "Finished with make_connectome" >> "${log}"
    echo "" >> "${log}"

}


######################################################################

# Round up

######################################################################


#call function

imageANALYSISDIFFUSION

echo "image_analysis_diffusion.sh completed"

#cleanup
echo "" >> "${log}"
date >> "${log}"
echo "Clean up time" >> "${log}"
echo "" >> "${log}"


#rm bpx.bedpostX/command_files/*
rm -r bpx.bedpostX/logs/*
#rm -r probtrackx/*/Seg*
#rm -r probtrackx/*/commands
rm -r *seeds


echo "" >> "${log}"
date >> "${log}"
echo "Clean up complete" >> "${log}"


#close up
echo "" >> "${log}"
echo "All done with image_analysis_diffusion.sh" >> "${log}"
date >> "${log}"
echo "" >> "${log}"
