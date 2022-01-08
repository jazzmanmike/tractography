#!/bin/bash

#  bit_segmentation.sh
#  
#  Quick script for running segmentation analyses separate from tract_van.sh
#  Atlases include:
#   Desikan-Killiany (individual segmentation, from FreeSurfer): cluster based segmentation, thalamus only
#   Yeo7: hard segmentation & kmeans, thalamus & pallidum
#   Can also run with custom atlas too
#
#  Created by Michael Hart on 05/11/2020.
#

#################

#Set up

#################


#remove me from tract_van.sh
tempdir=`pwd`
echo ${tempdir}
codedir=${HOME}/code/github/tractography
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard

#make log
test -f bit_segmentation_log.txt && rm bit_segmentation_log.txt
touch ${tempdir}/bit_segmentation_log.txt
log=${tempdir}/bit_segmentation_log.txt

echo $(date) >> ${log}
echo "starting bit_segmentation" >> ${log}
echo "workingdir is ${tempdir}" >> ${log}
echo "codedir is ${codedir}" >> ${log}


#########

#Template

#########


#define atlas: fill in & uncomment as required
#atlas=
#atlas=${tempdir}/dkn_volume_MNI_seq.nii.gz
#atlas=${codedir}/templates/Yeo7.nii.gz
#echo ${atlas}


#########

#1. Other

#########


if [ $(imtest ${atlas}) == 1 ] ;
then
    echo "${atlas} dataset for segmentation ok"
    echo "Doing separate ${atlas} segmentation analysis (nb: code to be added)"
fi


######

#2. DK

######


if [ $(imtest dkn_volume_MNI_seq) == 1 ] ;
then
    echo "DKN_volume_MNI_seq template already made"
    echo "DKN_volume_MNI_seq template already made" >> ${log}
    atlas=${tempdir}/dkn_volume_MNI_seq.nii.gz

else
    echo "making DK_volume_MNI_seq"
    echo "making DK_volume_MNI_seq" >> ${log}
    echo $(date) >> ${log}
    
    #Set up DK: work in 'diffusion' directory
    SUBJECTS_DIR=`pwd`
    mri_aparc2aseg --s FS --annot aparc
    mri_convert ./FS/mri/aparc+aseg.mgz dkn_volume.nii.gz
    fslreorient2std dkn_volume.nii.gz dkn_volume.nii.gz

    #Registration

    flirt -in dkn_volume.nii.gz -ref ${codedir}/templates/500.sym_4mm.nii.gz -o dkn_volume_check -dof 12 -interp nearestneighbour

    #Renumber sequentially
    file_matlab=temp_DK_renumDesikan
    echo "Matlab file is: ${file_matlab}.m"
    echo "Matlab file variable is: ${file_matlab}"

    echo "renumDesikan_sub('dkn_volume_MNI.nii.gz', 0);exit" > ${file_matlab}.m
    matlab -nodisplay -r "${file_matlab}"

    #end DK setup
    echo "dkn_volume_MNI_seq now made"
    echo "dkn_volume_MNI_seq now made" >> ${log}
    echo $(date) >> ${log}
    atlas=${tempdir}/dkn_volume_MNI_seq.nii.gz

fi


#Define atlas
if [ $(imtest $atlas) == 1 ] ;
then
    echo "${atlas} dataset ok"
fi


#Not for DK! (mask atlas by hemisphere)

if [[ ! -d ${tempdir}/segmentation ]] ;
then
    mkdir -p ${tempdir}/segmentation
fi

cd segmentation
cp ${atlas} .
outname=`basename ${atlas} .nii.gz` #for parsing outputs
#fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
#fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

#Split atlas into individual ROI files
echo "running deparcellator.sh ${outname}"
echo "running deparcellator.sh ${outname}" >> ${log}
deparcellator.sh ${outname}

