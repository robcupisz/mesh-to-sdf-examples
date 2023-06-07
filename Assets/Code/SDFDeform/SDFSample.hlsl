#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Texture.hlsl"

SamplerState SDF_linear_clamp_sampler;

void SDFSample_float(float3 PositionWS, float4x4 WorldToSDF, UnityTexture3D SDF, out float Distance)
{
    float3 sdfLocalPos = mul(WorldToSDF, float4(PositionWS, 1)).xyz;
    Distance = SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos, 0).r;
}

void SDFSampleNormal_float(float3 PositionWS, float4x4 WorldToSDF, UnityTexture3D SDF, out float Distance, out float3 Normal)
{
    float3 sdfLocalPos = mul(WorldToSDF, float4(PositionWS, 1)).xyz;
    Distance = SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos, 0).r;

    float3 size;
    float levels;
    SDF.tex.GetDimensions(0, size.x, size.y, size.z, levels); 
    float2 k = float2(1, -1);
    // A simple texel size estimate, since the tetrahedral sampling pattern requires more care to get the right eps
    float avgSize = dot(size, 0.33);
    // TODO: get rid of the magic 4 mult 
    float eps = 4.0/avgSize;
    Normal = normalize( k.xyy * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.xyy * eps, 0).r + 
                        k.yyx * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.yyx * eps, 0).r + 
                        k.yxy * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.yxy * eps, 0).r + 
                        k.xxx * SDF.SampleLevel(SDF_linear_clamp_sampler, sdfLocalPos + k.xxx * eps, 0).r);
}