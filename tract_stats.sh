#!/bin/bash
set -e

# tract_stats.sh
#
#
# Michael Hart, University of British Columbia, June 2021 (c)

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

tract_stats.sh -s stimulation_field.nii.gz

(c) Michael Hart, University of British Columbia, June 2021

Statistical outputs of tractography data (e.g. that run with: tract_van.sh or mini_tract.sh)

Simply run as a script in directory used to run tract_van.sh (checks output folder '/diffusion')

Outputs: text file of tractography biomarkers overlap with stimulation_field

Options:
-s              stimulation field (e.g. VAT/VTA with which to be tested with tractography data)
-o              overwrite
-h              show this help
-v              verbose

Pipeline
1. Tract based outcomes (e.g. DRT, NF, PF)
2. Segmentation based outcomes (e.g. cluster, hard segmentation, k-means)
3. Connectome based outcomes (e.g. module connectivity)

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

while getopts "shov" OPTION
do
    case $OPTION in
    s)
        stimulationfield=1
        ;;
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

###############
# Run checks #
##############


#check usage

if [[ -z ${stimulationfield} ]]
then
    echo "usage incorrect: mandatory inputs not entered"
    usage
    exit 1
fi

if [ ! -d ${basedir}/diffusion ]
then
    echo "usage incorrect - no '/diffusion' directory to run in - make sure in correct directory & tract_van.sh run"
    usage
    exit 1
fi

cd diffusion/


#call mandatory images / files

echo "stimulation field data are: ${stimulationfield}"


#check mandatory images / files

echo "Checking mandatory files are ok (stimulation field image)"

stimulationfield_test=${basedir}/${volume}

if [ $(imtest $stimulationfield_test) == 1 ] ;
then
    echo "stimulation field data are ok"
else
    echo "Cannot locate data file ${stimulationfield_test}. Please ensure the ${stimulationfield_test} dataset is in this directory -> exiting now" >&2
    exit 1
fi


#set verbose option

if [ "${verbose}" == 1 ] ;
then
    echo "verbose set on"
    set -x verbose
else
    echo "verbose set off"
fi


#Output files: if already exists (and therefore script previously run) stops here unless 'overwrite' on

if [ ! -d ${basedir}/diffusion/tract_stats ] ;
then
    echo "making output files"
    mkdir -p tract_stats
    touch tract_stats/tract_stats.txt
else
    echo "output directory already exists - tract_stats.sh has probably been run already"
    if [ "$overwrite" == 1 ] ;
    then
        echo "overwrite on: making new output files"
        rm -r tract_stats/
        mkdir -p tract_stats
        touch tract_stats/tract_stats.txt
    else
        echo "no overwrite permission - exiting now"
    exit 1
    fi
fi

outdir=${basedir}/diffusion/tract_stats

log=${outdir}/tract_stats.txt
echo $(date) >> ${log}
echo "${0}" >> ${log}
echo "Starting tract_stats.sh"
echo "" >> ${log}
echo "Options are: ${options}" >> ${log}
echo "" >> ${log}
echo "basedir is: ${basedir}/diffusion" >> ${log}
echo "" >> ${log}
echo "outdir is: ${basedir}/diffusion/tract_stats" >> ${log}
echo "" >> ${log}


#############
# 1. Tracts #
#############


echo "" >> ${log}
echo "1. Tract analysis" >> ${log}
echo "" >> ${log}