#Add dentate to list
echo "${codedir}/templates/dentate_left.nii.gz" >> ${outname}_seeds/seeds_targets_list.txt
echo "${codedir}/templates/dentate_right.nii.gz" >> ${outname}_seeds/seeds_targets_list.txt

cd ../

    
#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-R_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/thalamus_right_MNI.nii.gz

fslmaths ${tempdir}/segmentation/thalamus_right_MNI.nii.gz -bin ${tempdir}/segmentation/thalamus_right_MNI.nii.gz

#Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
applywarp --in=${tempdir}/first_segmentation/first-L_Thal_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/thalamus_left_MNI.nii.gz

fslmaths ${tempdir}/segmentation/thalamus_left_MNI.nii.gz -bin ${tempdir}/segmentation/thalamus_left_MNI.nii.gz


#Thalamus: DK, R+L, cluster


#Right thalamus

#If DK segmentation run pull out, otherwise make call
if [[ -d ${tempdir}/thalamus2cortex_right_cluster ]] ;
then
    echo "DK cluster segmentation already run on right"
    echo "DK cluster segmentation already run on right" >> ${log}
else
    echo "Running DK cluster segmentation on right"
    echo "Running DK cluster segmentation on right" >> ${log}
    
    #Seed to target
    touch ${tempdir}/batch_thalamus2cortex_right_cluster.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_right_cluster.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right_cluster \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_right_cluster.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_right_cluster.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_right_cluster.sh
    
fi


#Left thalamus

#If DK segmentation run pull out, otherwise make call
if [[ -d ${tempdir}/thalamus2cortex_left_cluster ]] ;
then
    echo "DK cluster segmentation already run on left"
    echo "DK cluster segmentation already run on left" >> ${log}
else
    echo "Running DK cluster segmentation on left"
    echo "Running DK cluster segmentation on left" >> ${log}
    
    #Seed to target
    touch ${tempdir}/batch_thalamus2cortex_left_cluster.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_left_cluster.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left_cluster \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_left_cluster.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_left_cluster.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_left_cluster.sh

fi


#######

#3. Yeo

#######


atlas="${codedir}/templates/Yeo7.nii.gz"

#Mask atlas by hemisphere (faster & avoids conflict with connectome)
if [[ ! -d ${tempdir}/segmentation ]] ;
then
    echo "making new segmentation directory"
    mkdir -p ${tempdir}/segmentation
fi

cd segmentation
cp ${atlas} .
outname=`basename ${atlas} .nii.gz` #for parsing outputs
fslmaths ${atlas} -mas ${codedir}/templates/right_brain.nii.gz ${outname}_right
fslmaths ${atlas} -mas ${codedir}/templates/left_brain.nii.gz ${outname}_left

#Split atlas into individual ROI files
echo "running deparcellator ${outname}"
echo "running deparcellator ${outname}" >> ${log}
deparcellator.sh ${outname}_right
deparcellator.sh ${outname}_left

cd ../


#Start segmentation: thalamus then pallidum, right then left
#NB: nsamples set to 5000 at start


#Hard segmentation


#Thalamus


#Right thalamus: hard segmentation

if [[ -d ${tempdir}/thalamus2cortex_right/ ]] && [[ -d ${tempdir}/segmentation/${outname}_right_seeds/ ]] ;
then
    echo "Hard segmentation of right thalamus already run with: ${outname}"
    echo "Hard segmentation of right thalamus already run with: ${outname}" >> ${log}
else
    echo "Running hard segmentation of right thalamus with: ${outname}"
    echo "Running hard segmentation of right thalamus with: ${outname}" >> ${log}

    #Seed to target
    
    touch ${tempdir}/batch_thalamus2cortex_right.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_right.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_right.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_right.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_right.sh
    
    #Run find_the_biggest later

fi


#Left thalamus: hard segmentation

if [[ -d ${tempdir}/thalamus2cortex_left/ ]] && [[ -d ${tempdir}/segmentation/${outname}_left_seeds/ ]] ;
then
    echo "Hard segmentation of left thalamus already run with: ${outname}"
    echo "Hard segmentation of left thalamus already run with: ${outname}" >> ${log}
