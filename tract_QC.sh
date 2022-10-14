#!/bin/bash
set -e

# tract_QC.sh
#
#
# Michael Hart, University of British Columbia, April 2021 (c)

#define

codedir=${HOME}/code/github/tractography
basedir="$(pwd -P)"
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make usage function

usage()
{
cat<<EOF
usage: $0 options

=============================================================================================

tract_QC.sh

(c) Michael Hart, University of British Columbia, April 2021

Quality control of tractography data run with: image_analysis.sh

Simply run as a script in directory used to run image_analysis.sh (checks output folder '/diffusion')

Outputs: 2 files - a text file with a variety of calls for visualisation (e.g. FSLEYES, Freeview) & a text file of notable values (e.g. SNR, CNR, etcetera). To view visualisation calls just cp & paste to terminal & run.

Options:
-o              overwrite
-h              show this help
-v              verbose


Pipeline
1.  Freesurfer: visualisation calls
2.  Freesurfer: SNR WM, Euler, QA_check, Quora files
3.  Brain extraction: visualisation calls (bet, fsl_anat, ANTs)
4.  Registration: visualisation calls (flirt, epi_reg, fnirt, ANTs) & cost functions
5.  Segmentation: FAST SNR/CNR WM/GM
6.  Diffusion: visualisation calls (DYADS, DTI, XTRACT)
7.  XTRACT stats

Version:    1.0

History:    original

NB: requires Matlab, Freesurfer, FSL, ANTs, and set path to codedir

=============================================================================================

EOF
exit 1
}


####################
# Run options call #
####################

#define options

overwrite=
verbose=

#initialise options

while getopts "hov" OPTION
do
    case $OPTION in
    h)
        usage
        exit 1
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

if [ ! -d ${basedir}/diffusion ]
then
    echo "usage incorrect - no '/diffusion' directory to run in - make sure in correct directory & image_analysis.sh run"
    usage
    exit 1
fi

cd diffusion/

#Output files: if already exists (and therefore script previously run) stops here unless 'overwrite' on

if [ ! -f ${basedir}/diffusion/tract_QC.txt ] ;
then
    echo "making output files"
    touch tract_QC.txt
    touch tract_QC_vis.txt
else
    echo "output files already exists - tract_QC.sh has probably been run already"
    if [ "$overwrite" == 1 ] ;
    then
        echo "overwrite on: making new output files"
        rm tract_QC.txt
        touch tract_QC.txt
        rm tract_QC_vis.txt
        touch tract_QC_vis.txt
    else
        echo "no overwrite permission - exiting now"
    exit 1
    fi
fi

if [ ! -d ${basedir}/diffusion/qoala ] ;
then
    echo "making quoala output directory"
    mkdir qoala
else
    echo "qoala directory already exists - tract_QC.sh has probably been run already"
    if [ "$overwrite" == 1 ] ;
    then
        echo "overwrite on: making new qoala directory"
        rm -r qoala
        mkdir qoala
    else
        echo "no overwrite permission - exiting now"
    exit 1
    fi
fi


log=${basedir}/diffusion/tract_QC.txt
log_vis=${basedir}/diffusion/tract_QC_vis.txt
echo $(date) >> ${log}
echo $(date) >> ${log_vis}
echo "${0}" >> ${log}
echo "${0}" >> ${log_vis}
echo "Starting tract_QC.sh"
echo "" >> ${log}
echo "" >> ${log_vis}
echo "Options are: ${options}" >> ${log}
echo "Options are: ${options}" >> ${log_vis}
echo "" >> ${log}
echo "" >> ${log_vis}
echo "basedir is: ${basedir}/diffusion" >> ${log}
echo "basedir is: ${basedir}/diffusion" >> ${log_vis}
echo "" >> ${log}
echo "" >> ${log_vis}


################
# Image header #
################


echo "" >> ${log}
echo "Image header data" >> ${log}
echo "" >> ${log}

x=`fslhd data.nii.gz | grep dim1 | awk 'FNR == 1 {print $2}'`
y=`fslhd data.nii.gz | grep dim2 | awk 'FNR == 1 {print $2}'`
z=`fslhd data.nii.gz | grep dim3 | awk 'FNR == 1 {print $2}'`
dir=`fslhd data.nii.gz | grep dim4 | awk 'FNR == 1 {print $2}'`
xvox=`fslhd data.nii.gz | grep pixdim1 | awk '{print $2}'`
yvox=`fslhd data.nii.gz | grep pixdim2 | awk '{print $2}'`
zvox=`fslhd data.nii.gz | grep pixdim3 | awk '{print $2}'`
scan=`fslhd data.nii.gz | grep aux_file | awk '{print $2}'`

