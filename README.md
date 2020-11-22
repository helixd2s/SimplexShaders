# Simplex Shaders

WIP Innovational shader pack that can be used as basis


### Features

- Precise correct screen space reflection
- Correctly transparency (stochastic OIT)
- Split screen technique for correct results
- Packing tangents, normals, texcoords, lmcoords, colors... into 4 buffers only


### Render Quality

Please, use render quality 2x
I'm NOT made super-sampling upscaling


### Planar Reflection

Due Optifine limitations, there is NOT possible to make planar reflections in such shader pack<br>
Main problem: getting required plane level...


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
