#Code tested during trials for tract_van (mostly parallel code)

#omatrix2 hard segmentation
#from gui
#probtrackx2 \
-x hardsegmentation/thalamus_right_MNI.nii.gz \
--omatrix2 \
--target2=/hardsegmentation/GM_mask_MNI.nii.gz \
--xfm=diffusion.bedpostX/xfms/standard2diff.nii.gz \
--invxfm=diffusion.bedpostX/xfms/diff2standard.nii.gz \
-s diffusion.bedpostX/merged \
-m diffusion.bedpostX/nodif_brain_mask \
--dir=thalamus2cortex_right_omatrix2 \
--onewaycondition \
-c 0.2 \
-S 2000 \
--steplength=0.5 \
-P 5000 \
--fibthresh=0.01 \
--distthresh=0.0 \
--sampvox=0.0 \
--forcedir \
--opd \
-l

#Alternative parallel (slurm) version for probtrackx connectome code (from Rafa) - similar to below but reformatted


if [ "${parallel}" == 1 ] ;
then
    echo "Starting connectome -- in parallel"
    echo "Starting connectome -- in parallel" >> $log
    echo "" >> $log
   
    #Generate scripts
    
    if [ ! -f ${tempdir}/probtrackx/DK/commands_dir/Seg`printf %04d $nParcels`.sh ] ;
    then
         echo "Generating tractography scripts"
         rm -rf ${tempdir}/probtrackx/DK/commands_dir/
         mkdir -p ${tempdir}/probtrackx/DK/commands_dir/

         for region in `cat  ${tempdir}/probtrackx/DK/seeds_targets_list.txt`;
         do
            region_name=`basename ${region} .nii.gz`
            echo "#!/bin/bash" > ${tempdir}/probtrackx/DK/commands_dir/${region_name}.sh
            echo "probtrackx \
            --samples ${tempdir}/diffusion.bedpostX/merged \
            --mask ${tempdir}/diffusion.bedpostx/nodif_brain_mask \
            --seed ${region} \
            --dir=${tempdir}/probtrackx/DK/${region_name}/ \
            --targetmasks=${tempdir}/probtrackx/DK/seeds_targets_list.txt \
            --s2tastext \
            --pd \
            --loopcheck \
            --forcedir \
            --opd \
            --os2t \
            --nSamples 500" >> ${tempdir}/probtrackx/DK/commands_dir/${region_name}.sh
         done
    fi

    seedFinished=`(ls ${tempdir}/probtrackx/DK/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

  #Submit to cluster
  if [ "${seedFinished}" != "$numParcels" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
  then

      echo "Run tractography parallel"
      for cmdFiles in ${tempdir}/probtrackx/DK/commands_dir/*.sh
      do
          temp=${tempdir}/probtrack/DK/commands_dir/script_list_${RANDOM}.sh
          #echo "!/bin/bash" >> ${temp}
          printf "#!/bin/bash\n . ${HOME}/.bashrc && cd ${dir} && chmod 777 $cmdFiles && . $cmdFiles" >> ${temp}
          num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
          seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
          seg_id2=`echo $seg_id | sed "s/...$//g"`
          if [ ! -f ${tempdir}/probtrackx/DK/${seg_id2}/matrix_seeds_to_all_targets ]
          then
              sbatch --time=23:00:00 ${temp}
              sleep 10
          fi
      done
      
      echo "Tractography jobs submitted to the cluster. Re-run script after they finished (check with qstats or squeue) to merge tracts."
      echo "Check number of jobs finished (number of parcels=${nParcels})."
      echo "ls ${tempdir}/probtrackx/DK/Seg*/matrix_seeds_to_all_targets | wc -l"
  fi

  #Merge tracts
  echo "checking: ${tempdir}/images/connectivity_DK.jpg"
  if [ ! -f ${tempdir}/images/connectivity_DK.jpg ]
  then
      if [ "${seedFinished}" = "$numParcels" ]
      then
          echo "Combining tractography images"
          mkdir -p logs
          cd ${path_project}

          file_matlab=temp_${nParcels}_mergeTracts
          pwd
          echo ${file_matlab}.m

          echo "mergeTracts('${path_project}/diffusion/','${parcellation}');exit" > ${file_matlab}.m
          matlab -nodisplay -r "${file_matlab}"

          rm ${file_matlab}.m

          mkdir -p ${tempdir}/connectome_output/matrices_Prob/
          mkdir -p ${tempdir}/connectome_output/matrices_strlines/
          mkdir -p ${tempdir}/parcellation/DK

          cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.jpg \
              ${tempdir}/images/connectivity_DK.jpg

      
          #Copy to an external folder (diffusion_output): need to understand output first
          cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.csv \
              ${tempdir}/connectome_output/matrices_Prob/DK.csv
          
          cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_strlines.csv  \ ${tempdir}/connectome_output/matrices_strlines/DK.csv
          
          cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.jpg \
              ${tempdir}/connectome_output/images/prob_DK.jpg
          
          echo "FSL tractography COMPLETE without errors!"
      else
          echo "Jobs submitted to the cluster. Re-run after they finish ${path_project}"
      fi
  else
      echo "Connectivity matrices were already computed ${path_project}"
  fi
fi


#probtrackx in parallel from Rafa

if [ ! -f ${tempdir}/probtrackx/DK/commands_dir/Seg`printf %04d $nParcels`.sh ] ;
then
     echo "Generating tractography scripts"
     rm -rf ${tempdir}/probtrackx/DK/commands_dir/
     mkdir -p ${tempdir}/probtrackx/DK/commands_dir/

     for region in `cat  ${tempdir}/probtrackx/DK/seeds_targets_list.txt`;
     do
        region_name=`basename ${region} .nii.gz`
        echo "#!/bin/bash" > ${tempdir}/probtrackx/DK/commands_dir/${region_name}.sh
        echo "probtrackx \
        --samples ${tempdir}/diffusion.bedpostX/merged \
        --mask ${tempdir}/diffusion.bedpostx/nodif_brain_mask \
        --seed ${region} \
        --dir=${tempdir}/probtrackx/DK/${region_name}/ \
        --targetmasks=${tempdir}/probtrackx/DK/seeds_targets_list.txt \
        --s2tastext \
        --pd \
        --loopcheck \
        --forcedir \
        --opd \
        --os2t \
        --nSamples 500" >> ${tempdir}/probtrackx/DK/commands_dir/${region_name}.sh
     done
fi

seedFinished=`(ls ${tempdir}/probtrackx/DK/Seg*/matrix_seeds_to_all_targets 2>/dev/null | wc -l)`

      #Submit to cluster
      if [ "${seedFinished}" != "$numParcels" ] && [ -f ${tempdir}/diffusion.bedpostX/mean_S0samples.nii.gz ]
      then

          echo "Run tractography parallel"
          for cmdFiles in ${tempdir}/probtrackx/DK/commands_dir/*.sh
          do
              temp=${tempdir}/probtrack/DK/commands_dir/script_list_${RANDOM}.sh
              #echo "!/bin/bash" >> ${temp}
              printf "#!/bin/bash\n . ${HOME}/.bashrc && cd ${dir} && chmod 777 $cmdFiles && . $cmdFiles" >> ${temp}
              num_bars=$(( $(echo "$cmdFiles" |   grep -o "/"  | wc -l) + 1))
              seg_id=`echo $cmdFiles | cut -d "/" -f $num_bars`
              seg_id2=`echo $seg_id | sed "s/...$//g"`
              if [ ! -f ${tempdir}/probtrackx/DK/${seg_id2}/matrix_seeds_to_all_targets ]
              then
                  sbatch --time=23:00:00 ${temp}
                  sleep 10
              fi
          done
          
          echo "Tractography jobs submitted to the cluster. Re-run script after they finished (check with qstats or squeue) to merge tracts."
          echo "Check number of jobs finished (number of parcels=${nParcels})."
          echo "ls ${tempdir}/probtrackx/DK/Seg*/matrix_seeds_to_all_targets | wc -l"
      fi

      #Merge tracts
      echo "checking: ${tempdir}/images/connectivity_DK.jpg"
      if [ ! -f ${tempdir}/images/connectivity_DK.jpg ]
      then
          if [ "${seedFinished}" = "$numParcels" ]
          then
              echo "Combining tractography images"
              mkdir -p logs
              cd ${path_project}

              file_matlab=temp_${nParcels}_mergeTracts
              pwd
              echo ${file_matlab}.m

              echo "mergeTracts('${path_project}/diffusion/','${parcellation}');exit" > ${file_matlab}.m
              matlab -nodisplay -r "${file_matlab}"

              rm ${file_matlab}.m

              mkdir -p ${tempdir}/connectome_output/matrices_Prob/
              mkdir -p ${tempdir}/connectome_output/matrices_strlines/
              mkdir -p ${tempdir}/parcellation/DK

              cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.jpg \
                  ${tempdir}/images/connectivity_DK.jpg

          
              #Copy to an external folder (diffusion_output): need to understand output first
              cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.csv \
                  ${tempdir}/connectome_output/matrices_Prob/DK.csv
              
              cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_strlines.csv  \ ${tempdir}/connectome_output/matrices_strlines/DK.csv
              
              cp ${path_project}/diffusion/parcellation/$parcellation/connectivity_Prob.jpg \
                  ${tempdir}/connectome_output/images/prob_DK.jpg
              
              echo "FSL tractography COMPLETE without errors!"
          else
              echo "Jobs submitted to the cluster. Re-run after they finish ${path_project}"
          fi
      else
          echo "Connectivity matrices were already computed ${path_project}"
      fi


#Old BedPostX Parallel Code


   if [ "${parallel}" == 1 ] ;
    then
        id_par=0
        mkdir -p ${tempdir}/diffusion.bedpostX/command_files/
        while read line; do
            if [ ! -f ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_`printf %04d $id_par`/mean_S0samples.nii.gz ]
            then
                echo '#!/bin/bash' > ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d $id_par`.sh
                echo $line >> ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d $id_par`.sh
                chmod 777 ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d $id_par`.sh
                sleep 2
                echo "Step-by-step bedpostx command_files/command_`printf %04d $id_par`.sh"
                sbatch --time=02:00:00 ${tempdir}/diffusion.bedpostX/command_files/command_`printf %04d $id_par`.sh
                sleep 1
            fi
            id_par=$(($id_par + 1))
        done < ${tempdir}/diffusion.bedpostX/commands.txt

        echo "Bedpost jobs submitted to the cluster. Set to sleep for 2 hours."
        
        sleep 2h

        #combines individual file outputs: check if all made, and if so, run bedpostx_postproc
        bedpostFinished=`(ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice_*/mean_S0samples.nii.gz 2>/dev/null | wc -l)`
        numLines=`cat ${tempdir}/diffusion.bedpostX/commands.txt  | wc -l`
        if  [ "${bedpostFinished}" = "$numLines" ]
        then
            echo "bedpostx_postproc.sh ${tempdir}/diffusion.bedpostX/"
            bedpostx_postproc.sh ${tempdir}/diffusion.bedpostX/
        fi
        
        echo "Check number of jobs finished. Total should be: ${id_par}"
        echo "ls ${tempdir}/diffusion.bedpostX/diff_slices/data_slice*/mean_dsamples.nii.gz | wc -l"
        
    fi

