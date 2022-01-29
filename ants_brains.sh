#!/bin/bash
set -e

# ants_brains.sh
#
#
# Michael Hart, University of Cambridge, 13 April 2016 (c)

#define directories
codedir=${HOME}/Dropbox/Github/tractography
basedir=$(pwd)

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

ants_brains.sh

(c) Michael Hart, University of Cambridge, 2016

Does brain extraction with ANTs
As default uses MNI head & brain mask

Example:

ants_brains.sh -s mprage.nii.gz

Options:

-h  show this help
-s  anatomical
-t  template head (not skull stripped)
-m  brain mask of template
-o  overwrite output directory
-v  verbose

Version:    1.2

History:    amended for github tractography repository

NB:         require MNI template & mask (in Github repository)

============================================================================

EOF
}


###################
# Standard checks #
###################

structural=
template=
mask=

#initialise options

while getopts "hs:tmov" OPTION
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
    m)
        mask=$OPTARG
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

if [[ -z $structural ]]
then
    echo "usage incorrect" >&2
    usage
    exit 1
fi

echo "options ok"

# Set defaults if options empty

if [ "$template" == "" ]
then
    template="${codedir}/ANTS_templates/MNI152_T1_2mm.nii.gz"
fi

if [ "$mask" == "" ]
then
    mask="${codedir}/ANTS_templates/MNI152_T1_2mm_brain_mask.nii.gz"
fi

# final check of files

echo "Checking functional and template data"

#structural=${basedir}/${structural}

if [ $(imtest $structural) == 1 ];
then
    echo "Structural dataset ok"
else
    echo "Cannot locate file $structural. Please ensure the $structural dataset is in this directory"
    exit 1
fi

if [ $(imtest $template) == 1 ];
then
    echo "Template dataset ok"
else
    echo "Cannot locate file $template. Please ensure the $template dataset is in this directory"
    exit 1
fi

if [ $(imtest $mask) == 1 ];
then
    echo "Mask dataset ok"
else
    echo "Cannot locate file $mask. Please ensure the $mask dataset is in this directory"
    exit 1
fi

echo "files ok"

#make output directory

if [ ! -d ${basedir}/ants_brains ];
then
    echo "making output director"
    mkdir ${basedir}/ants_brains
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        mkdir -p ${basedir}/ants_brains
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/ants_brains

#make temporary directory

#tempdir="$(mktemp -t -d temp.XXXXXXXX)"
#cd "${tempdir}"
#mkdir ants_brains #duplicate

#cd "${outdir}"

#start logfile
touch ${outdir}/ants_brains_logfile.txt
log=${outdir}/ants_brains_logfile.txt

echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function antsBE() {

    antsBrainExtraction.sh \
    -d 3 \
    -a $structural \
    -e $template \
    -m $mask \
    -o ants_brains/

}

#call function

antsBE

echo "ants_brains.sh done: brain extracted"

#check results

echo "now viewing results"

slicer ants_brains/BrainExtractionBrain.nii.gz -a ants_brains/ants_brains_check.ppm

#cleanup

#cd ${basedir}
#cd ants_brains/
#cp -fpR . "${outdir}"
#cd ${outdir}
#rm -Rf ${tempdir} BrainExtractionMask.nii.gz BrainExtractionPrior0GenericAffine.mat

#close up

cd ..
echo "all done with ants_brains.sh" >> ${log}
echo $(date) >> ${log}
