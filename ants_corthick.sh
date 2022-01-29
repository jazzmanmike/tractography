#!/bin/bash

#Michael Hart, University of British Columbia, February 2021 (c)

#define directories

codedir=${HOME}/Dropbox/Github/tractography
basedir="$(pwd -P)"

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

ants_corthick.sh

(c) Michael Hart, University of British Columbia, 2021

Performs ANTS cortical thickness algorithm
Also includes brain extraction & registration to standard space (usually MNI)


ants_corthick.sh -s mprage.nii.gz

Options:

-h  show this help
-s  anatomical image (not brain extracted or otherwise processed)
-t  path to standard space template
-o  overwrite output
-v  verbose

NB: standard space template requires images of full head, brain, brain mask, and priors
(see github MNI example and paths setup)

Version:    1.2

History:    amended from antsCT.sh (tumour mask version)

============================================================================

EOF
}


###################
# Standard checks #
###################


structural=
template=

#initialise options

while getopts "hs:tov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    s)
        structural=$OPTARG
        ;;
    t)
        template=$OPTARG
        ;;
    o)
        overwrite=1
        ;;
    v)
        verbose=1
        ;;
    ?)
        usage
        exit
        ;;
    esac
done

#set verbose option

if [ "$verbose" == 1 ]
    then
    set -x verbose
fi

#check usage

if [[ -z "${structural}" ]]
then
    echo "usage incorrect"
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "Checking structural data"
#structural=${basedir}/${structural}

if [ $(imtest "${structural}") == 1 ];
then
    echo "Structural dataset ok"
else
    echo "Cannot locate file $structural. Please ensure the $structural dataset is in this directory"
    exit 1
fi

if [ "${template}" = "" ];
then
    echo "No template supplied - using MNI"
    template=${HOME}/Dropbox/Github/tractography/ANTS_templates/
else
    echo "${template} dataset ok"
    template=${basedir}/${template}
fi

#make output directory

if [ ! -d ${basedir}/ants_corthick ];
then
    echo "making output directory"
    mkdir ${basedir}/ants_corthick
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        echo "overwriting output directory"
        mkdir -p ${basedir}/ants_corthick
    else
        echo "no overwrite permission to make new output directory"
        exit 1
    fi
fi

outdir=${basedir}/ants_corthick
#cd "${outdir}"

#start logfile
touch ${outdir}/ants_corthick_logfile.txt
log=${outdir}/ants_corthick_logfile.txt

echo $(date) >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


#define function

function antsCT() {

    #run antsCorticalThickness.sh

    echo "now running antsCorticalThickness.sh"

    antsCorticalThickness.sh \
    -d 3 \
    -a $structural \
    -e ${template}/MNI152_T1_2mm.nii.gz \
    -m ${template}/MNI152_T1_2mm_brain_mask.nii.gz \
    -p ${template}/Priors/prior%d.nii.gz \
    -t ${template}/MNI152_T1_2mm_brain.nii.gz \
    -o ants_corthick/

}

#call function

antsCT

#close up
#cd ${basedir}

echo "all done with ants_corthick.sh" >> ${log}
echo $(date) >> ${log}
