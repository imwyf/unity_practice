// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 9/Attenuation And Shadow Use Build-in Functions" {
	Properties {
		_Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
		_Specular ("Specular", Color) = (1, 1, 1, 1)
		_Gloss ("Gloss", Range(8.0, 256)) = 20
	}
	SubShader {
		Tags { "RenderType"="Opaque" }
		
		Pass {
			// Base Pass仅会执行一次，用于一个平行光
			// Pass for ambient light & first pixel light (directional light)
			Tags { "LightMode"="ForwardBase" }
			
			CGPROGRAM
			
			// Apparently need to add this declaration
			#pragma multi_compile_fwdbase	
			
			#pragma vertex vert
			#pragma fragment frag
			
			// Need these files to get built-in macros
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				// 声明一个用于对阴影纹理采样的变量（_ShadowCoord），参数：下一个可用的插值寄存器的索引值，效果：TEXCOORD2寄存器用来存储一个_ShadowCoord变量
				SHADOW_COORDS(2)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// Pass shadow coordinates to pixel shader
				// 计算阴影纹理坐标，把顶点坐标从模型空间变换到光源空间后存储到_ShadowCoord中
				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				// 环境光和自发光在Base Pass中计算
				fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
				
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

				// UNITY_LIGHT_ATTENUATION not only compute attenuation, but also shadow infos
				// 同时实现对阴影映射纹理采样和计算光照衰减，接受3个参数，将光照衰减和阴影值相乘后的结果存储到第一个参数中
				// 第二个参数是结构体v2f,使用其中的_ShadowCoord(光源空间坐标)对阴影映射纹理采样得到阴影值
				// 第三个参数是片元的世界空间坐标，会转换成光源空间坐标，对光照衰减纹理采样来得到光照衰减
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				return fixed4(ambient + (diffuse + specular) * atten, 1.0);// 光照颜色乘上阴影和衰减，实现接收阴影
			}
			
			ENDCG
		}
		
		Pass {
			// 每个逐像素光源会执行一次Additional Pass
			// Pass for other pixel lights
			Tags { "LightMode"="ForwardAdd" }
			
			Blend One One
			
			CGPROGRAM
			
			// Apparently need to add this declaration
			#pragma multi_compile_fwdadd
			// Use the line below to add shadows for point and spot lights
			//			#pragma multi_compile_fwdadd_fullshadows
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			fixed4 _Diffuse;
			fixed4 _Specular;
			float _Gloss;
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float3 worldNormal : TEXCOORD0;
				float3 worldPos : TEXCOORD1;
				SHADOW_COORDS(2)
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				o.worldNormal = UnityObjectToWorldNormal(v.normal);
				
				o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				
				// Pass shadow coordinates to pixel shader
				TRANSFER_SHADOW(o);
				
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed3 worldNormal = normalize(i.worldNormal);
				fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				
				fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * max(0, dot(worldNormal, worldLightDir));

				fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
				fixed3 halfDir = normalize(worldLightDir + viewDir);
				fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(worldNormal, halfDir)), _Gloss);

				// UNITY_LIGHT_ATTENUATION not only compute attenuation, but also shadow infos
				// UNITY_LIGHT_ATTENUATION会根据该Pass处理的光源类型，使用内置变量和宏计算不同的衰减因子
				// 默认Additional Pass不支持点光源和聚光灯的阴影，更改#pragma可以让UNITY_LIGHT_ATTENUATION也计算这两种光源的阴影值
				UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);
				
				return fixed4((diffuse + specular) * atten, 1.0);
			}
			
			ENDCG
		}
	}
	FallBack "Specular" // Fallback中的内置Shader会自动实现LightMode=ShadowCaster的pass来更新光源的阴影映射纹理和摄像机的深度纹理
}
