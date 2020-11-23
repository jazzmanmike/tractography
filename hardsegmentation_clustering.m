%SEGMENT_CLUSTERS 
%Part of the DBS tractography code
%Complimentary script to probtrackx -omatrix2 option
%Performs k-means segmentation of target nucleus
%
%NB: run from the patient probtrackx_hardsegmentation directory
%
% Michael Hart, University of British Columbia, November 2020

%% Run clustering

% Load Matrix2
x=load('fdt_matrix2.dot');
M=full(spconvert(x));

% Calculate cross-correlation
CC  = 1+corrcoef(M');

% Do kmeans with k clusters
k=5; %set number of clusters
idx = kmeans(CC,k);   % k is the number of clusters

% Load coordinate information to save results
addpath([getenv('FSLDIR') '/etc/matlab']);
[mask,~,scales] = read_avw('fdt_paths');
mask = 0*mask;
coord = load('coords_for_fdt_matrix2')+1;
ind   = sub2ind(size(mask),coord(:,1),coord(:,2),coord(:,3));
[~,~,j] = unique(idx);
mask(ind) = j;
save_avw(mask,'clusters','i',scales);
!fslcpgeom fdt_paths clusters