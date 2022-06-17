# StrokeGen: Realtime GPU Contour Curve Generation from Mesh  

<img src="Abstract Submit Image" alt="Abstract Submit Image" style="zoom: 33%;" />

See our paper at EGSR 2022: XXXXXXXX

*StrokeGen* is a real-time method to compute 2D curves from 3D mesh’s contour. 

No exsisting GPU-based outlining method (Hull Outline, Postprocessing, etc.) can extract stroke curves, which is essential for expressive line drawings. *StrokeGen* makes real-time contour-curve-generation possible. 

It has following advantages:

- Reaches up to 800x acceleration over CPU-based offline alternatives ([Pencil+4](https://www.psoft.co.jp/jp/product/pencil/unity/), [Line Art](https://docs.blender.org/manual/en/latest/grease_pencil/modifiers/generate/line_art.html), [Freestyle](https://docs.blender.org/manual/en/latest/render/freestyle/introduction.html#:~:text=Freestyle%20is%20an%20edge%2Fline,technical%20(hard%20line)%20looks.), [Active Strokes](https://github.com/benardp/ActiveStrokes)), .
- Produces stroke curves with quality comparable to or even better than these CPU-based approaches.

StrokeGen is developed with URP in Unity Engine. All runtime procedures are implemented on the GPU with HLSL shaders. To run this project:

- 



