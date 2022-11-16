Shader "Unlit/FogShader"
{
    Properties
    {
        _ShallowColor ("Shallow Color", Color) = (1,1,1,1)
        _DeepColor ("Deep Color", Color) = (0,0,0,0)
        _MainTex ("Main color texture", 2D) = "black" {}
		_FogFadeRange ("Fog fade distance", Float) = 0.3
        _FogIntensity("Blend Intensity", Float) = 0.1
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "Queue"="Geometry"
        }

        Pass
        {
            CGPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            
            struct MeshData {
                float3 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT; 
                float2 uv0 : TEXCOORD0;
            };

            
            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv0 : TEXCOORD2;
            };
            
            float4 _ShallowColor;
            float4 _DeepColor;
            sampler2D _CameraDepthTexture;
            sampler2D _MainTex;
			float _FogFadeRange;
			float _FogIntensity;
            
            Interpolators vert ( MeshData v ) {
                Interpolators i;
                
                i.vertex = UnityObjectToClipPos(v.vertex);
                
                i.uv0 = v.uv0;
                i.worldNormal = UnityObjectToWorldNormal( v.normal );
                i.worldPos = mul( UNITY_MATRIX_M, float4( v.vertex, 1 ) );
                return i;
            }

            float4 frag (Interpolators i) : SV_Target {
				float CameraDistance = distance(i.worldPos, _WorldSpaceCameraPos);
				
				CameraDistance *= _FogFadeRange;
				
				float t = saturate(CameraDistance * _FogIntensity);
                return lerp(_ShallowColor, _DeepColor, t);
                
            }
            ENDCG
        }
    }
}