if [ ! -d ${basedir}/diffusion/dbsxtract ] ;
then
    echo "Directory dbsxtract exists: performing tract based analysis"
    echo "Directory dbsxtract exists: performing tract based analysis" >> ${log}
    
    #DRT
    echo "DRT" >> ${log}
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/drt_l/density.nii.gz -thr 0.5 ${outdir}/drt_l_thr
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/drt_r/density.nii.gz -thr 0.5 ${outdir}/drt_r_thr

    echo "DRT_l" >> ${log}
    fslstats ${outdir}/drt_l_thr -V >> ${log}

    echo "DRT_r" >> ${log}
    fslstats ${outdir}/drt_r_thr -V >> ${log}

    fslmaths ${outdir}/drt_l_thr -sub ${stimulationfield_test} ${outdir}/drt_l_lesion
    fslmaths ${outdir}/drt_r_thr -sub ${stimulationfield_test} ${outdir}/drt_r_lesion

    echo "DRT_l_lesion" >> ${log}
    fslstats ${outdir}/drt_l_lesion -V >> ${log}
    echo "" >> ${log}

    echo "DRT_r_lesion" >> ${log}
    fslstats ${outdir}/drt_r_lesion -V >> ${log}
    echo "" >> ${log}

    echo "" >> ${log}


    #NF
    echo "NF" >> ${log}
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/nf_l/density.nii.gz -thr 0.5 ${outdir}/nf_l_thr
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/nf_r/density.nii.gz -thr 0.5 ${outdir}/nf_r_thr

    echo "NF_l" >> ${log}
    fslstats ${outdir}/nf_l_thr -V >> ${log}

    echo "NF_r" >> ${log}
    fslstats ${outdir}/nf_r_thr -V >> ${log}

    fslmaths ${outdir}/nf_l_thr -sub ${stimulationfield_test} ${outdir}/nf_l_lesion
    fslmaths ${outdir}/nf_r_thr -sub ${stimulationfield_test} ${outdir}/nf_r_lesion

    echo "NF_l_lesion" >> ${log}
    fslstats ${outdir}/nf_l_lesion -V >> ${log}
    echo "" >> ${log}

    echo "NF_r_lesion" >> ${log}
    fslstats ${outdir}/nf_r_lesion -V >> ${log}
    echo "" >> ${log}

    echo "" >> ${log}


    #PF
    echo "PF" >> ${log}
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/pf_l/density.nii.gz -thr 0.5 ${outdir}/pf_l_thr
    fslmaths ${basedir}/diffusion/dbsxtract/tracts/pf_r/density.nii.gz -thr 0.5 ${outdir}/pf_r_thr

    echo "PF_l" >> ${log}
    fslstats ${outdir}/pf_l_thr -V >> ${log}

    echo "PF_r" >> ${log}
    fslstats ${outdir}/pf_r_thr -V >> ${log}

    fslmaths ${outdir}/pf_l_thr -sub ${stimulationfield_test} ${outdir}/pf_l_lesion
    fslmaths ${outdir}/pf_r_thr -sub ${stimulationfield_test} ${outdir}/pf_r_lesion

    echo "PF_l_lesion" >> ${log}
    fslstats ${outdir}/pf_l_lesion -V >> ${log}
    echo "" >> ${log}

    echo "PF_r_lesion" >> ${log}
    fslstats ${outdir}/pf_r_lesion -V >> ${log}
    echo "" >> ${log}

    echo "" >> ${log}


    echo "" >> ${log}
    echo "All done with tracts" >> ${log}
    echo "" >> ${log}

else
    echo "Directory dbsxtract does not exist: exiting this analysis now"
    echo "Directory dbsxtract does not exists: exiting this analysis now" >> ${log}
fi


###################
# 2. Segmentation #
###################


echo "" >> ${log}
echo "2. Segmentation analysis" >> ${log}
echo "" >> ${log}


#Cluster

if [ ! -d ${basedir}/diffusion/thalamus2cortex_left_cluster ] ;
then
    echo "Directory thalamus2cortex_left_cluster exists: performing tract based analysis"
    echo "Directory thalamus2cortex_left_cluster exists: performing tract based analysis" >> ${log}
    
    #baseline analysis
    echo "Cluster 21 left" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_21.nii.gz -V >> ${log}
    echo "Cluster 23 left" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_23.nii.gz -V >> ${log}
    echo "Cluster 27 left" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_27.nii.gz -V >> ${log}
    echo "Cluster dentate right" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_dentate_right.nii.gz -V >> ${log}
    echo "" >> ${log}
    
    #lesioned analysis
    echo "Cluster 21 left lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_21.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_21_left_lesioned.nii.gz
    fslstats ${outdir}/cluster_21_left_lesioned.nii.gz -V >> ${log}
    echo "Cluster 23 left lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_23.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_23_left_lesioned.nii.gz
    fslstats ${outdir}/cluster_23_left_lesioned.nii.gz -V >> ${log}
    echo "Cluster 27 left lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_27.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_27_left_lesioned.nii.gz
    fslstats ${outdir}/cluster_27_left_lesioned.nii.gz -V >> ${log}
    echo "Cluster dentate right lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_left_cluster/cluster_dentate_right.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_dentate_right_lesioned.nii.gz
    fslstats ${outdir}/cluster_dentate_right_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}

