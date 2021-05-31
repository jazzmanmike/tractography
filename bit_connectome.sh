#!/bin/bash

#  bit_connectome.sh
#
#  Test for runnning x3 DTI connectome calls separate from tract_van.sh
#  Atlases used include:
#   Desikan-Killiany (individual segmentation, from FreeSurfer)
#   AAL90 (cortical)
#   Custom randomised iso-volumetric
#   Can also add a separate template too
#
#  Created by Michael Hart on 11/11/2020.
#

#################

#Set up

#################


#test me then remove me***

tempdir=`pwd`
codedir=${HOME}/code/github/tractography
template=#only set up for a single specific run
FSLOUTPUTTYPE=NIFTI_GZ #occassionally not set as standard
parallel=1;
test -f bit_connectome_log.txt && rm bit_connectome_log.txt
touch bit_connectome_log.txt
log=bit_connectome_log.txt
echo $(date) >> ${log}


#################

#1. DK

#################


#If DK_volume_seq doesn't exist make it

if [ $(imtest dkn_volume_MNI_seq) == 1 ] ;
then
    echo "DKN_volume_MNI_seq template already made"
    echo "DKN_volume_MNI_seq template already made" >> ${log}
    template=${tempdir}/dkn_volume_MNI_seq.nii.gz
    
