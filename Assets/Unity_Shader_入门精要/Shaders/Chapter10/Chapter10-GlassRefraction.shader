// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unity Shaders Book/Chapter 10/Glass Refraction" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {} // 该玻璃的材质纹理
		_BumpMap ("Normal Map", 2D) = "bump" {} // 玻璃的法线纹理
		_Cubemap ("Environment Cubemap", Cube) = "_Skybox" {} // 模拟反射的环境纹理
		_Distortion ("Distortion", Range(0, 100)) = 10 // 控制模拟折射时图像的扭曲程度
		_RefractAmount ("Refract Amount", Range(0.0, 1.0)) = 1.0 // 混合折射和反射效果
	}
	SubShader {
		// We must be transparent, so other objects are drawn before this one.
		// 涉及透明物体，用Transparent队列，确保其他所有不透明物体都已经被渲染到屏幕上之后再渲染透明物体
		// RenderType = Opaque是为了在使用着色器替换时，该物体可以被正确渲染
		Tags { "Queue"="Transparent" "RenderType"="Opaque" } 
		
		// This pass grabs the screen behind the object into a texture.
		// We can access the result in the next pass as _RefractionTex
		// 由于在抓取之前，不透明物体已经渲染完成，因此需要体现折射的内部物体也已经渲染完成
		GrabPass { "_RefractionTex" } // 抓取得到的屏幕图像将会被存入_RefractionTex，这个图像体现的就是没有被折射影响的毛玻璃内部物体原来的位置
		
		Pass {		
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _BumpMap;
			float4 _BumpMap_ST;
			samplerCUBE _Cubemap;
			float _Distortion;
			fixed _RefractAmount;
			sampler2D _RefractionTex; // 抓取得到的屏幕图像存在这里，这个图像就是一个屏幕空间的图像
			float4 _RefractionTex_TexelSize; // 纹理的纹素大小，例如大小为256X512的纹理，它的纹素大小为(1/256, 1/512)
			
			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT; 
				float2 texcoord: TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 scrPos : TEXCOORD0; // 顶点在被抓取的屏幕图像的屏幕空间坐标
				float4 uv : TEXCOORD1;
				float4 TtoW0 : TEXCOORD2;  
				float4 TtoW1 : TEXCOORD3;  
				float4 TtoW2 : TEXCOORD4; 
			};
			
			v2f vert (a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				
				// ComputeGrabScreenPos类似于computeScreenPos，把坐标从裁剪空间变换到屏幕空间
				o.scrPos = ComputeGrabScreenPos(o.pos);
				
				// 计算主纹理和法线纹理的偏移和缩放，得到采样坐标
				o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.uv.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
				// 把法线方向从切线空间变换到世界空间
				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;  
				fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);  
				fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);  
				fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w; 
				
				o.TtoW0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);  
				o.TtoW1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);  
				o.TtoW2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);  
				
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target {		
				float3 worldPos = float3(i.TtoW0.w, i.TtoW1.w, i.TtoW2.w);
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				
				// Get the normal in tangent space
				// 对法线纹理进行采样，得到切线空间下的法线方向
				fixed3 bump = UnpackNormal(tex2D(_BumpMap, i.uv.zw));	
				
				// Compute the offset in tangent space
				// 通过法线纹理计算一个偏移量，用这个偏移量扰动被抓取的屏幕图像纹理的采样坐标，实现折射看到的内部物体“变形”的效果
				// 选择使用切线空间下的法线方向来计算偏移，是因为该空间下的法线可以反映顶点局部空间下的法线方向
				float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy; // 当毛玻璃表面越是粗糙（由bump纹理体现），偏移量就会越大
				i.scrPos.xy = offset * i.scrPos.z + i.scrPos.xy; // 与书上不同，多乘了一个i.scrPos.z，会让变形程度随着距离摄像机的远近发生变化
				fixed3 refrCol = tex2D(_RefractionTex, i.scrPos.xy/i.scrPos.w).rgb; // 用采样坐标去采样抓取的毛玻璃内部的图像纹理，由于内部的不透明物体已经提前渲染好，因此采样相当于是用这次渲染结果覆盖那个抓取的没被折射影响的图片（对于毛玻璃部分）
				
				// Convert the normal to world space
				bump = normalize(half3(dot(i.TtoW0.xyz, bump), dot(i.TtoW1.xyz, bump), dot(i.TtoW2.xyz, bump)));
				fixed3 reflDir = reflect(-worldViewDir, bump); //根据光路可逆，得到反射方向
				fixed4 texColor = tex2D(_MainTex, i.uv.xy); // 采样主纹理贴图
				fixed3 reflCol = texCUBE(_Cubemap, reflDir).rgb * texColor.rgb; // 用反射向量在Cubemap上采样来模拟毛玻璃映射环境的“镜子”效果，乘上主纹理颜色来控制反射的颜色
				
				fixed3 finalColor = reflCol * (1 - _RefractAmount) + refrCol * _RefractAmount; // 混合反射和折射
				
				return fixed4(finalColor, 1);
			}
			
			ENDCG
		}
	}
	
	FallBack "Diffuse"
}