else
    echo "Directory thalamus2cortex_left_cluster does not exist: exiting this analysis now"
    echo "Directory thalamus2cortex_left_cluster does not exist: exiting this analysis now" >> ${log}
fi
    

if [ ! -d ${basedir}/diffusion/thalamus2cortex_right_cluster ] ;
then
    echo "Directory thalamus2cortex_right_cluster exists: performing tract based analysis"
    echo "Directory thalamus2cortex_right_cluster exists: performing tract based analysis" >> ${log}
    
    echo "Cluster 21 right" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_21.nii.gz -V >> ${log}
    echo "Cluster 23 right" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_23.nii.gz -V >> ${log}
    echo "Cluster 27 right" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_27.nii.gz -V >> ${log}
    echo "Cluster dentate left" >> ${log}
    fslstats ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_dentate_left.nii.gz -V >> ${log}
    echo "" >> ${log}
    
    #lesioned analysis
    echo "Cluster 21 right lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_21.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_21_right_lesioned.nii.gz
    fslstats ${outdir}/cluster_21_right_lesioned.nii.gz -V >> ${log}
    echo "Cluster 23 right lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_23.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_23_right_lesioned.nii.gz
    fslstats ${outdir}/cluster_23_right_lesioned.nii.gz -V >> ${log}
    echo "Cluster 27 right lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_27.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_27_right_lesioned.nii.gz
    fslstats ${outdir}/cluster_27_right_lesioned.nii.gz -V >> ${log}
    echo "Cluster dentate left lesioned" >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_right_cluster/cluster_dentate_left.nii.gz -sub ${stimulationfield_test} ${outdir}/cluster_dentate_left_lesioned.nii.gz
    fslstats ${outdir}/cluster_dentate_left_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}

else
    echo "Directory thalamus2cortex_right_cluster does not exist: exiting this analysis now"
    echo "Directory thalamus2cortex_right_cluster does not exist: exiting this analysis now" >> ${log}
fi


#Hard segmentation

if [ ! -f ${basedir}/diffusion/thalamus2cortex_left/biggest_segmentation.nii.gz ] ;
then
    echo "Directory thalamus2cortex_left exists: performing tract based analysis"
    echo "Directory thalamus2cortex_left exists: performing tract based analysis" >> ${log}
    
    echo "Hard segmentation thalamus left" >> ${log}
    fslstats -K ${basedir}/diffusion/thalamus2cortex_left/biggest_segmentation.nii.gz -V >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_left/biggest_segmentation.nii.gz -sub ${stimulationfield_test} ${outdir}/biggest_segmentation_left_lesioned.nii.gz
    fslstats -K ${outdir}/biggest_segmentation_left_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}
    
else
    echo "Directory thalamus2cortex_left does not exist: exiting this analysis now"
    echo "Directory thalamus2cortex_left does not exist: exiting this analysis now" >> ${log}
fi


if [ ! -f ${basedir}/diffusion/thalamus2cortex_right/biggest_segmentation.nii.gz ] ;
then
    echo "Directory thalamus2cortex_right exists: performing tract based analysis"
    echo "Directory thalamus2cortex_right exists: performing tract based analysis" >> ${log}
    
    echo "Hard segmentation thalamus right" >> ${log}
    fslstats -K ${basedir}/diffusion/thalamus2cortex_right/biggest_segmentation.nii.gz -V >> ${log}
    fslmaths ${basedir}/diffusion/thalamus2cortex_right/biggest_segmentation.nii.gz -sub ${stimulationfield_test} ${outdir}/biggest_segmentation_right_lesioned.nii.gz
    fslstats -K ${outdir}/biggest_segmentation_right_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}
    
else
    echo "Directory thalamus2cortex_right does not exist: exiting this analysis now"
    echo "Directory thalamus2cortex_right does not exist: exiting this analysis now" >> ${log}
fi


#kmeans

if [ ! -f ${basedir}/diffusion/thalamus2cortex_left_omatrix2/clusters.nii.gz ] ;
then
    echo "Directory thalamus2cortex_left_omatrix2/clusters.nii.gz exists: performing tract based analysis"
    echo "Directory thalamus2cortex_left_omatrix2/clusters.nii.gz exists: performing tract based analysis" >> ${log}
    
    echo "kmeans segmentation thalamus left" >> ${log}
       fslstats -K ${basedir}/diffusion/thalamus2cortex_left_omatrix2/clusters.nii.gz -V >> ${log}
       fslmaths ${basedir}/diffusion/thalamus2cortex_left_omatrix2/clusters.nii.gz -sub ${stimulationfield_test} ${outdir}/clusters_left_lesioned.nii.gz
       fslstats -K ${outdir}/clusters_left_lesioned.nii.gz -V >> ${log}
       echo "" >> ${log}
    