else

    echo "Running hard segmentation left thalamus with: ${outname}"
    echo "Running hard segmentation left thalamus with: ${outname}" >> ${log}

    #Seed to target
    touch ${tempdir}/batch_thalamus2cortex_left.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_left.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=thalamus2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_left.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_left.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_left.sh
           
    #Run find_the_biggest later

fi


#Pallidum


#Right pallidum: hard segmentation

if [[ -d ${tempdir}/pallidum2cortex_right/ ]] && [[ -d ${tempdir}/segmentation/${outname}_right_seeds/ ]] ;
then
    echo "Hard segmentation of right pallidum already run with: ${outname}"
    echo "Hard segmentation of right pallidum already run with: ${outname}" >> ${log}
else

    echo "Running hard segmentation right pallidum with: ${outname}"
    echo "Running hard segmentation right pallidum with: ${outname}" >> ${log}
   
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-R_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/pallidum_right_MNI.nii.gz

    fslmaths ${tempdir}/segmentation/pallidum_right_MNI.nii.gz -bin ${tempdir}/segmentation/pallidum_right_MNI.nii.gz

    #Seed to target
    touch ${tempdir}/batch_pallidum2cortex_right.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_pallidum2cortex_right.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/pallidum_right_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_right_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_right \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_pallidum2cortex_right.sh
    chmod 777 ${tempdir}/batch_pallidum2cortex_right.sh
    sbatch --time=3:00:00 ${tempdir}/batch_pallidum2cortex_right.sh

    #run find_the_biggest at end
    
fi


#Left pallidum: hard segmentation

if [[ -d ${tempdir}/pallidum2cortex_left/ ]] && [[ -d ${tempdir}/segmentation/${outname}_left_seeds/ ]] ;
then
    echo "Hard segmentation of left pallidum already run with: ${outname}"
    echo "Hard segmentation of left pallidum already run with: ${outname}" >> ${log}
else

    echo "Running hard segmentation left pallidum with: ${outname}"
    echo "Running hard segmentation left pallidum with: ${outname}" >> ${log}
   
    #Move individual nucleus (seed) to be segmentated to standard space (i.e. same as target parcellation / atlas)
    applywarp --in=${tempdir}/first_segmentation/first-L_Pall_first.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/pallidum_left_MNI.nii.gz

    fslmaths ${tempdir}/segmentation/pallidum_left_MNI.nii.gz -bin ${tempdir}/segmentation/pallidum_left_MNI.nii.gz

    #Seed to target
    touch ${tempdir}/batch_pallidum2cortex_left.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_pallidum2cortex_left.sh
    echo "probtrackx2 --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seedref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz \
    --seed=${tempdir}/segmentation/pallidum_left_MNI.nii.gz \
    --targetmasks=${tempdir}/segmentation/${outname}_left_seeds/seeds_targets_list.txt \
    --dir=pallidum2cortex_left \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --os2t \
    --nsamples=5000" >> ${tempdir}/batch_pallidum2cortex_left.sh
    chmod 777 ${tempdir}/batch_pallidum2cortex_left.sh
    sbatch --time=3:00:00 ${tempdir}/batch_pallidum2cortex_left.sh

    #run find_the_biggest at end

fi


#do actual segmentation at the end: pause to allow completion of probtrackx2 call
echo "Sleep after sbatch calls"
echo "Sleep after sbatch calls" >> ${log}
echo $(date) >> ${log}
sleep 10h
echo "Resuming after sleep"
echo "Resuming after sleep" >> ${log}
echo $(date) >> ${log}


##########

#4. kmeans

##########


#Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation


