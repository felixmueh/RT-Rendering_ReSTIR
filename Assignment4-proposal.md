# Realtime Rendering Practical Course - Assignment 4 Proposal

## ReSTIR

### Motivation
Spatiotemporal Reservoir Resampling ([ReSTIR](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf)), introduced by Bitterli et al. in 2020, enables dynamic direct lighting calculations for a large number of light sources in realtime. The algorithm enhances raytracing and is designed to work with a variety of light sources such as point lights and area lights. ReSTIR has been implemented in state of the art engines such as Unreal Engine 5 and the paper is discussed in the Interactive CG lecture at KIT. Both theory and practical application are interesting for us. We therefore want to use this practical course to gain hands on experience with this algorithm.

### Overview
In the original paper, ReSTIR is used for direct illumination. The algorithm works in screen space and operates in two steps:

First, points on light sources are sampled and stored in a per-pixel reservoir. The samples weights are then calculated from the unshadowed contribution to their respective pixel. This requires evaluating the BRDF but not tracing rays.

Subsequently the resampling is performed. A final sample is drawn at random from the reservoir based on the sample weights. The sample is then used for estimating the direct illumination by tracing a shadow ray.

The strength of this algorithm is its ability to leverage existing samples by utilizing the last frames reservoir (temporal reuse) as well as combining reservoirs from adjacent pixels (spatial reuse).

### Key Objectives
- **Light sampling**: Currently the framework does not provide the functionality to sample points on light sources. Therefore the first step is to add a buffer for emissive geometry, thereby enabling uniform sampling of points on area light sources.
- **Reservoir creation**: A screen space buffer needs to be allocated for the reservoirs a sampling pass needs to be added to fill the reservoirs with light samples and calculate the corresponding weights.
- **Resampling**: A lighting pass needs to be implemented to calculate the direct illumination for each pixel by resampling from the reservoir.
- **Spatial reuse**: To utilize samples from nearby pixels, reservoirs need to be combined in a spatial neighbourhood before resampling.
- **Temporal reuse**: To support temporal reuse when moving the camera, temporal reporjection is required to access reservoirs from previous frames.
- **Performance analysis and visual results**: For the final presentation we will test our implementation on different scenes and compare its performance and visual quality to the results of previous assignments.

### Bonus Objectives
In case we have time left of the proposal so far does not fulfill the requirements for this project, we provide additional objectives:

1. **ReSTIR GI**: As proposed by Ouyang et al. in 2021 ([ReSTIR GI](https://d1qx31qr3h6wln.cloudfront.net/publications/ReSTIR%20GI.pdf)), the algorithm can be extended to improve global illumination as well. To achieve this, path-traced samples of indirect illumination are added to the reservoirs. The resampling as well as spatial and temporal reuse are not effected by this extension.
2. **Unbiased ReSTIR**: Spatial and temporal reuse induces a bias as the BRDF and angles differ between pixels and frames. To remove this bias, the weights of each sample need to be recomputed before resampling to ensure a correct pdf for the MC estimate.
3. **Next Event Estimation**: With light sampling implemented, we can improve the path-tracing results by adding NEE for subsequent bounces as well. 

### Division of Workload
The initial steps are implemented by pair programming as subsequent steps depend on these basic capabilities. Specifically this includes:
- Light sampling (this is required for the next steps)
- Reservoir creation (this is required for the next step)
The final presentation will also be created as teamwork.

The extensions are then split between the participants. The preliminary assignment is as follows:

Dominik:
- resampling and direct illumination
- spatial reuse

Felix:
- temporal reuse and reprojection
- performance analysis
- visual results
  
In case some of these prove to be significantly more challenging than others we would like to be able to change these assignments. We will however supply an updated assignment in that case.

### Students
- Felix Mühlenberend
- Dominik Wüst

# TODOs
- Add emissive triangles to scene (cbox)
- Initialize light list
- Resampling / Environment map / lightlist
- Spacial / temporal datastructures
- Spacial / temporal reuse