echo "X dimension:" >> ${log}
echo "${x}" >> ${log}
echo "Y dimension:" >> ${log}
echo "${y}" >> ${log}
echo "Z dimension:" >> ${log}
echo "${z}" >> ${log}
echo "Diffusion directions:" >> ${log}
echo "${dir}" >> ${log}
echo "X voxel size:" >> ${log}
echo "${xvox}" >> ${log}
echo "Y voxel size:" >> ${log}
echo "${yvox}" >> ${log}
echo "Z voxel size:" >> ${log}
echo "${zvox}" >> ${log}
echo "Scan & sequences:" >> ${log}
echo "${scan}" >> ${log}

#fslhd data.nii.gz >> ${log} #slices, directions, sizes, voxels, scanner

echo "" >> ${log}


##############
# FreeSurfer #
##############


echo "" >> ${log_vis}
echo "FreeSurfer visualisation calls" >> ${log_vis}
echo "nb: from all of above, cd into FS then SUBJECTS_DIR=`pwd`"
echo "" >> ${log_vis}

#Set FreeSurfer directory
cd ./FS
echo "cd FS" >> ${log_vis}
export SUBJECTS_DIR=`pwd`
echo "export SUBJECTS_DIR=`pwd`" >> ${log_vis}

#Run alias calls

echo "" >> ${log_vis}
echo "#Check recon1" >> ${log_vis}
echo "" >> ${log_vis}
echo "freeview -v mri/brainmask.mgz -v mri/T1.mgz" >> ${log_vis}
echo "" >> ${log_vis}

echo "#Overview" >> ${log_vis}
echo "" >> ${log_vis}
echo "freeview -v mri/T1.mgz -v mri/wm.mgz -v mri/brainmask.mgz -v mri/aseg.mgz:colormap=lut:opacity=0.2 -f surf/lh.white:edgecolor=blue -f surf/lh.pial:edgecolor=red -f surf/rh.white:edgecolor=blue -f surf/rh.pial:edgecolor=red" >> ${log_vis}
echo "" >> ${log_vis}

echo "#Surfaces" >> ${log_vis}
echo "" >> ${log_vis}
echo "freeview -f surf/lh.pial:annot=aparc.annot:name=pial_aparc:visible=0 surf/lh.inflated:overlay=lh.thickness:overlay_threshold=0.1,3::name=inflated_thickness:visible=0 surf/lh.inflated:visible=0 surf/lh.white:visible=0 surf/lh.pial" >> ${log_vis}
echo "freeview -f surf/rh.pial:annot=aparc.annot:name=pial_aparc:visible=0 surf/rh.inflated:overlay=lh.thickness:overlay_threshold=0.1,3::name=inflated_thickness:visible=0 surf/rh.inflated:visible=0 surf/rh.white:visible=0 surf/rh.pial" >> ${log_vis}
echo "" >> ${log_vis}

echo "#White matter" >> ${log_vis}
echo "" >> ${log_vis}
echo "freeview -v mri/brainmask.mgz -v mri/wm.mgz:colormap=heatscale -f surf/lh.white:edgecolor=blue -f surf/lh.pial:edgecolor=red" >> ${log_vis}
echo "freeview -v mri/brainmask.mgz -v mri/wm.mgz:colormap=heatscale -f surf/rh.white:edgecolor=blue -f surf/rh.pial:edgecolor=red" >> ${log_vis}
echo "" >> ${log_vis}

cd ../
echo "cd ../" >> ${log_vis}

#FreeSurfer QC

SUBJECTS_DIR=`pwd`


echo "" >> ${log}
echo "FreeSurfer stats" >> ${log}
echo "" >> ${log}

#Euler
euler_left=`mris_euler_number FS/surf/lh.orig.nofix | grep total | awk '{print $5}'`
echo "Euler number, left hemisphere:">> ${log}
echo "${euler_left}" >> ${log}

euler_right=`mris_euler_number FS/surf/rh.orig.nofix | grep total | awk '{print $5}'`
echo "Euler number, right hemisphere:" >> ${log}
echo "${euler_right}" >> ${log}
echo "" >> ${log}


