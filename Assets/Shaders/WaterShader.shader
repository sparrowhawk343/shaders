Shader "Unlit/WaterShader"
{
    Properties
    {
        _NoiseTex ("Noise Texture", 2D) = "white" {}
        _ShallowColor ("Shallow Color", Color) = (1,1,1,1)
        _DeepColor ("Deep Color", Color) = (0,0,0,1)

        _DepthFactor("Depth Factor", float) = 1.0
        _DepthPow("Depth Power", float) = 1.0

        _FogFadeRange ("Fog fade distance", Float) = 0.3
        _FogIntensity("Blend Intensity", Float) = 0.1

        _NormalTex1 ("Normal Map 1", 2D) = "bump" {}

        _RefractionStrength ("Refraction Strength", Range(0, 0.1)) = 1.0
        _RefractionVelocity ("Refraction Velocity", Vector) = (1,1,1,1)
        _EdgeThreshold ("Edge Threshold", float) = 1.0
        _NoiseStrength ("Noise Strength", float) = 1.0

        _Gravity ("Gravity", float) = 9.8

        _WaveA ("Wave A (xy = dir, z = steepness, w = length)", Vector) = (1, 0, 0.5, 0.24)
        _WaveB ("Wave B (xy = dir, z = steepness, w = length)", Vector) = (0, 1, 0.25, 0.4)
        _WaveC ("Wave B (xy = dir, z = steepness, w = length)", Vector) = (0, 2, 0.1, 0.3)
        
        _SpecGloss ("Specular Glossiness", Range(0, 1)) = 1.0
        _Opacity ("Opacity value for transparency", Range(0, 1)) = 1.0
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        Blend SrcAlpha OneMinusSrcAlpha
        LOD 100
        
        GrabPass  {"_SceneColorPass"}
        
        Pass
        {
            
            Tags
            {
                "LightMode" = "ForwardBase"
            }

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #include "UnityCG.cginc"
            #include "SharedFunctions.cginc"
           
            struct MeshData
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv0 : TEXCOORD0;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float4 screenPos: TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float3 worldNormal : TEXCOORD3;
                float3 tangent : TEXCOORD4;
                float3 bitangent : TEXCOORD5;
                float4 grabPos : TEXCOORD6;
            };

            sampler2D _NoiseTex;

            float4 _ShallowColor;
            float4 _DeepColor;

            float _DepthFactor;
            fixed _DepthPow;
            UNITY_DECLARE_DEPTH_TEXTURE(_CameraDepthTexture);
            sampler2D _CameraOpaqueTexture;

            float _FogFadeRange;
            float _FogIntensity;

            sampler2D _NormalTex1;

            float _RefractionStrength;
            float2 _RefractionVelocity;
            float _EdgeThreshold;
            float _NoiseStrength;

            float _Gravity;
            float2 _Direction;
            float4 _WaveA, _WaveB, _WaveC;
            float _SpecGloss;
            float _Opacity;

            sampler2D _SceneColorPass;

            Interpolators vert(MeshData v)
            {
                Interpolators i;

                //waves, start with a point on the grid and accumulate Gerstner waves
                float3 gridPoint = v.vertex.xyz;
                float3 tangent = float3(1, 0, 0);
                float3 bitangent = float3(0, 0, 1);
                float3 p = gridPoint;
                p += GerstnerWave(_WaveA, gridPoint, _Gravity, tangent, bitangent);
                p += GerstnerWave(_WaveB, gridPoint, _Gravity, tangent, bitangent);
                p += GerstnerWave(_WaveC, gridPoint, _Gravity, tangent, bitangent);

                float3 normal = normalize(cross(bitangent, tangent));

                v.vertex.xyz = p;
                v.normal = normal;
                
                i.vertex = UnityObjectToClipPos(v.vertex);

                i.uv0 = v.uv0; // world space
                i.worldNormal = UnityObjectToWorldNormal(v.normal);

                i.tangent = UnityObjectToWorldDir(tangent);
                i.bitangent = UnityObjectToWorldDir(bitangent);
                i.worldPos = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1));

                i.screenPos = ComputeScreenPos(i.vertex);
                i.grabPos = ComputeGrabScreenPos(i.vertex);
                COMPUTE_EYEDEPTH(i.screenPos.z);
                
                return i;
            }

            fixed4 frag(Interpolators i) : SV_Target
            {
                // normalize world normals, this made them less steppy and more smooth
                i.worldNormal = normalize(i.worldNormal);
                
                // refraction
                float2 RefractionNormals = i.uv0 + _Time.y * _RefractionVelocity;
                float3 TangentSpaceNormal = UnpackNormal(tex2D(_NormalTex1, RefractionNormals));
                float3x3 MtxTangentToWorld =
                {
                    i.tangent.x, i.bitangent.x, i.worldNormal.x,
                    i.tangent.y, i.bitangent.y, i.worldNormal.y,
                    i.tangent.z, i.bitangent.z, i.worldNormal.z
                };

                float3 WorldSpaceNormal = mul(MtxTangentToWorld, TangentSpaceNormal);
                float3 ViewSpaceNormal = WorldToViewDir(WorldSpaceNormal);
                float2 RefractionOffset = ViewSpaceNormal.xy * _RefractionStrength;


                // depth
                fixed4 ShallowColor = _ShallowColor;
                fixed4 DeepColor = _DeepColor;

                float4 DepthCoordinate = UNITY_PROJ_COORD(i.screenPos);
                float3 viewPos = mul(UNITY_MATRIX_V, float4(i.worldPos.xyz, 1));

                // negate this because it turned out the camera "forward" vector was pointing backwards
                float SurfaceDepth = -viewPos.z;

                // apply the refraction offset
                DepthCoordinate.xy += RefractionOffset;
                float BackgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, DepthCoordinate));

                // only refract if things are above water surface
                float DepthDifference = BackgroundDepth - SurfaceDepth;
                if (DepthDifference < 0)
                {
                    // prevent artifacts here
                    BackgroundDepth = LinearEyeDepth(
                        SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));
                }

                // fade based on depth
                float Depth = BackgroundDepth - i.screenPos.z;
                fixed DepthFade = saturate((abs(pow(Depth, _DepthPow))) / _DepthFactor);
                fixed4 DepthColor = lerp(ShallowColor, DeepColor, DepthFade);

                // fog based on depth (reuse from FogShader)
                float CameraDistance = distance(i.worldPos, _WorldSpaceCameraPos);

                CameraDistance *= _FogFadeRange;

                float t = saturate(CameraDistance * _FogIntensity);
                float3 FogColor = lerp(_ShallowColor, _DeepColor, t);

                // foam
                float EdgeDepth = InvLerp(0, _EdgeThreshold, Depth);
                float ClampedDepth = saturate(EdgeDepth);
                float Frequency = 2.6;
                float Noise = tex2D(_NoiseTex, i.uv0 / _NoiseStrength);
                float FoamWaveSpeed = 0.2;

                // this is W(x)
                float FoamWave = cos(Frequency * (ClampedDepth - (_Time.y + Noise * 10) * FoamWaveSpeed) * TAU) * 0.5 +
                    0.5;

                i.grabPos.xy += RefractionOffset;
                float4 SceneColor = tex2Dproj(_SceneColorPass, i.grabPos);
                
                // transparency
                DepthColor.xyz = InvLerp3(_ShallowColor.xyz, _DeepColor.xyz, DepthFade);
                // R(x) is 1-x (1 - ClampedDepth), hence W(x) * R(x)

                
                // specular lighting
                // direction to camera (view vector)
                float3 V = normalize(_WorldSpaceCameraPos - i.worldPos);
                float specExp = exp2(1 + _SpecGloss * 12);
                float3 L = UnityWorldSpaceLightDir(i.worldPos);
                float specular = BlinnPhong(i.worldNormal, L, V, specExp) * _LightColor0;
                
                
                // more transparency & return value
                float opacity = DepthColor.a * _Opacity;
                float3 BelowSurfaceColor = lerp((DepthColor.rgb + FogColor), SceneColor, _Opacity);
                return float4(BelowSurfaceColor + (1 - ClampedDepth) * FoamWave + specular, 1);
            }
            ENDCG
        }
    }
}