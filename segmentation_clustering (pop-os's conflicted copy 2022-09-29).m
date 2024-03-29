%SEGMENTATIONC_CLUSTERING
%Part of the DBS tractography ('tract_van') code
%Complimentary script to probtrackx -omatrix2 option
%Performs k-means segmentation of target nucleus
%
%NB: run from the patient segmentation_omatrix2 directory
%
% Michael Hart, University of British Columbia, November 2020

%% Run clustering

% Load matrix2
x = load('fdt_matrix2.dot');
M = full(spconvert(x));

% Calculate cross-correlation
CC = 1+corrcoef(M');
CC(isnan(CC)) = 0; %removes NAN's: catch for some matrices (need to query input data)

% Do kmeans with k clusters
k = 7; %set number of clusters - default 5
idx = kmeans(CC,k);   % k is the number of clusters

% Load coordinate information to save results
addpath([getenv('FSLDIR') '/etc/matlab']);
[mask,~,scales] = read_avw('fdt_paths');
mask = 0*mask;
coord = load('coords_for_fdt_matrix2')+1;
ind = sub2ind(size(mask),coord(:,1),coord(:,2),coord(:,3));
[~,~,j] = unique(idx);
mask(ind) = j;
save_avw(mask,'clusters','i',scales);

%fslcpgeom fdt_paths clusters %do this in terminal to set geometry
