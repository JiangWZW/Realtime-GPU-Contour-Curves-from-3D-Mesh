# StrokeGen: Realtime GPU Contour Curve Generation from Mesh  

| <img src=".\Abstract Submit Image.png" alt="Abstract Submit Image" width = 500 style="zoom: 33%;" /> |
| :----------------------------------------------------------: |
|       <b>Generated strokes with different colors</b>.        |

No existing GPU-based NPR method (inverted hull, post-processing, etc.) can generate stroke curves, essential for expressive line drawings. 

*StrokeGen*, a real-time method to generate 2D curves from 3D mesh’s contour:

- Reaches up to 800x acceleration over CPU-based offline alternatives ([Pencil+4](https://www.psoft.co.jp/jp/product/pencil/unity/), [Line Art](https://docs.blender.org/manual/en/latest/grease_pencil/modifiers/generate/line_art.html), [Freestyle](https://docs.blender.org/manual/en/latest/render/freestyle/introduction.html#:~:text=Freestyle%20is%20an%20edge%2Fline,technical%20(hard%20line)%20looks.), [Active Strokes](https://github.com/benardp/ActiveStrokes)). It is crazily fast: only costs 1ms for mesh of 300k tris, under 1920x1080 screen resolution.
- Produces stroke curves comparable to these CPU-based approaches.

## How to setup

StrokeGen is a research prototype, developed in Unity Engine, with its Universal Render Pipeline.
All runtime procedures are implemented on the GPU with HLSL (mainly compute shaders). 

To run this project:

- Download and install Unity Editor 2021.2.11f1 (from Unity Hub or [here](https://unity3d.com/unity/whats-new/2021.2.11));
- Open the project, in package manager, make sure following packages are imported:
  - Official: Core RP Library, Unity UI, Universal RP;
  - Third Party: [Odin Inspector](https://assetstore.unity.com/packages/tools/utilities/odin-inspector-and-serializer-89041)
- Open “Assets/Scenes/SampleScene.unity”;
- Click “Play”. Different color corresponds to different stroke curves.

## Implementation Notes

​	For more details, please refer to our paper at EGSR 2022: XXXXXXXX

- Currently only support to render a **single static mesh**. However, in theory, it can be adapted for a skeletal mesh easily. Multiple mesh is also possible, but I’m too lazy to deal with the mesh api in Unity.
- **Temporal Coherence**
  Strokes can change quickly under animation.
  I’ve spent a year working on a optimizer to generate smooth stroke animation. It is removed in this branch. I’ll upload that in the future.
- **Stroke Styles**
  I removed stamping (similar to paint brush in Photoshop) style, only kept the sweeping (similar to brush path in Illustrator), since the branch for stamping is kind of messy.

## Compatibility

Tested on Windows, with Nnvidia GPUs (GTX 1070, GTX 1080, Quadro M2000). 

Any questions or problems, email 3284829455@qq.com. June 17, 2022