#Make grey matter mask in MNI space
#Use ANTS preferentially
if [[ -f $tempdir}/ACT/CorticalThicknessNormalizedToTemplate.nii.gz ]] ;
then
    fslmaths ${tempdir}/ACT/CorticalThicknessNormalizedToTemplate.nii.gz -bin ${tempdir}/segmentation/GM_mask_MNI.nii.gz
else
    #Otherwise use FSL
    applywarp --in=${tempdir}/structural.anat/T1_fast_pve_1.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain --warp=${tempdir}/diffusion.bedpostX/xfms/str2standard_warp --out=${tempdir}/segmentation/GM_mask_MNI
    #binarise
    fslmaths ${tempdir}/segmentation/GM_mask_MNI -thr 0.5 ${tempdir}/segmentation/GM_mask_MNI #generous threshold
fi


#Right thalamus: kmeans


if [[ -d ${tempdir}/thalamus2cortex_right_omatrix2/ ]] && [[ -d ${tempdir}/segmentation/${outname}_right_seeds/ ]] ;
then
    echo "kmeans of right thalamus already run with: ${outname}"
    echo "kmeans of right thalamus already run with: ${outname}" >> ${log}
else
    echo "Running kmeans segmentation of right thalamus with: ${outname}"
    echo "Running kmeans segmentation of right thalamus with: ${outname}" >> ${log}

    #omatrix2
    
    touch ${tempdir}/batch_thalamus2cortex_right_omatrix2.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_right_omatrix2.sh
    echo "probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/segmentation/thalamus_right_MNI.nii.gz \
    --target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_right_omatrix2.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_right_omatrix2.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_right_omatrix2.sh
    
fi


#Left thalamus: kmeans

if [[ -d ${tempdir}/thalamus2cortex_left_omatrix2/ ]] && [[ -d ${tempdir}/segmentation/${outname}_left_seeds/ ]] ;
then
    echo "kmeans of left thalamus already run with: ${outname}"
    echo "kmeans of left thalamus already run with: ${outname}" >> ${log}
else
    echo "Running kmeans segmentation of left thalamus with: ${outname}"
    echo "Running kmeans segmentation of left thalamus with: ${outname}" >> ${log}
    
    #omatrix2
    touch ${tempdir}/batch_thalamus2cortex_left_omatrix2.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_thalamus2cortex_left_omatrix2.sh
    echo "probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/segmentation/thalamus_left_MNI.nii.gz \
    --target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
    --dir=thalamus2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000" >> ${tempdir}/batch_thalamus2cortex_left_omatrix2.sh
    chmod 777 ${tempdir}/batch_thalamus2cortex_left_omatrix2.sh
    sbatch --time=3:00:00 ${tempdir}/batch_thalamus2cortex_left_omatrix2.sh

fi


#Right pallidum: kmeans

if [[ -d ${tempdir}/pallidum2cortex_right_omatrix2/ ]] && [[ -d ${tempdir}/segmentation/${outname}_right_seeds/ ]] ;
then
    echo "kmeans of right pallidum already run with: ${outname}"
    echo "kmeans of right pallidum already run with: ${outname}" >> ${log}
else
    echo "Running kmeans segmentation of right pallidum with: ${outname}"
    echo "Running kmeans segmentation of right pallidum with: ${outname}" >> ${log}
   
    #Alternative segmentation method (hypothesis free): requires subsequent Matlab run for kmeans segmentation

    #omatrix2
    touch ${tempdir}/batch_pallidum2cortex_right_omatrix2.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_pallidum2cortex_right_omatrix2.sh
    echo "probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/segmentation/pallidum_right_MNI.nii.gz \
    --target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
    --dir=pallidum2cortex_right_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000" >> ${tempdir}/batch_pallidum2cortex_right_omatrix2.sh
    chmod 777 ${tempdir}/batch_pallidum2cortex_right_omatrix2.sh
    sbatch --time=3:00:00 ${tempdir}/batch_pallidum2cortex_right_omatrix2.sh

fi


