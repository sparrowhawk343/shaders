Shader "Unlit/MossRockShader"
{
    Properties
    {
        _ColorA ("Color A", Color) = (1,1,1,1)
        _ColorB ("Color B", Color) = (1,1,1,1)

        _MainTex ("Main color texture", 2D) = "black" {}
        _HeightMap ("Height", 2D) = "black" {}
        _MossTex ("Moss texture", 2D) = "black" {}
        _BlendIntensity("Blend Intensity", Float) = 1
        
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
            sampler2D _MainTex;
            sampler2D _HeightMap;
            sampler2D _MossTex;
            float _BlendIntensity; 

            Interpolators vert ( MeshData v ) {
                Interpolators i;
                
                float height = tex2Dlod( _HeightMap, float4(v.uv0,0,0));
                v.vertex += v.normal * height;
                
                i.vertex = UnityObjectToClipPos(v.vertex);
                i.uv0 = v.uv0;
                i.worldNormal = UnityObjectToWorldNormal( v.normal );
                i.worldPos = mul( UNITY_MATRIX_M, float4( v.vertex, 1 ) );
                
                return i;
            }

            float4 frag (Interpolators i) : SV_Target {
                float4 texColor = tex2D( _MainTex, i.uv0 );
                float4 mossColor = tex2D( _MossTex, i.uv0 );
                float t = saturate(i.worldNormal.y * _BlendIntensity / 5);
                return lerp( texColor, mossColor, t );
                
            }
            ENDCG
        }
    }
}