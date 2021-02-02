# WARNING! PROJECT OUTDATED, NEEDS MUCH UPDATES!

**PLEASE, DO NOT MORE USE THAT SHADER PACK BEFORE I UPDATE!**<br>
WIP Innovational shader pack that can be used as basis


### NEEDS THOSE UPDATES!

- Use blend-states per render-target
- Use CORRECT depth value
- Make correct screen space reflections
- Use layering, and probably, INT types

### Features

- Precise correct screen space reflection
- Correctly transparency (stochastic OIT)
- Split screen technique for correct results
- Packing tangents, normals, texcoords, lmcoords, colors... into 4 buffers only


### Render Quality

Please, use render quality 2x
I'm NOT made super-sampling upscaling
**TODO: Layered framebuffer rendering**

### Planar Reflection

Due Optifine limitations, there is NOT possible to make planar reflections in such shader pack<br>
Main problem: getting required plane level...
**TODO: Planned to resolve that problem with my new extensions for Optifine**

### Far future

For Optifine shaders system needs:
- dedicated `image2D` buffers
- separate blending per draw buffers

It needs for:
- planar reflections
- reprojections
- some advanced features
- ray tracing features
- deferred texturing
- advanced data packing (mixed with blended)
