Shader "Unlit/SDFTracer"
{
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            HLSLPROGRAM
            #pragma target 5.0
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
            #include "Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/ShaderVariables.hlsl"

            struct VertOutput
            {
                float4 vertex : SV_POSITION;
                float3 world : TEXCOORD0;
            };

            struct FragOutput
            {
                float4 color : SV_Target;
                float depth : SV_Depth;
            };

            float4 _Color;
            float3 _TestPosition;
            float4x4 _WorldToSDFSpace;
            sampler3D _SDF;
            float _Margin;
            float3 _BoxSize;
            float3 _BoxPos;
            float3 _LightColor;
            float3 _LightDir;
            float3 _Ambient;
            float3 _Albedo;
            float3 _Sky;
            float4 _ScatterParams;

            #define SCATTER_AMOUNT _ScatterParams.x
            #define SCATTER_START _ScatterParams.y
            #define SCATTER_STEP _ScatterParams.z
            #define SCATTER_MAX_DEPTH _ScatterParams.w

            float _DirScatterAmount;
            int _DirScatterMaxIterations;
            int _DirScatterMaxIterationsSecondary;
            float _ExtinctionCoeff;
            float _Anisotropy;
            float _BlendDistance;
            int _Mode;

            #define BOX_SCENE 0
            #define SPHERES_SCENE 1

            StructuredBuffer<float4> _Spheres;


            VertOutput vert (float4 vertex : POSITION)
            {
                VertOutput o;
                float3 positionRWS = TransformObjectToWorld(vertex.xyz);
                o.vertex = TransformWorldToHClip(positionRWS);
                o.world = GetAbsolutePositionWS(positionRWS);
                return o;
            }

            float SDFTex(float3 worldPos, float margin)
            {
                float3 sdfLocalPos = mul(_WorldToSDFSpace, float4(worldPos, 1)).xyz;
                float sdf = tex3Dlod(_SDF, float4(sdfLocalPos, 0)).r;
                // -_Margin to be able to converge on an isosurface other than 0.
                sdf -= margin;
                return sdf;
            }

            float Box(float3 worldPos, float radius)
            {
                float3 d = abs(worldPos - _BoxPos) - _BoxSize + radius;
                return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0)) - radius;
            }

            float Sphere(float3 worldPos, float radius)
            {
                return length(worldPos) - radius;
            }

            float SmoothMinCubic(float a, float b, float k)
            {
                float h = max(k - abs(a - b), 0.0);
                return min(a, b) - h * h * h / (6.0 * k * k);
            }

            float SmoothMaxCubic(float a, float b, float k)
            {
                float h = max(k - abs(a - b), 0.0);
                return max(a, b) + h * h * h / (6.0 * k * k);
            }

            #define r(x)     frac(1e4 * sin((x) * 541.17))      // rand, signed rand   in 1, 2, 3D.
            #define sr2(x)   ( r(float2(x, x + 0.1)) * 2.0 - 1.0 )
            #define sr3(x)   ( r(float4(x, x + 0.1, x + 0.2, 0)) * 2.0 - 1.0 )

            float SpheresScene(float3 worldPos)
            {
                uint count, stride;
                _Spheres.GetDimensions(count, stride);
                float dist = 10000000.0;
                for (uint i = 0; i < count; i++)
                {
                    float4 sphere = _Spheres[i];
                    dist = SmoothMinCubic(dist, Sphere(worldPos - sphere.xyz, sphere.w), _BlendDistance);
                }

                dist = SmoothMaxCubic(-SDFTex(worldPos, _Margin), dist, _BlendDistance);

                return dist;
            }

            float BoxScene(float3 worldPos)
            {
                float dist = Box(worldPos, 0.03);
                dist = SmoothMaxCubic(-SDFTex(worldPos, _Margin), dist, 0.1);

                return dist;
            }

            float SampleSDF(float3 worldPos)
            {
                if (_Mode == BOX_SCENE)
                    return BoxScene(worldPos);
                else
                    return SpheresScene(worldPos);
            }

            float3 CalcNormal(float3 p)
            {
                // Neighborhood size should be the size of a voxel in case of the sdf tex.
                // TODO: make dynamic
                // TODO: adjust for the fact we're sampling in a tetrahedral pattern.
                float eps = 0.02;
                
                float2 off = float2(1, -1);
                return normalize(   off.xyy * SampleSDF(p + off.xyy * eps) + 
                                    off.yyx * SampleSDF(p + off.yyx * eps) + 
                                    off.yxy * SampleSDF(p + off.yxy * eps) + 
                                    off.xxx * SampleSDF(p + off.xxx * eps) );
            }

            float G1V(float nv, float k)
            {
                return 1.0 / (nv * (1.0 - k) + k);
            }

            float GGX(float3 n, float3 v, float3 l, float roughness, float f0)
            {
                float alpha = roughness * roughness;

                float3 h = normalize(v + l);
                
                float nl = saturate(dot(n, l));
                float nv = saturate(dot(n, v));
                float nh = saturate(dot(n, h));
                float lh = saturate(dot(l, h));
                
                float f, d, vis;
                
                float alphaSqr = alpha * alpha;
                float denom = nh * nh * (alphaSqr - 1.0) + 1.0;
                d = alphaSqr / (PI * denom * denom);

                float lh5 = pow(1.0 - lh, 5.0);
                f = f0 + (1.0 - f0) * lh5;

                float k = alpha;
                return nl * d * f * G1V(nl, k) * G1V(nv, k);
            }

            float Scatter(float3 p, float3 v, float3 n)
            {
                float3 d = refract(v, n, 1.0/1.5);
                float3 o = p;
                float a = 0.0;

                for(float i = SCATTER_START; i < SCATTER_MAX_DEPTH; i += SCATTER_STEP)
                {
                    o += i*d;
                    float t = SampleSDF(o);
                    if (t > 0)
                        break;
                    a += t;
                }
                float thickness = max(0.01, -a);
                return SCATTER_AMOUNT * pow(SCATTER_MAX_DEPTH*0.5, 3.0) / thickness;
            }

            float Extinction(float thickness)
            {
                return exp(-_ExtinctionCoeff * thickness);
            }

            float Anisotropy(float costheta)
            {
                float g = _Anisotropy;
                float gsq = g*g;
                float denom = 1 + gsq - 2.0 * g * costheta;
                denom = denom * denom * denom;
                denom = sqrt(max(0, denom));
                return (1 - gsq) / denom;
            }

            float DirScatter(float3 p, float3 v, float3 n)
            {
                // I mean, there's a lot to trim here, but we're just having fun
                float3 d = refract(v, n, 1.0/1.5);
                float a = 0.0;
                float3 pos = p;

                pos += SCATTER_START * d;
                for (int k = 0; k < 10; k++)
                {
                    float t = SampleSDF(pos);
                    pos -= t * d;
                }

                float thickness = length(p - pos);
                float stepSize = thickness / (float)_DirScatterMaxIterations;
                
                pos = p + SCATTER_START * d;
                for(int i = 0; i < _DirScatterMaxIterations; i++)
                {
                    pos += stepSize * d;
                    float t = SampleSDF(pos);
                    if (t >= 0)
                        break;

                    float3 posbis = pos;
                    float tbis = t;
                    for (int j = 0; j < _DirScatterMaxIterationsSecondary; j++)
                    {
                        posbis += tbis * _LightDir;
                        tbis = SampleSDF(posbis);
                        if (tbis >= 0)
                            break;
                    }

                    float thicknessToLight = length(pos - posbis);
                    float inscatter = Extinction(thicknessToLight);
                    float thicknessToInscatterPos = length(p - pos);
                    a += inscatter * Extinction(thicknessToInscatterPos) / max(thickness, 0.01);
                }

                float aniso = Anisotropy(dot(v, -_LightDir));
                return _DirScatterAmount * a * aniso;
            }

            float3 Shade(float3 p, float3 v, float3 n)
            {
                float3 l = -_LightDir;
                
                float fresnel = pow(max(0.0, 1.0 + dot(n, v)), 5.0);
                float diffuse = max(0.0, dot(n, l));
                float spec = GGX(n, v, l, 3.0, fresnel);

                // shading crimes
                fresnel *= 0.3;
                diffuse *= 0.3;
                spec *= 50.0;

                float scatter = Scatter(p, v, n) + DirScatter(p, v, n);
                
                return _Ambient + fresnel * _Sky + _LightColor * (_Albedo * diffuse + _Albedo * scatter + spec);
            }

            FragOutput frag (VertOutput i)
            {
                float3 cam = GetAbsolutePositionWS(GetPrimaryCameraPosition());
                float3 pos = i.world;

                float3 dir = normalize(pos - cam);

                for (int k = 0; k < 128; k++)
                {
                    float dist = SampleSDF(pos);

                    // We don't early-out, because going through the full iteration count
                    // converges on the surface much better.
                    pos += dir * dist;
                }

                float3 normal = CalcNormal(pos);

                FragOutput o;
                o.color = Shade(pos, dir, normal).xyzz * 0.5;
                o.depth = ComputeNormalizedDeviceCoordinatesWithZ(GetCameraRelativePositionWS(pos), GetWorldToHClipMatrix()).z;

                return o;
            }
            ENDHLSL
        }
    }
}
