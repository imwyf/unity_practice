// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 6/Diffuse Vertex-Level" {
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1) // 控制物体表面颜色，调一调就懂了
	}
	SubShader {
		Pass { 
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			
			fixed4 _Diffuse;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				fixed3 color : COLOR;
			};
			
			v2f vert(a2v v) {
				v2f o;
				// Transform the vertex from object space to projection space
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// Get ambient term
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				// Transform the normal from object space to world space
				fixed3 worldNormal = normalize(mul(v.normal, (float3x3)unity_WorldToObject));
				// Get the light direction in world space
				fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
				// Compute diffuse term
				// _Diffuse就是后面会提到的反照率，albedo。物体表现出来的颜色是反射的光的颜色，因此反照率代表反射哪些光，因此改变反照率就等同于改变物体颜色
				// _LightColor0是光强和光源颜色的乘积，光源颜色x反照率=反射颜色
				// 后面计算的那些与光强和法线有关的值是一个系数，这个系数乘上反射颜色使得某些点的颜色暗淡/明亮一点，这样就可以体现出“光泽”
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLight));
				
				o.color = ambient + diffuse;
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				return fixed4(i.color, 1.0);
			}
			
			ENDCG
		}
	}
	FallBack "Diffuse"
}