#Qoala-T files

asegstats2table --subjects FS --meas volume --skip --tablefile FS/stats/aseg_stats.txt
cp FS/stats/aseg_stats.txt qoala/

aparcstats2table --subjects FS --hemi lh --meas area --skip --tablefile FS/stats/aparc_area_lh.txt
cp FS/stats/aparc_area_lh.txt qoala/

aparcstats2table --subjects FS --hemi rh --meas area --skip --tablefile FS/stats/aparc_area_rh.txt
cp FS/stats/aparc_area_rh.txt qoala/

aparcstats2table --subjects FS --hemi lh --meas thickness --skip --tablefile FS/stats/aparc_thickness_lh.txt
cp FS/stats/aparc_thickness_lh.txt qoala/

aparcstats2table --subjects FS --hemi rh --meas thickness --skip --tablefile FS/stats/aparc_thickness_rh.txt
cp FS/stats/aparc_thickness_rh.txt qoala/


#mean WM, SD WM, SNR WM, mean G/W contrast, SD G/W contrast, CNR
#SNR: mean ./ SD
#CNR: mean1 - mean2 ./ SD
#NB: output to log & statsfile are slightly different formaing

mri_segstats --qa-stats FS statsfile

echo "Freesurfer WM SNR & CNR" >> ${log}
echo "" >> ${log}

wmm=`cat statsfile | awk '{print $12}'`
wmsd=`cat statsfile | awk '{print $13}'`
wmsnr=`cat statsfile | awk '{print $17}'`
echo "" >> ${log}
gwm=`cat statsfile | awk '{print $18}'`
gwsd=`cat statsfile | awk '{print $19}'`
cnr=`cat statsfile | awk '{print $20}'`

echo "White matter mean signal:" >> ${log}
echo "${wmm}" >> ${log}
echo "White matter signal SD:" >> ${log}
echo "${wmsd}" >> ${log}
echo "White matter SNR:" >> ${log}
echo "${wmsnr}" >> ${log}
echo "Grey-White contrast mean:" >> ${log}
echo "${gwm}" >> ${log}
echo "Grey-White contrast SD:" >> ${log}
echo "${gwsd}" >> ${log}
echo "CNR:" >> ${log}
echo "${cnr}" >> ${log}

#this is also an alternative to get the info:
#asegstats2table --subjects FS --stats wmparc.stats --tablefile wmparc.vol.table

echo "" >> ${log}
echo "All done with FreeSurfer QC" >> ${log}
echo "" >> ${log}


####################
# Brain extraction #
####################


echo "" >> ${log_vis}
echo "Brain extraction alias calls: structural space" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes ${basedir}/diffusion/bet/T1_brain.nii.gz ${basedir}/diffusion/structural.anat/T1_biascorr_brain.nii.gz ${basedir}/diffusion/ants_brains/BrainExtractionBrain.nii.gz " >> ${log_vis}
echo "" >> ${log_vis}


################
# Registration #
################


echo "" >> ${log_vis}
echo "Registration alias calls: MNI space - FSL & ANTs" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes --standard ${basedir}/structural.anat/T1_to_MNI_nonlin.nii.gz ${basedir}/ants_struct2stand/BrainExtractionBrain_MNI.nii.gz" >> ${log_vis}
echo "" >> ${log_vis}


################
# Segmentation #
################


echo "" >> ${log_vis}
echo "Segmentation checks" >> ${log_vis}
echo "First" >> ${log_vis}
echo "open -a Safari ${basedir}/diffusion/first_segmentation/slicesdir/index.html" >> ${log_vis}
echo "" >> ${log_vis}

echo "" >> ${log}
echo "Segmentation stats: FAST" >> ${log}

#SNR: mean ./ SD
#CNR: mean1 - mean2 ./ SD

echo "" >> ${log}
gmm=`fslstats ${basedir}/diffusion/structural.anat/T1.nii.gz -k ${basedir}/diffusion/structural.anat/T1_fast_pve_1.nii.gz -M`
echo "GM signal mean:" >> ${log}
echo "${gmm}" >> ${log}

gmsd=`fslstats ${basedir}/diffusion/structural.anat/T1.nii.gz -k ${basedir}/diffusion/structural.anat/T1_fast_pve_1.nii.gz -S`
echo "GM signal SD:" >> ${log}
echo "${gmsd}" >> ${log}

