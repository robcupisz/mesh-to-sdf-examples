# mesh-to-sdf examples

A sample project showing VFX examples relying on the real-time SDF generator from the [mesh-to-sdf package](https://github.com/Unity-Technologies/com.unity.demoteam.mesh-to-sdf).

SDFs are generated from a low poly version of the Adam character as it's animating, and consumed by the effects:
- The pink character is a VFX Graph effect. The SDF is sampled in the *Position (SDF)*, *Conform to SDF* and *Sample SDF* nodes.
- Adam surrounded by green bubbles is an example of raymarching the SDF in a shader.
- Sparky is a VFX Graph effect as well, using the *Collide with SDF* node.

\
![mesh-to-sdf](Video/mesh-to-sdf.gif)

# acknowledgements

Sparky is based on the portal effect from [VFX Graph samples](https://github.com/Unity-Technologies/VisualEffectGraph-Samples) by [@JulienFryer](https://twitter.com/JulienFryer) and [@peeweekVFX](https://twitter.com/peeweekVFX).