else
    
    echo "making DKN_volume_MNI_seq"
    echo "making DKN_volume_MNI_seq" >> ${log}
    
    #Set up DK: work in 'diffusion' directory
    SUBJECTS_DIR=`pwd`
    mri_aparc2aseg --s FS --annot aparc
    mri_convert ./FS/mri/aparc+aseg.mgz dkn_volume.nii.gz
    fslreorient2std dkn_volume.nii.gz dkn_volume.nii.gz

    #Registration

    #flirt affine
    flirt -in dkn_volume.nii.gz -ref ${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz -omat dkn_affine.mat -dof 12
    
    #fnirt
    fnirt --in=dkn_volume.nii.gz --aff=dkn_affine.mat --cout=dkn2mni_warp --config=T1_2_MNI152_2mm
    
    #applyxfm
    applywarp --in=dkn_volume.nii.gz --ref=${FSLDIR}/data/standard/MNI152_T1_2mm_brain.nii.gz --warp=dkn2mni_warp --out=dkn_volume_MNI.nii.gz --interp=nn

    #Renumber sequentially
    file_matlab=temp_DK_renumDesikan
    echo "Matlab file is: ${file_matlab}.m"
    echo "Matlab file variable is: ${file_matlab}"

    echo "renumDesikan_sub('dkn_volume_MNI.nii.gz', 0);exit" > ${file_matlab}.m
    matlab -nodisplay -r "${file_matlab}"

    #end DK setup
    template=${tempdir}/dkn_volume_MNI_seq.nii.gz

fi


#If DK exists (in probtrackx) pull out, otherwise make call

echo "template is: ${template}"
echo "template is: ${template}" >> ${log}
echo $(date) >> ${log}

outname=`basename ${template} .nii.gz`
echo "outname is: ${outname}"
echo "outname is: ${outname}" >> ${log}

if [[ -d ${tempdir}/probtrackx/${outname} ]] ;
then

    echo "${template} template connectome already run in probtrackx directory"
    echo "${template} template connectome already run in probtrackx directory" >> ${log}

else

    maxParcel=`fslstats ${template} -R | awk '{print $2}'`
    numParcels=`printf "%0.0f\n" $maxParcel`
    echo "numParcels: ${numParcels}"
    echo "numParcels: ${numParcels}" >> ${log}

    #mask template by gray matter: optional - not for DK
    #fslmaths ${template} -mul ${tempdir}/hardsegmentation/GM_mask_MNI ${template}

    #generate list of seeds
    #make new each time (for path continuity)
    if [[ -d ${tempdir}/${outname}_seeds/ ]] ; then rm -r ${tempdir}/${outname}_seeds/; fi
    echo "${template}: making seeds & seeds_list"
    echo "${template}: making seeds & seeds_list" >> ${log}
    deparcellator.sh ${template}

    if [ "${parallel}" == 1 ] ;
    then
        echo "Running probtrackx connectome in parallel"
        echo "Running probtrackx connectome in parallel" >> ${log}

        #1. Generate scripts

        mkdir -p ${tempdir}/probtrackx/${outname}/commands/

        if [ ! -f ${tempdir}/probtrackx/${outname}/commands/Seg`printf %04d $numParcels`.sh ] ;
        then
            echo "Generating tractography scripts"
            echo "Generating tractography scripts" >> ${log}
            for region in `cat  ${tempdir}/${outname}_seeds/seeds_targets_list.txt`;
            do
                region_name=`basename ${region} .nii.gz`
                touch ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "#!/bin/bash" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "probtrackx2 \
                --samples=${tempdir}/diffusion.bedpostX/merged \
                --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
                --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
                --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
                --seed=${region} \
                --dir=${tempdir}/probtrackx/${outname}/${region_name}/ \
                --targetmasks=${tempdir}/${outname}_seeds/seeds_targets_list.txt \
                --s2tastext \
                --pd \
                --loopcheck \
                --forcedir \
                --opd \
                --os2t \
                --nsamples=500" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            done
        else
            echo "Tractography scripts have been made already."
            echo "Tractography scripts have been made already." >> ${log}
        fi

        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


        #2. Submit to cluster

        if [ "${seedFinished}" != "{$numParcels}" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
        then
            echo "Submitting tractography scripts to cluster"
            echo "Submitting tractography scripts to cluster" >> ${log}
            chmod 777 ${tempdir}/probtrackx/${outname}/commands/*
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
                num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
                seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
                seg_id2=`echo $seg_id | sed "s/...$//g"`
                if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ]
                then
                    sbatch --time=1:00:00 ${cmdFiles}
                    sleep 10
                fi
            done

            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts."
            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts." >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})."
            echo "Check number of jobs finished (number of parcels=${numParcels})." >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "going to sleep to wait for parcels to finish: 6h"
            echo "going to sleep to wait for parcels to finish: 6h" >> ${log}
            sleep 6h

        else
            echo "Tractography scripts have finished running on cluster already"
            echo "Tractography scripts have finished running on cluster already" >> ${log}
        fi


        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        
        #3. Check all tractography scripts have run (& re-submit if not)
        
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}"
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}" >> ${log}
        
        iteration=1
        
        while [ "${seedFinished}" != "${numParcels}" ] ;
        do
            
            echo "Number of jobs finished: ${seedFinished}"
            echo "Number of jobs finished: ${seedFinished}" >> ${log}
            
            echo "iteration = ${iteration}"
            echo "iteration = ${iteration}" >> ${log}
            
            echo "Re-submitting incomplete tractography scripts to cluster"
            echo "Re-submitting incomplete tractography scripts to cluster" >> ${log}
            
            echo "(partial) cleanup of intermediary files"
            echo "(partial) cleanup of intermediary files" >> ${log}
            
            rm -r slurm*
            
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
               num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
               seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
               seg_id2=`echo $seg_id | sed "s/...$//g"`
               if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ] ;
               then
                   sbatch --time=1:00:00 ${cmdFiles}
                   echo "re-submitting ${seg_id2}"
                   echo "re-submitting ${seg_id2}" >> ${log}
                   sleep 10
               fi
            done

            echo "Tractography jobs re-submitted to the cluster"
            echo "Tractography jobs re-submitted to the cluster" >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})"
            echo "Check number of jobs finished (number of parcels=${numParcels})" >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "Going to sleep (again) to wait for parcels to finish: 6h"
            echo "Going to sleep (again) to wait for parcels to finish: 6h" >> ${log}
            sleep 6h
            
            iteration=`echo $iteration + 1 | bc`;
            seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        done
               
               
        #4. Merge tracts
        
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg"
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg" >> ${log}

        if [ ! -f ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg ] ;
        then
            echo "Making mergeTracts.m file"
            echo "Making mergeTracts.m file" >> ${log}
            file_matlab=temp_${numParcels}_mergeTracts

            echo "mergeTracts('${tempdir}/','${outname}');exit" > ${file_matlab}.m

            matlab -nodisplay -r "${file_matlab}"
        
            mkdir -p ${tempdir}/probtrackx/${outname}/connectome
            mv ${tempdir}/probtrackx/${outname}/connectivity* ${tempdir}/probtrackx/${outname}/connectome/
        
            echo "Connectome tractography complete without errors!"
            echo "Connectome tractography complete without errors!" >> ${log}
            
            echo "cleanup of intermediary files"
            echo "cleanup of intermediary files" >> ${log}

            rm -r slurm* probtrackx/${outname}/Seg* probtrackx/${outname}/commands ${outname}_seeds/Seg*
                                
        else
        
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/"
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/" >> ${log}
        
        fi

    else #parallel loop at start
    
        echo "Running probtrackx connectome sequentially with --network option"
        #this shouldn't run either!
        #echo "Starting connectome sequentially with --network option" >> $log
        #echo "" >> $log

        #only 500 seeds and no option '-opd'
        probtrackx2 \
        --network \
        --samples=${tempdir}/diffusion.bedpostX/merged \
        --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
        --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
        --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
        --dir=${outname} \
        --seed=${outname}_seeds/seeds_targets_list.txt \
        --loopcheck \
        --onewaycondition \
        --forcedir \
        --nsamples=500

    fi

fi


#########

#2. AAL90

#########


template="${codedir}/templates/AAL90.nii.gz"

outname=`basename ${template} .nii.gz`
echo "outname is: ${outname}"
echo "outname is: ${outname}" >> ${log}

if [[ -d ${tempdir}/probtrackx/${outname} ]] ;
then

    echo "${template} template connectome already run in probtrackx directory"
    echo "${template} template connectome already run in probtrackx directory" >> ${log}

else

    maxParcel=`fslstats ${template} -R | awk '{print $2}'`
    numParcels=`printf "%0.0f\n" $maxParcel`
    echo "numParcels: ${numParcels}"
    echo "numParcels: ${numParcels}" >> ${log}

    #mask template by gray matter: optional - not for DK
    #fslmaths ${template} -mul ${tempdir}/hardsegmentation/GM_mask_MNI ${template}

    #generate list of seeds
    #make new each time (for path continuity)
    if [[ -d ${tempdir}/${outname}_seeds/ ]] ; then rm -r ${tempdir}/${outname}_seeds/; fi
    echo "${template}: making seeds & seeds_list"
    echo "${template}: making seeds & seeds_list" >> ${log}
    deparcellator.sh ${template}

    if [ "${parallel}" == 1 ] ;
    then
        echo "Running probtrackx connectome in parallel"
        echo "Running probtrackx connectome in parallel" >> ${log}

        #1. Generate scripts

        mkdir -p ${tempdir}/probtrackx/${outname}/commands/

        if [ ! -f ${tempdir}/probtrackx/${outname}/commands/Seg`printf %04d $numParcels`.sh ] ;
        then
            echo "Generating tractography scripts"
            echo "Generating tractography scripts" >> ${log}
            for region in `cat  ${tempdir}/${outname}_seeds/seeds_targets_list.txt`;
            do
                region_name=`basename ${region} .nii.gz`
                touch ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "#!/bin/bash" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "probtrackx2 \
                --samples=${tempdir}/diffusion.bedpostX/merged \
                --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
                --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
                --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
                --seed=${region} \
                --dir=${tempdir}/probtrackx/${outname}/${region_name}/ \
                --targetmasks=${tempdir}/${outname}_seeds/seeds_targets_list.txt \
                --s2tastext \
                --pd \
                --loopcheck \
                --forcedir \
                --opd \
                --os2t \
                --nsamples=500" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            done
        else
            echo "Tractography scripts have been made already."
            echo "Tractography scripts have been made already." >> ${log}
        fi

        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


        #2. Submit to cluster

        if [ "${seedFinished}" != "{$numParcels}" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
        then
            echo "Submitting tractography scripts to cluster"
            echo "Submitting tractography scripts to cluster" >> ${log}
            chmod 777 ${tempdir}/probtrackx/${outname}/commands/*
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
                num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
                seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
                seg_id2=`echo $seg_id | sed "s/...$//g"`
                if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ]
                then
                    sbatch --time=1:00:00 ${cmdFiles}
                    sleep 10
                fi
            done

            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts."
            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts." >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})."
            echo "Check number of jobs finished (number of parcels=${numParcels})." >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "going to sleep to wait for parcels to finish: 6h"
            echo "going to sleep to wait for parcels to finish: 6h" >> ${log}
            sleep 6h

        else
            echo "Tractography scripts have finished running on cluster already"
            echo "Tractography scripts have finished running on cluster already" >> ${log}
        fi


        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        
        #3. Check all tractography scripts have run (& re-submit if not)
        
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}"
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}" >> ${log}
        
        iteration=1
        
        while [ "${seedFinished}" != "${numParcels}" ] ;
        do
            
            echo "Number of jobs finished: ${seedFinished}"
            echo "Number of jobs finished: ${seedFinished}" >> ${log}
            
            echo "iteration = ${iteration}"
            echo "iteration = ${iteration}" >> ${log}
            
            echo "Re-submitting incomplete tractography scripts to cluster"
            echo "Re-submitting incomplete tractography scripts to cluster" >> ${log}
            
            echo "(partial) cleanup of intermediary files"
            echo "(partial) cleanup of intermediary files" >> ${log}
            
            rm -r slurm*
            
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
               num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
               seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
               seg_id2=`echo $seg_id | sed "s/...$//g"`
               if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ] ;
               then
                   sbatch --time=1:00:00 ${cmdFiles}
                   echo "re-submitting ${seg_id2}"
                   echo "re-submitting ${seg_id2}" >> ${log}
                   sleep 10
               fi
            done

            echo "Tractography jobs re-submitted to the cluster"
            echo "Tractography jobs re-submitted to the cluster" >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})"
            echo "Check number of jobs finished (number of parcels=${numParcels})" >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "Going to sleep (again) to wait for parcels to finish: 6h"
            echo "Going to sleep (again) to wait for parcels to finish: 6h" >> ${log}
            sleep 6h
            
            iteration=`echo $iteration + 1 | bc`;
            seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        done
               
               
        #4. Merge tracts
        
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg"
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg" >> ${log}

        if [ ! -f ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg ] ;
        then
            echo "Making mergeTracts.m file"
            echo "Making mergeTracts.m file" >> ${log}
            file_matlab=temp_${numParcels}_mergeTracts

            echo "mergeTracts('${tempdir}/','${outname}');exit" > ${file_matlab}.m

            matlab -nodisplay -r "${file_matlab}"
        
            mkdir -p ${tempdir}/probtrackx/${outname}/connectome
            mv ${tempdir}/probtrackx/${outname}/connectivity* ${tempdir}/probtrackx/${outname}/connectome/
        
            echo "Connectome tractography complete without errors!"
            echo "Connectome tractography complete without errors!" >> ${log}
            
            echo "cleanup of intermediary files"
            echo "cleanup of intermediary files" >> ${log}

            rm -r slurm* probtrackx/${outname}/Seg* probtrackx/${outname}/commands ${outname}_seeds/Seg*
                                
        else
        
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/"
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/" >> ${log}
        
        fi

    else #parallel loop at start
    
        echo "Running probtrackx connectome sequentially with --network option"
        #this shouldn't run either!
        #echo "Starting connectome sequentially with --network option" >> $log
        #echo "" >> $log

        #only 500 seeds and no option '-opd'
        probtrackx2 \
        --network \
        --samples=${tempdir}/diffusion.bedpostX/merged \
        --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
        --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
        --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
        --dir=${outname} \
        --seed=${outname}_seeds/seeds_targets_list.txt \
        --loopcheck \
        --onewaycondition \
        --forcedir \
        --nsamples=500

    fi

fi


###################################################

#3. Randomised isovolumetric 500mm2 / 300+ region

###################################################


template=${codedir}/templates/500.sym_4mm.nii.gz

outname=`basename ${template} .nii.gz`
echo "outname is: ${outname}"
echo "outname is: ${outname}" >> ${log}

if [[ -d ${tempdir}/probtrackx/${outname} ]] ;
then

    echo "${template} template connectome already run in probtrackx directory"
    echo "${template} template connectome already run in probtrackx directory" >> ${log}

else

    maxParcel=`fslstats ${template} -R | awk '{print $2}'`
    numParcels=`printf "%0.0f\n" $maxParcel`
    echo "numParcels: ${numParcels}"
    echo "numParcels: ${numParcels}" >> ${log}

    #mask template by gray matter: optional - not for DK
    #fslmaths ${template} -mul ${tempdir}/hardsegmentation/GM_mask_MNI ${template}

    #generate list of seeds
    #make new each time (for path continuity)
    if [[ -d ${tempdir}/${outname}_seeds/ ]] ; then rm -r ${tempdir}/${outname}_seeds/; fi
    echo "${template}: making seeds & seeds_list"
    echo "${template}: making seeds & seeds_list" >> ${log}
    deparcellator.sh ${template}

    if [ "${parallel}" == 1 ] ;
    then
        echo "Running probtrackx connectome in parallel"
        echo "Running probtrackx connectome in parallel" >> ${log}

        #1. Generate scripts

        mkdir -p ${tempdir}/probtrackx/${outname}/commands/

        if [ ! -f ${tempdir}/probtrackx/${outname}/commands/Seg`printf %04d $numParcels`.sh ] ;
        then
            echo "Generating tractography scripts"
            echo "Generating tractography scripts" >> ${log}
            for region in `cat  ${tempdir}/${outname}_seeds/seeds_targets_list.txt`;
            do
                region_name=`basename ${region} .nii.gz`
                touch ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "#!/bin/bash" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
                echo "probtrackx2 \
                --samples=${tempdir}/diffusion.bedpostX/merged \
                --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
                --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
                --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
                --seed=${region} \
                --dir=${tempdir}/probtrackx/${outname}/${region_name}/ \
                --targetmasks=${tempdir}/${outname}_seeds/seeds_targets_list.txt \
                --s2tastext \
                --pd \
                --loopcheck \
                --forcedir \
                --opd \
                --os2t \
                --nsamples=500" >> ${tempdir}/probtrackx/${outname}/commands/${region_name}.sh
            done
        else
            echo "Tractography scripts have been made already."
            echo "Tractography scripts have been made already." >> ${log}
        fi

        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`


        #2. Submit to cluster

        if [ "${seedFinished}" != "{$numParcels}" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
        then
            echo "Submitting tractography scripts to cluster"
            echo "Submitting tractography scripts to cluster" >> ${log}
            chmod 777 ${tempdir}/probtrackx/${outname}/commands/*
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
                num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
                seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
                seg_id2=`echo $seg_id | sed "s/...$//g"`
                if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ]
                then
                    sbatch --time=1:00:00 ${cmdFiles}
                    sleep 10
                fi
            done

            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts."
            echo "Tractography jobs submitted to the cluster - *might* need to re-run script after they have finished (check with qstats or squeue) to merge tracts." >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})."
            echo "Check number of jobs finished (number of parcels=${numParcels})." >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "going to sleep to wait for parcels to finish: 6h"
            echo "going to sleep to wait for parcels to finish: 6h" >> ${log}
            sleep 6h

        else
            echo "Tractography scripts have finished running on cluster already"
            echo "Tractography scripts have finished running on cluster already" >> ${log}
        fi


        seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        
        #3. Check all tractography scripts have run (& re-submit if not)
        
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}"
        echo "Number of jobs finished: ${seedFinished} Should equal number of parcels: ${numParcels}" >> ${log}
        
        iteration=1
        
        while [ "${seedFinished}" != "${numParcels}" ] ;
        do
            
            echo "Number of jobs finished: ${seedFinished}"
            echo "Number of jobs finished: ${seedFinished}" >> ${log}
            
            echo "iteration = ${iteration}"
            echo "iteration = ${iteration}" >> ${log}
            
            echo "Re-submitting incomplete tractography scripts to cluster"
            echo "Re-submitting incomplete tractography scripts to cluster" >> ${log}
            
            echo "(partial) cleanup of intermediary files"
            echo "(partial) cleanup of intermediary files" >> ${log}
            
            rm -r slurm*
            
            for cmdFiles in ${tempdir}/probtrackx/${outname}/commands/*.sh
            do
               num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
               seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
               seg_id2=`echo $seg_id | sed "s/...$//g"`
               if [ ! -f ${tempdir}/probtrackx/${outname}/${seg_id2}/matrix_seeds_to_all_targets ] ;
               then
                   sbatch --time=1:00:00 ${cmdFiles}
                   echo "re-submitting ${seg_id2}"
                   echo "re-submitting ${seg_id2}" >> ${log}
                   sleep 10
               fi
            done

            echo "Tractography jobs re-submitted to the cluster"
            echo "Tractography jobs re-submitted to the cluster" >> ${log}
            echo "Check number of jobs finished (number of parcels=${numParcels})"
            echo "Check number of jobs finished (number of parcels=${numParcels})" >> ${log}
            echo "ls ${tempdir}/${outname}_connectome/Seg*/matrix_seeds_to_all_targets | wc -l"

            #Significant pause: ~1min per parcel for tracing (depends on volume) + queue
            echo "Going to sleep (again) to wait for parcels to finish: 6h"
            echo "Going to sleep (again) to wait for parcels to finish: 6h" >> ${log}
            sleep 6h
            
            iteration=`echo $iteration + 1 | bc`;
            seedFinished=`(ls ${tempdir}/probtrackx/${outname}/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

        done
               
               
        #4. Merge tracts
        
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg"
        echo "checking: ${tempdir}/probtrackx/${outname}/connectome/connectivity_strlines.jpg" >> ${log}

        if [ ! -f ${tempdir}/probtrackx/connectome/connectivity_strlines.jpg ] ;
        then
            echo "Making mergeTracts.m file"
            echo "Making mergeTracts.m file" >> ${log}
            file_matlab=temp_${numParcels}_mergeTracts

            echo "mergeTracts('${tempdir}/','${outname}');exit" > ${file_matlab}.m

            matlab -nodisplay -r "${file_matlab}"
        
            mkdir -p ${tempdir}/probtrackx/${outname}/connectome
            mv ${tempdir}/probtrackx/${outname}/connectivity* ${tempdir}/probtrackx/${outname}/connectome/
        
            echo "Connectome tractography complete without errors!"
            echo "Connectome tractography complete without errors!" >> ${log}
            
            echo "cleanup of intermediary files"
            echo "cleanup of intermediary files" >> ${log}

            rm -r slurm* probtrackx/${outname}/Seg* probtrackx/${outname}/commands ${outname}_seeds/Seg*
                                
        else
        
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/"
            echo "Connectome already computed: results in ${tempdir}/probtrackx/${outname}/connectome/" >> ${log}
        
        fi

    else #parallel loop at start
    
        echo "Running probtrackx connectome sequentially with --network option"
        #this shouldn't run either!
        #echo "Starting connectome sequentially with --network option" >> $log
        #echo "" >> $log

        #only 500 seeds and no option '-opd'
        probtrackx2 \
        --network \
        --samples=${tempdir}/diffusion.bedpostX/merged \
        --mask=${tempdir}/diffusion.bedpostX/nodif_brain_mask \
        --xfm=${tempdir}/diffusion.bedpostX/xfms/standard2diff \
        --invxfm=${tempdir}/diffusion.bedpostX/xfms/diff2standard \
        --dir=${outname} \
        --seed=${outname}_seeds/seeds_targets_list.txt \
        --loopcheck \
        --onewaycondition \
        --forcedir \
        --nsamples=500

    fi

fi


echo $(date) >> ${log}
echo "All done with bit_connectome"
echo "All done with bit_connectome" >> ${log}
