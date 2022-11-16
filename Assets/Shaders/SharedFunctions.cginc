#define TAU 6.28318530718
#include <UnityCG.cginc>

#include "UnityLightingCommon.cginc"
#include "AutoLight.cginc"

// v =  lerp(a,b,t)
// t = ilerp(a,b,v)
float InvLerp(float a, float b, float v)
{
    return (v - a) / (b - a);
}

float4 InvLerp(float4 a, float4 b, float4 v)
{
    return (v - a) / (b - a);
}

float3 InvLerp3(float3 a, float3 b, float3 v)
{
    return (v - a) / (b - a);
}

float Lambert(float3 N, float3 L)
{
    return saturate(dot(N, L));
}

float BlinnPhong(float3 N, float3 L, float3 V, float specExp)
{
    float3 H = normalize(L + V);
    return pow(max(0, dot(H, N)), specExp);
}

float3 ApplyLighting(float3 surfColor, float3 N, float3 wPos, float gloss)
{
    // diffuse lighting
    float3 L = UnityWorldSpaceLightDir(wPos); // light direction
    float3 lightColor = _LightColor0;
    float3 diffuse = Lambert(N, L) * lightColor;

    // specular lighting
    float3 V = normalize(_WorldSpaceCameraPos - wPos); // direction to camera (view vector)
    float specExp = exp2(1 + gloss * 12);
    float specular = BlinnPhong(N, L, V, specExp) * lightColor;

    // composite and return
    return surfColor * diffuse + specular;
}

float3 WorldToViewDir(in float3 vec)
{
    return mul((float3x3)UNITY_MATRIX_V, vec).xyz;
}

float3 GerstnerWave(float4 wave, float3 gridPoint, float gravity, inout float3 tangent, inout float3 bitangent)
{
    float steepness = wave.z;
    float wavelength = wave.w;

    float k = TAU / wavelength;

    // c for phase speed based on gravity and number of waves
    // lower gravity = slower waves
    float c = sqrt(gravity / k);
    float2 d = normalize(wave.xy);
    float f = k * (dot(d, gridPoint.xz) - c * _Time.y);
    float a = steepness / k;

    // correcting normal vectors
    tangent += float3(
        -d.x * d.x * (steepness * sin(f)),
        d.x * (steepness * cos(f)),
        -d.x * d.y * (steepness * sin(f))
    );
    bitangent += float3(
        -d.x * d.y * (steepness * sin(f)),
        d.y * (steepness * cos(f)),
        -d.y * d.y * (steepness * sin(f))
    );

    return float3(
        d.x * (a * cos(f)),
        a * sin(f),
        d.y * (a * cos(f))
    );
}
