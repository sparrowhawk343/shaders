Shader "Unlit/FogShader"
{
    // path (not the asset path)
    Properties
    {
        // input data to this shader (per-material)
        _ColorA ("Color A", Color) = (1,1,1,1)
        _ColorB ("Color B", Color) = (0,0,0,0)
        _MainTex ("Main color texture", 2D) = "black" {}
		_FogFadeRange ("Fog fade distance", Float) = 0.3
        _FogIntensity("Blend Intensity", Float) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry" // render order
        }

        Pass
        {
            // render setup
            // ZTest On
            // ZWrite On
            // Blend x y

            CGPROGRAM

            // what functions to use for what
            #pragma vertex vert
            #pragma fragment frag

            // bunch of unity utility functions and variables
            #include "UnityCG.cginc"
            // #include "SharedFunctions.cginc"


            // per-vertex input data from the mesh
            struct MeshData {
                float3 vertex : POSITION;  // vertex position
                float3 normal : NORMAL;
                float4 tangent : TANGENT; // xyz = tangent direction, w = flip sign -1 or 1
                float2 uv0 : TEXCOORD0;    // uv channel 0
                // float2 uv1 : TEXCOORD1;     // uv channel 1
                // float4 uv2 : TEXCOORD2;     // uv channel 2
                // float4 uv3 : TEXCOORD3;     // uv channel 3
            };

            // the struct for sending data from the vertex shader to the fragment shader
            struct Interpolators {
                float4 vertex : SV_POSITION; // clip space vertex position
                // arbitrary data we want to send:
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv0 : TEXCOORD2;
                float4 screenPos : TEXCOORD3;
                // float4 name : TEXCOORD2;
            };

            // property variable declaration
            float4 _ShallowColor;
            float4 _DeepColor;
            sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
			float _FogFadeRange;
			float _FogIntensity;
            
            
            // vertex shader - foreach( vertex )
            Interpolators vert ( MeshData v ) {
                Interpolators i;
                
                // transforms from local space to clip space
                // usually using the matrix called UNITY_MATRIX_MVP
                // model-view-projection matrix (local to clip space)
                i.vertex = UnityObjectToClipPos(v.vertex);

                // pass coordinates to the fragment shader
                i.uv0 = v.uv0; // world space
                i.worldNormal = UnityObjectToWorldNormal( v.normal );
                i.worldPos = mul( UNITY_MATRIX_M, float4( v.vertex, 1 ) ); // world space
                //i.screenPos = ComputeScreenPos(i.vertex);
                return i;
            }

            // fragment shader - foreach( fragment/pixel )
            float4 frag (Interpolators i) : SV_Target {
				float cameraDistance = distance(i.worldPos, _WorldSpaceCameraPos);
				
				cameraDistance *= _FogFadeRange;
				
				float t = saturate(cameraDistance * _FogIntensity);
                return lerp(_ShallowColor, _DeepColor, t);
                
            }
            ENDCG
        }
    }
}