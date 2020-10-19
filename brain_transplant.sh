#!/bin/bash
set -e

# brain_transplant.sh
#
#
# Michael Hart, University of Cambridge, 18 July 2017 (c)

#define directories

codedir=${HOME}/bin
basedir=$(pwd)

#make usage function

usage()
{
cat<<EOF
usage: $0 options

===========================================================================

brain_transplant.sh

(c) Michael Hart, University of Cambridge, 2017

Transplants (contralateral) *healthy* brain instead of a lesion / tumour (mask)
Can be useful for Freesurfer
See: Solodkin et al, 2010

Example:

brain_transplant.sh -s mprage.nii.gz -w standard2structural.nii.gz -m mask.nii.gz

Options:

-h  show this help
-s  structural / anatomical image e.g. mprage, T1, etc
-w  warp from standard to structural space (e.g. output of ATR)		
-m  mask of tumour (structural space)
-o  overwrite output directory
-v  verbose

Version:    1.1

History:    change output directories and names

============================================================================

EOF
}


###################
# Standard checks #
###################

structural=
warp=
mask=

#initialise options

while getopts "hs:w:m:ov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
        ;;
    s)
        structural=$OPTARG
        ;;
    w)
        warp=$OPTARG
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
    echo "usage incorrect" 
    usage
    exit 1
fi

echo "options ok"


# Set defaults if options empty

template="${HOME}/ANTS/ANTS_templates/MNI/MNI152_T1_2mm.nii.gz"


# final check of files

echo "Checking structural, warp, and mask"

structural=${basedir}/${structural}

if [ $(imtest $structural) == 1 ];
then
    echo "Structural data ok"
else
    echo "Cannot locate file $structural. Please ensure the $structural dataset is in this directory"
    exit 1
fi

warp=${basedir}/${warp}

if [ $(imtest $warp) == 1 ];
then
    echo "Warp data ok"
else
    echo "Cannot locate file $warp. Please ensure the $warp dataset is in this directory"
    exit 1
fi

mask=${basedir}/${mask}

if [ $(imtest $mask) == 1 ];
then
    echo "Mask data ok"
else
    echo "Cannot locate file $mask. Please ensure the $mask dataset is in this directory"
    exit 1
fi

echo "files ok"

#make output directory

if [ ! -d ${basedir}/brain_transplant ];
then
    echo "making output director"
    mkdir ${basedir}/brain_transplant
else
    echo "output directory already exists"
    if [ "$overwrite" == 1 ]
    then
        mkdir -p ${basedir}/brain_transplant
    else
        echo "no overwrite permission to make new output directory"
    exit 1
    fi
fi

outdir=${basedir}/brain_transplant

#make temporary directory

tempdir="$(mktemp -t -d temp.XXXXXXXX)"

cd "${tempdir}"

#start logfile

touch brain_transplant_logfile.txt
log=brain_transplant_logfile.txt

echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "${@}" >> ${log}


##################
# Main programme #
##################


function antsBT() {


    #1. Determine if right or left tumour
    
    tumour_side=`fslstats ${mask} -c | awk '{print $1}'`	

    #2. Right & Left hemisphere masks
    
    #if right tumour
    if [ `echo "${tumour_side} > 0" | bc -l` = 1 ]; then
	    fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -roi 0 45 0 -1 0 -1 0 1 ipsilateral_MNI #i.e. right is <45 in MNI space
	    fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -roi 45 -1 0 -1 0 -1 0 1 contralateral_MNI
    #if left tumour
    	else
	    fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -roi 45 -1 0 -1 0 -1 0 1 ipsilateral_MNI #i.e. left is >45 in MNI space
	    fslmaths ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -roi 0 45 0 -1 0 -1 0 1 contralateral_MNI	
    fi    
    
    antsApplyTransforms \
    -d 3 \
    -i contralateral_MNI.nii.gz \
    -o contralateral_structural.nii.gz \
    -r ${structural} \
    -t ${warp} \
    -n NearestNeighbor \
    --float 1
    
    antsApplyTransforms \
    -d 3 \
    -i ipsilateral_MNI.nii.gz \
    -o ipsilateral_structural.nii.gz \
    -r ${structural} \
    -t ${warp} \
    -n NearestNeighbor \
    --float 1
    
    fslmaths $structural -mas ipsilateral_structural ipsilateral_brain
    
    fslmaths $structural -mas contralateral_structural contralateral_brain
    
    #3. Register hemispheres
    
    fslswapdim contralateral_brain -x y z contralateral_brain_flipped
    
    antsRegistrationSyN.sh \
    -d 3 \
    -f ipsilateral_brain.nii.gz \
    -m contralateral_brain_flipped.nii.gz \
    -o contralateral
    
    #3. Transplant tissue
    
    fslmaths ${mask} -binv brain_mask
    fslmaths ${structural} -mul brain_mask structural_notumour
    fslmaths contralateralWarped -mas ${mask} brain2transplant
    fslmaths structural_notumour -add brain2transplant transplanted_brain
    
}

#call function

antsBT

echo "brain_transplant.sh done: brain transplanted"

#check results

echo "now viewing results"

slices $anat transplanted_brain.nii.gz -o BT_check.gif

#cleanup

cp -fpR . "${outdir}"
cd $outdir
rm -Rf ${tempdir} 

#close up

echo "all done with brain_transplant.sh" >> ${log}
echo $(date) >> ${log}