else
    echo "Directory thalamus2cortex_left/clusters.nii.gz does not exist: exiting this analysis now (check directories segmentation & clusters, batch scripts and slurm calls, matlab clusters analysis)"
    echo "Directory thalamus2cortex_left/clusters.nii.gz does not exist: exiting this analysis now" >> ${log}
fi


if [ ! -f ${basedir}/diffusion/thalamus2cortex_right_omatrix2/clusters.nii.gz ] ;
then
    echo "Directory thalamus2cortex_right_omatrix2/clusters.nii.gz exists: performing tract based analysis"
    echo "Directory thalamus2cortex_right_omatrix2/clusters.nii.gz exists: performing tract based analysis" >> ${log}
    
    echo "kmeans segmentation thalamus right" >> ${log}
       fslstats -K ${basedir}/diffusion/thalamus2cortex_right_omatrix2/clusters.nii.gz -V >> ${log}
       fslmaths ${basedir}/diffusion/thalamus2cortex_right_omatrix2/clusters.nii.gz -sub ${stimulationfield_test} ${outdir}/clusters_right_lesioned.nii.gz
       fslstats -K ${outdir}/clusters_right_lesioned.nii.gz -V >> ${log}
       echo "" >> ${log}
    
else
    echo "Directory thalamus2cortex_right/clusters.nii.gz does not exist: exiting this analysis now (check directories segmentation & clusters, batch scripts and slurm calls, matlab clusters analysis)"
    echo "Directory thalamus2cortex_right/clusters.nii.gz does not exist: exiting this analysis now" >> ${log}
fi


echo "" >> ${log}
echo "All done with segmentation" >> ${log}
echo "" >> ${log}


#################
# 3. Connectome #
#################


echo "" >> ${log}
echo "3. Connectome analysis" >> ${log}
echo "" >> ${log}



if [ ! -d ${basedir}/diffusion/connectome_modules_left ] ;
then
    echo "Directory connectome_modules_left exists: performing tract based analysis"
    echo "Directory connectome_modules_left exists: performing tract based analysis" >> ${log}
    
    echo "Module-based hard segmentation thalamus left" >> ${log}
    fslstats -K ${basedir}/diffusion/connectome_modules_left/biggest_segmentation.nii.gz -V >> ${log}
    fslmaths ${basedir}/diffusion/connectome_modules_left/biggest_segmentation.nii.gz -sub ${stimulationfield_test} ${outdir}/module_segmentation_left_lesioned.nii.gz
    fslstats -K ${outdir}/module_segmentation_left_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}
    
else
    echo "Directory connectome_modules_left does not exist: exiting this analysis now"
    echo "Directory connectome_modules_left does not exist: exiting this analysis now" >> ${log}
fi


if [ ! -d ${basedir}/diffusion/connectome_modules_right ] ;
then
    echo "Directory connectome_modules_right exists: performing tract based analysis"
    echo "Directory connectome_modules_right exists: performing tract based analysis" >> ${log}
    
    echo "Module-based hard segmentation thalamus right" >> ${log}
    fslstats -K ${basedir}/diffusion/connectome_modules_right/biggest_segmentation.nii.gz -V >> ${log}
    fslmaths ${basedir}/diffusion/connectome_modules_right/biggest_segmentation.nii.gz -sub ${stimulationfield_test} ${outdir}/module_segmentation_right_lesioned.nii.gz
    fslstats -K ${outdir}/module_segmentation_right_lesioned.nii.gz -V >> ${log}
    echo "" >> ${log}
    
else
    echo "Directory connectome_modules_right does not exist: exiting this analysis now"
    echo "Directory connectome_modules_right does not exist: exiting this analysis now" >> ${log}
fi


echo "" >> ${log}
echo "All done with connectome" >> ${log}
echo "" >> ${log}


############
# Round up #
############


echo "" >> ${log}
echo "all done with tract_stats.sh"
echo "all done with tract_stats.sh" >> ${log}
echo $(date) >> ${log}
echo "" >> ${log}