wmm=`fslstats ${basedir}/diffusion/structural.anat/T1.nii.gz -k ${basedir}/diffusion/structural.anat/T1_fast_pve_2.nii.gz -M`
echo "WM signal mean:" >> ${log}
echo "${wmm}" >> ${log}

wmsd=`fslstats ${basedir}/diffusion/structural.anat/T1.nii.gz -k ${basedir}/diffusion/structural.anat/T1_fast_pve_2.nii.gz -S`
echo "WM signal SD:" >> ${log}
echo "${wmsd}" >> ${log}

fslmaths bet/bet_outskin_mask.nii.gz -mul -1 -add 1 bet/invmask
bm=`fslstats ${basedir}/diffusion/structural.anat/T1_orig.nii.gz -k ${basedir}/diffusion/bet/invmask.nii.gz -s`
echo "Background (outside brain) signal SD:" >> ${log}
echo "${bm}" >> ${log}
echo "" >> ${log}


#############
# Diffusion #
#############


echo "" >> ${log_vis}
echo "DTI visualisation alias calls" >> ${log_vis}

#dtifit

echo "" >> ${log_vis}
echo "DTI fit" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes FDT/dti_FA dti_V1 -ot rgbvector" >> ${log_vis}
echo "" >> ${log_vis}

#as tensor

echo "" >> ${log_vis}
echo "As tensor" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes FDT/dti_FA ./" >> ${log_vis}
echo "" >> ${log_vis}

#as 6 volume image with unique elements of tensor matrix

echo "" >> ${log_vis}
echo "Tensor matrix" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes FDT/dti_tensor.nii.gz -ot tensor" >> ${log_vis}
echo "" >> ${log_vis}

#spherical harmonic components (to check this)

echo "" >> ${log_vis}
echo "Spherical harmonic components" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes FDT/asym_fods.nii.gz -ot sh" >> ${log_vis}
echo "" >> ${log_vis}

#bedpostx

echo "" >> ${log_vis}
echo "BedpostX" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes bpx.bedpostX/mean_f1samples diffusion.bedpostX/dyads1 -ot linevector bpx.bedpostX/dyads2_thr0.05 -ot linevector" >> ${log_vis}
echo "" >> ${log_vis}


#View dyads (& others)

echo "dyads" >> ${log_vis}
echo "" >> ${log_vis}
echo "fsleyes diffusion.bedpostX/mean_fsumsamples.nii.gz diffusion.bedpostX/dyads1.nii.gz -ot linevector -xc 1 0 0 -yc 1 0 0 -zc 1 0 0 -lw 2 diffusion.bedpostX/dyads2_thr0.05.nii.gz -ot linevector -xc 0 1 0 -yc 0 1 0 -zc 0 1 0 -lw 2 diffusion.bedpostX/dyads3_thr0.05.nii.gz -ot linevector -xc 0 0 1 -yc 0 0 1 -zc 0 0 1 -lw 2" >> ${log_vis}
echo "" >> ${log_vis}


################
# XTRACT stats #
################


if [ ! -d ${basedir}/diffusion/myxtract ] ;
then
    echo "xtract not run - not running xtract stats"
else
    if [ ! -f ${basedir}/diffusion/myxtract/stats.csv ] ;
    then
        #xtract stats
        echo "" >> ${log}
        echo "Running xtract_stats"
        echo "Running xtract_stats" >> ${log}
        xtract_stats -d ${basedir}/diffusion/FDT/dti_ -xtract ${basedir}/diffusion/myxtract -w ${basedir}/diffusion/bpx.bedpostX/xfms/standard2diff.nii.gz -r ${basedir}/diffusion/FDT/dti_FA.nii.gz -keepfiles
        echo "" >> ${log}
    else
        echo "" >> ${log}
        echo "xtract_stats already run"
        echo "xtract_stats already run" >> ${log}
        echo "" >> ${log}
    fi
fi

#xtract_viewer
echo "xtract_viewer call" >> ${log_vis}
echo "xtract_viewer -dir myxtract -species HUMAN" >> ${log_vis}


############
# Round up #
############


echo "" >> ${log}
echo "" >> ${log_vis}
echo "all done with tract_QC.sh"
echo "all done with tract_QC.sh" >> ${log}
echo "all done with tract_QC.sh" >> ${log_vis}
echo $(date) >> ${log}
echo $(date) >> ${log_vis}
echo "" >> ${log}
echo "" >> ${log_vis}
