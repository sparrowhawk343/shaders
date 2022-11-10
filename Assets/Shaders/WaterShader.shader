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
        _NormalTex2 ("Normal Map 2", 2D) = "bump" {}
        
        _RefractionStrength ("Refraction Strength", Range(0, 0.1)) = 1.0
        _RefractionVelocity ("Refraction Velocity", Vector) = (1,1,1,1)
        _EdgeThreshold ("Edge Threshold", float) = 1.0
        _NoiseStrength ("Noise Strength", float) = 1.0
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
            sampler2D _NormalTex2;
            
            float _RefractionStrength;
            float2 _RefractionVelocity;
            float _EdgeThreshold;
            float _NoiseStrength;

            Interpolators vert(MeshData v)
            {
                Interpolators i;
                
                i.vertex = UnityObjectToClipPos(v.vertex);
                i.uv0 = v.uv0; // world space
                i.worldNormal = UnityObjectToWorldNormal(v.normal);

                i.tangent = UnityObjectToWorldDir(v.tangent.xyz);
                i.bitangent = cross(i.worldNormal, i.tangent) * (v.tangent.w * unity_WorldTransformParams.w);

                i.worldPos = mul(UNITY_MATRIX_M, float4(v.vertex.xyz, 1)); // world space

                i.screenPos = ComputeScreenPos(i.vertex);
                COMPUTE_EYEDEPTH(i.screenPos.z);

                return i;
            }

            fixed4 frag(Interpolators i) : SV_Target
            {
                
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

                // apply the refraction offset
                DepthCoordinate.xy += RefractionOffset;
                float BackgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, DepthCoordinate));
                // surface depth, to exclude things above surface from refraction
                float SurfaceDepth = UNITY_Z_0_FAR_FROM_CLIPSPACE(i.screenPos.z);

                float DepthDifference = BackgroundDepth - SurfaceDepth;
                

                // only refract if things are above water surface
                // change this magic number to be a threshold tweakable in-editor
                if (DepthDifference < 10)
                {
                    // prevent artifacts here
                    BackgroundDepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE_PROJ(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPos)));
                }
                
                float Depth = BackgroundDepth - i.screenPos.z;
                fixed DepthFade = saturate((abs(pow(Depth, _DepthPow))) / _DepthFactor);

                fixed4 DepthColor = lerp(ShallowColor, DeepColor, DepthFade);
                

                // fog based on depth (reuse from FogShader)
                float CameraDistance = distance(i.worldPos, _WorldSpaceCameraPos);

                CameraDistance *= _FogFadeRange;

                float t = saturate(CameraDistance * _FogIntensity);
                float FogColor = lerp(_ShallowColor, _DeepColor, t);

                // define foam gradient (0-1 from edge)
                // find edge based on depth, if depth is 0-0.2, that is edge
                // project foam noise texture kinda like normals rn

                float EdgeDepth = InvLerp(0, _EdgeThreshold, Depth);
                float ClampedDepth = saturate(EdgeDepth);
                float Frequency = 2.6;
                float Noise = tex2D(_NoiseTex, i.uv0 / _NoiseStrength);
                float FoamWaveSpeed = 0.2;
                
                // this is W(x)
                float FoamWave = cos(Frequency * (ClampedDepth - (_Time.y + Noise * 10) * FoamWaveSpeed) * TAU) * 0.5 +
                    0.5;

                // transparency
                // DepthColor.a = lerp(DepthColor.a, SceneColor.a, _TransparencyFactor * (1 - DepthFade));
                DepthColor.xyz = InvLerp3(_ShallowColor.xyz, _DeepColor.xyz, DepthFade);
                // R(x) is 1-x (1 - ClampedDepth), hence W(x) * R(x)
                return (DepthColor + FogColor) + (1 - ClampedDepth) * FoamWave;
            }
            ENDCG
        }
    }
}

// TODO:
// ask Freya about subsurface artifacts
// expose depth check threshold
// implement vertex displacing waves
// clean up code
// make checkboxes for features for easy presentation
// record walkthrough of project