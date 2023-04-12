// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 5/Simple Shader" {
    Properties {
        _Color ("Color Tint", Color) = (1, 1, 1, 1)
    }
    SubShader {
        Pass {
            CGPROGRAM

            #pragma vertex vert
            #pragma fragment frag
            
            uniform fixed4 _Color;

            // 整个a2v的变量都在模型空间下
            struct a2v {
                float4 vertex : POSITION; // POSITION->模型空间的顶点位置
                float3 normal : NORMAL; // NORMAL->模型空间的顶点法线
                float4 texcoord : TEXCOORD0;
            };
            
            struct v2f {
                float4 pos : SV_POSITION; // SV_POSITION->裁剪空间的顶点位置
                fixed3 color : COLOR0;
            };
            
            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.color = v.normal * 0.5 + fixed3(0.5, 0.5, 0.5);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target { // SV_Target->意味着return到裁剪空间去
                fixed3 c = i.color;
                c *= _Color.rgb;
                return fixed4(c, 1.0);
            }

            ENDCG
        }
    }
}
