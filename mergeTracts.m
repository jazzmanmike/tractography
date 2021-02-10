function mergeTracts(path_dir_in,parcellation)

display(['mergeTracts(' path_dir_in ',' parcellation ')']);

path_dir=[path_dir_in '/probtrackx/' parcellation]; %path to probtrackx data
dir_seg=dir(path_dir);

numRand=5000; %number of seeds per region

mean_connectivity=[];
numVoxels=[];
indi=1;indj=1;
%sum_connectivity=[];indi=1;indj=1;

for is=3:numel(dir_seg)
    is
    name=dir_seg(is).name;
    if strfind(name,'Seg')
        path_seg=[path_dir '/' name '/matrix_seeds_to_all_targets'];
        d=dir(path_seg);
        if d.bytes>0
            name_tg_list=dlmread(path_seg);
            vol=load_nifti([path_dir_in parcellation '_seeds/' name '.nii.gz']);
            numVoxels(indi)=sum(sum((sum(vol.vol>0))));
            row=mean(name_tg_list,1);
        else
            row=zeros(1,numel(dir_seg)-3);
        end
        mean_connectivity(indi,:)=row;
        indi=indi+1;
     end
end

connectivity=mean_connectivity;
%[s1 s2 s3]=mkdir([path_dir_in '/parcellation/' parcellation]);

%save number of streamlines
csvwrite([path_dir '/connectivity_strlines.csv'], connectivity);
imagesc(connectivity);
saveas(gca,[path_dir '/connectivity_strlines.jpg'])
close(gcf)

%save connectivity probability
numSeeds=numRand*repmat(numVoxels,numel(numVoxels),1);
connectivity=mean_connectivity./numSeeds;
csvwrite([path_dir '/connectivity_Prob.csv'], connectivity);
imagesc(connectivity);
saveas(gca,[path_dir '/connectivity_Prob.jpg'])
close(gcf)

end
