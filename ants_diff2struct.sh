#!/bin/bash
set -e

# ants_diff2struct.sh
#
#
# Michael Hart, University of Cambridge, 13 April 2016 (c)

#define directories

codedir=${HOME}/code/github/tractography
basedir=$(pwd)

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

ants_diff2struct.sh

(c) Michael Hart, University of Cambridge, 2016

Creates an rigid transform from diffusion to structural space

Example:

ants_diff2struct.sh -d diffusion.nii.gz -s mprage_brain.nii.gz

Options:

-h  show this help
-d  diffusion image
-s  structural image (brain extracted)
-o  overwrite
-v  verbose

Version:    1.2

History:    amended for github tractography repository

============================================================================

EOF
}

###################
# Standard checks #
###################


#initialise options

diffusion=
structural=

while getopts "hd:s:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    d)
        diffusion=$OPTARG
        ;;
    s)
        structural=$OPTARG
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

if [[ -z $diffusion ]] || [[ -z $structural ]]

then
    echo "usage incorrect" >&2
    usage
    exit 1
fi

echo "options ok"

# final check of files

echo "Checking diffusion and structural data"

diffusion=${basedir}/${diffusion}

if [ $(imtest $diffusion) == 1 ];
then
    echo "${diffusion} dataset ok"
else
    echo "Cannot locate file ${diffusion}. Please ensure the ${diffusion} dataset is in this directory"
    exit 1
fi

structural=${basedir}/${structural}

if [ $(imtest $structural) == 1 ];
then
    echo "$structural dataset ok"
else
    echo "Cannot locate file $structural. Please ensure the $structural dataset is in this directory"
    exit 1
fi

echo "files ok"

#make output directory

if [ ! -d ${basedir}/ants_diff2struct ];
then
    echo "making output directory"
    mkdir ${basedir}/ants_diff2struct
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        echo "overwriting output directory"
        mkdir -p ${basedir}/ants_diff2struct
    else
        echo "no overwrite permission to make new output directory"
        exit 1
    fi
fi

outdir=${basedir}/ants_diff2struct

#make temporary directory

tempdir="$(mktemp -t -d temp.XXXXXXXX)"

cd "${tempdir}"

#start logfile

touch diff2struct_logfile.txt
log=diff2struct_logfile.txt

echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function antsD2S() {

    #1. generate a 3D affine transformation to a template

    antsRegistrationSyN.sh \
    -d 3 \
    -o rigid \
    -f ${structural} \
    -m ${diffusion} \
    -t r
	
    #2. warp image

    antsApplyTransforms \
    -d 3 \
    -o diff2struct.nii.gz \
    -i ${diffusion} \
    -t rigid0GenericAffine.mat \
    -r ${structural}

}

#call function

antsD2S

echo "ants_diff2struct.sh done: diffusion registered to structural"

#check results

echo "now viewing results"

slicer ${structural} diff2struct.nii.gz -a ants_diff2struct_check.ppm

#perform cleanup

cp -fpR . "${outdir}"
cd $outdir
rm -Rf "${tempdir}" epi_avg.nii.gz affineWarped.nii.gz affineInverseWarped.nii.gz

#complete log

echo "all done with ants_diff2struct.sh" >> ${log}
echo $(date) >> ${log}

