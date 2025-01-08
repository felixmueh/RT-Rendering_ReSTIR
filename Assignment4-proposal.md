# Realtime Rendering Practical Course - Assignment 4 Proposal

## ReSTIR

### Motivation
Spatiotemporal Reservoir Resampling ([ReSTIR](https://research.nvidia.com/sites/default/files/pubs/2020-07_Spatiotemporal-reservoir-resampling/ReSTIR.pdf)) as proposed by Bitterli et al. in 2020 enables direct lighting with many light sources in realtime. The algorithm relies on raytracing and is designed to work with a variety of light sources such as point lights and area lights. ReSTIR has ben implemented in state of the art engines such as Unreal Engine 5 and the paper is discussed in the Interactive CG lecture at KIT, thus we want to get hands on experience with this algorithm.

### Outline
In the original paper, ReSTIR is used for direct illumination. The algorithm works in screen space and operates in two steps:

First, points on light sources are sampled and stroed in a per-pixel reservoir. The samples are weighted by the unshadowed contribution to their respective pixel, which requires evaluating the BRDF, but no rays need to be traced.

In the second step, the resampling is done. A final sample is drawn from the reservoir based on the corresponding weight. This sample will be used for estimating the direct illumination by tracing a shadow ray.

The power of this algorithm lies in reusing samples of last frames reservoir (temporal reuse) as well as combining reservoirs of neighbouring pixels (spatial reuse).

### Key Objectives
- **Light sampling**: In the current state, our framework does not provide functionality to sample points on light sources. Thus, we need to add a buffer for emissive geometry, which enables uniform sampling of points on area light sources.
- **Reservoir creation**: We need to allocate the screen space buffer for the reservoirs and add a sampling pass to fill the reservoirs with light samples and the corresponding weights.
- **Resampling**: We need to implement a lighting pass to resample from the reservoir and compute the direct illumination for each pixel.
- **Spatial reuse**: To utilize samples from nearby pixels, reservoirs need to be combined in a spatial neighbourhood before resampling.
- **Temporal reuse**: To support temporal reuse when moving the camera, temporal reporjection is required to access reservoirs from previous frames.
- **Performance analysis and visual results**: For the final presentation we will test our implementation on different scenes and compare its performance and visual quality to the results of previous assignments.

### Bonus Objectives
In case we have time left of the proposal so far does not fulfill the requirements for this project, we provide additional objectives:

1. **ReSTIR GI**: As proposed by Ouyang et al. in 2021 ([ReSTIR GI](https://d1qx31qr3h6wln.cloudfront.net/publications/ReSTIR%20GI.pdf)), the algorithm can be extended to improve global illumination as well. Therefore, path-traced samples of indirect illumination are added to the reservoirs. The resampling as well as spatial and temporal reuse are not effected by this extension.
2. **Unbiased ReSTIR**: Spatial and temporal reuse induce a bias as the BRDF and angles differ between pixels and frames. To remove this bias, the weights of each sample need to be recomputed before resampling to ensure a correct pdf for the MC estimate.
3. **Next Event Estimation**: With light sampling implemented, we can improve the path-tracing results by adding NEE for later bounces as well. 

### Division of Workload
*We need to discuss this*
Together:
- Setup repo
- Prepare presentation
- Light sampling (this is required for the next steps)
- Reservoir creation (this is required for the next step)

Split:
- resampling and direct illumination
- spatial reuse
- temporal reuse and reprojection
- performance analysis
- visual results


### Students
- Felix
- Dominik
