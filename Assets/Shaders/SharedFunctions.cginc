#define TAU 6.28318530718
#include <UnityCG.cginc>

#include "UnityLightingCommon.cginc"

// v =  lerp(a,b,t)
// t = ilerp(a,b,v)
float InvLerp( float a, float b, float v )
{
    return (v-a)/(b-a);
}
float4 InvLerp( float4 a, float4 b, float4 v )
{
    return (v-a)/(b-a);
}

float3 InvLerp3( float3 a, float3 b, float3 v )
{
    return (v-a)/(b-a);
}


float Lambert( float3 N, float3 L )
{
    return saturate(dot(N,L));
}

float BlinnPhong( float3 N, float3 L, float3 V, float specExp )
{
    float3 H = normalize( L + V );
    return pow( max(0,dot(H,N)), specExp );
}

float3 ApplyLighting( float3 surfColor, float3 N, float3 wPos, float gloss )
{

    // diffuse lighting
    float3 L = UnityWorldSpaceLightDir(wPos); // light direction
    float3 lightColor = _LightColor0;
    float3 diffuse = Lambert(N,L)*lightColor;

    // specular lighting
    float3 V = normalize(_WorldSpaceCameraPos - wPos ); // direction to camera (view vector)
    float specExp = exp2(1+gloss*12);
    float specular = BlinnPhong(N,L,V,specExp) * lightColor;

    // composite and return
    return surfColor*diffuse + specular;
}

float2 MoveTexture(float2 UV, float Speed, float Scale)
{
    float Offset = _Time.y * Speed;

    return UV * Scale + Offset;
}


float3 WorldToViewDir( in float3 vec )
{
    return mul((float3x3)UNITY_MATRIX_V, vec).xyz;
}


// functions for generating gradient noise for water refraction
float2 unity_gradientNoise_dir(float2 p)
{
    p = p % 289;
    float x = (34 * p.x + 1) * p.x % 289 + p.y;
    x = (34 * x + 1) * x % 289;
    x = frac(x / 41) * 2 - 1;
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

float unity_gradientNoise(float2 p)
{
    float2 ip = floor(p);
    float2 fp = frac(p);
    float d00 = dot(unity_gradientNoise_dir(ip), fp);
    float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
    float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
    float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
    fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
    return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
}

void Unity_GradientNoise_float(float2 UV, float Scale, out float Out)
{
    Out = unity_gradientNoise(UV * Scale) + 0.5;
}