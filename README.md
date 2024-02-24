# Ray Tracing in One Weekend - GLSL Shadertoy

COSC 277 Computer Graphics: Programming Assignment 6

A GLSL adaptation of [_Ray Tracing in One Weekend_](https://raytracing.github.io/books/RayTracingInOneWeekend.html).

![](./previews/task11.png)

## Introduction

The GLSL source codes are meant to be run in VSCode using [Shader Toy plugin](https://marketplace.visualstudio.com/items?itemName=stevensona.shader-toy). To adapt the codes to [shadertoy.com](shadertoy.com), the following changes have to be made.

* Replace `void main()` with `void mainImage(out vec4 fragColor, in vec2 fragCoord)`
* Replace `gl_FragColor` with `fragColor`
* Replace `gl_FragCoord` with `fragCoord`

 ## TASK 1: Setup
![](./previews/task1-ch4.png)

 ## TASK 2: Adding a Sphere
![](./previews/task2-ch5.png)

 ## TASK 3: Surface Normals
![](./previews/task3-ch6.png)

 ## TASK 4: Antialiasing
![](./previews/task4-ch7.png)

 ## TASK 5: Diffuse Materials
![](./previews/task5-ch8.png)

 ## TASK 6: Metal
![](./previews/task6-ch9.png)

 ## TASK 7: Dielectrics
![](./previews/task7-ch10.png)

 ## TASK 8: Positionable Camera
![](./previews/task8-ch11.png)

 ## TASK 9: Defocus Blur
![](./previews/task9-ch12.png)

 ## TASK 10: Progressive Rendering
![](./previews/task10.png)

 ## TASK 11: Recreate Cover Image
![](./previews/task11.png)

 ## TASK 12: Interesting Scene
![](./previews/task12.png)