#Left pallidum: kmeans
if [[ -d ${tempdir}/pallidum2cortex_left_omatrix2/ ]] && [[ -d ${tempdir}/segmentation/${outname}_left_seeds/ ]] ;
then
    echo "kmeans of left pallidum already run with: ${outname}"
    echo "kmeans of left pallidum already run with: ${outname}" >> ${log}
else
    echo "Running kmeans segmentation of left pallidum with: ${outname}"
    echo "Running kmeans segmentation of left pallidum with: ${outname}" >> ${log}
   
    #omatrix2
    touch ${tempdir}/batch_pallidum2cortex_left_omatrix2.sh
    echo "#!/bin/bash" >> ${tempdir}/batch_pallidum2cortex_left_omatrix2.sh
    echo "probtrackx2 --omatrix2 \
    --samples=${tempdir}/diffusion.bedpostX/merged \
    --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
    --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
    --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
    --seed=${tempdir}/segmentation/pallidum_left_MNI.nii.gz \
    --target2=${tempdir}/segmentation/GM_mask_MNI.nii.gz \
    --dir=pallidum2cortex_left_omatrix2 \
    --loopcheck \
    --onewaycondition \
    --forcedir \
    --opd \
    --nsamples=5000" >> ${tempdir}/batch_pallidum2cortex_left_omatrix2.sh
    chmod 777 ${tempdir}/batch_pallidum2cortex_left_omatrix2.sh
    sbatch --time=3:00:00 ${tempdir}/batch_pallidum2cortex_left_omatrix2.sh

fi



################################

## 5. Post tractography analysis

################################


#Cluster

echo "Running clustering"
echo "Running clustering" >> ${log}

#right thalamus
#68 parcels (no subcortical)
#61, 57, 55 [-7 -11 -13] SMA-PMC/M1/S1 right
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0061.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_61
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0057.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_57
cluster --in=thalamus2cortex_right_cluster/seeds_to_Seg0055.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_55
cluster --in=thalamus2cortex_right_cluster/seeds_to_dentate_left.nii.gz --thresh=100 --othresh=thalamus2cortex_right_cluster/cluster_dentate_left

#left thalamus
#68 parcels (no subcortical)
#27, 23, 21 [-7 -11 -13] SMA-PMC/M1/S1 left
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0027.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_27
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0023.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_23
cluster --in=thalamus2cortex_left_cluster/seeds_to_Seg0021.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_21
cluster --in=thalamus2cortex_left_cluster/seeds_to_dentate_right.nii.gz --thresh=100 --othresh=thalamus2cortex_left_cluster/cluster_dentate_right


#Hard segmentation

echo "Running hard segmentation"
echo "Running hard segmentation" >> ${log}

#right thalamus
find_the_biggest thalamus2cortex_right/seeds_to_* thalamus2cortex_right/biggest_segmentation
#left thalamus
find_the_biggest thalamus2cortex_left/seeds_to_* thalamus2cortex_left/biggest_segmentation
#right pallidum
find_the_biggest pallidum2cortex_right/seeds_to_* pallidum2cortex_right/biggest_segmentation
#left pallidum
find_the_biggest pallidum2cortex_left/seeds_to_* pallidum2cortex_left/biggest_segmentation


#kmeans

echo "Running kmeans"
echo "Running kmeans" >> ${log}

#right thalamus
cd thalamus2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#left thalamus
cd thalamus2cortex_left_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#right pallidum
cd pallidum2cortex_right_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..

#left pallidum
cd pallidum2cortex_left_omatrix2
file_matlab=temp_Segmentation
echo "segmentation_clustering;exit" > ${file_matlab}.m
matlab -nodisplay -r "${file_matlab}"
fslcpgeom fdt_paths clusters
cd ..


echo "Cleanup of slurm* files"
echo "Cleanup of slurm* files" >> ${log}

rm slurm*
rm batch*

echo $(date) >> ${log}
echo "all done with bit_segmentation"
echo "all done with bit_segmentation" >> ${log}

#fin
