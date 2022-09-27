Shader "ShaderLib/DualBlur"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		_Offset ("Offset", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
        LOD 100
        Fog {Mode Off}

		HLSLINCLUDE
		
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		
		struct AttributesDefault
		{
		    float3 vertex : POSITION;
			float2 texcoord : TEXCOORD0;
		};
		
		struct v2f_DownSample
		{
			float4 vertex : SV_POSITION;
			float2 texcoord : TEXCOORD0;
			float2 uv : TEXCOORD1;
			float4 uv01 : TEXCOORD2;
			float4 uv23 : TEXCOORD3;
		};
		
		struct v2f_UpSample
		{
			float4 vertex: SV_POSITION;
			float2 texcoord: TEXCOORD0;
			float4 uv01: TEXCOORD1;
			float4 uv23: TEXCOORD2;
			float4 uv45: TEXCOORD3;
			float4 uv67: TEXCOORD4;
		};
		
		TEXTURE2D(_MainTex);
		SAMPLER(sampler_MainTex);

		CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_TexelSize;
			float4 _MainTex_ST;
			float _Offset;
        CBUFFER_END

		float2 TransformTriangleVertexToUV(float2 vertex)
		{
		    float2 uv = (vertex + 1.0) * 0.5;
		    return uv;
		}
		
		v2f_DownSample vert_down_sample(AttributesDefault  v)
		{
		   v2f_DownSample o;
		   o.vertex = TransformObjectToHClip(v.vertex.xyz);
		   o.texcoord  = v.texcoord;
		   float2 uv = TRANSFORM_TEX(o.texcoord, _MainTex);
        	
		   _MainTex_TexelSize *= 0.5;
		   float offset = float2(1 + _Offset, 1 + _Offset);
		   o.uv = uv;
		   o.uv01.xy = uv - _MainTex_TexelSize * offset; // 左下
		   o.uv01.zw = uv + _MainTex_TexelSize * offset; // 右上
		   o.uv23.xy = uv - float2(_MainTex_TexelSize.x, - _MainTex_TexelSize.y) * offset; //左上
		   o.uv23.zw = uv + float2(_MainTex_TexelSize.x, - _MainTex_TexelSize.y) * offset; //右下
		   return o;
		}

		//降采样加权平均，中心原点为4倍权重
		half4 frag_down_sample(v2f_DownSample i) : SV_Target{
		   half4 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * 4;
		   sum+= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
		   sum+= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw);
		   sum+= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy);
		   sum+= SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw);
		   return sum * 0.125;
		}

		//顶点着色器，负责处理uv的偏移
		v2f_UpSample vert_up_sample(AttributesDefault v)
		{
		   v2f_UpSample o;
           o.vertex = TransformObjectToHClip(v.vertex.xyz);
		   o.texcoord  = v.texcoord;
		   float2 uv = TRANSFORM_TEX(o.texcoord, _MainTex);
		   _MainTex_TexelSize *= 0.5;
		   float offset = float2(1 + _Offset, 1 + _Offset);
		   //                   23.xy
		   //            01.zw         23.zw
		   //      01.xy                     45.xy
		   //            67.zw         45.zw
		   //                   67.xy
		   // 菱形采样8个点,斜边上的4个点给2倍权重
		   o.uv01.xy = uv + float2(-_MainTex_TexelSize.x * 2.0, 0) * offset;
		   o.uv01.zw = uv + float2(-_MainTex_TexelSize.x , -_MainTex_TexelSize.y) * offset;
		   o.uv23.xy = uv + float2(0 , _MainTex_TexelSize.y * 2.0) * offset;
		   o.uv23.zw = uv + float2(_MainTex_TexelSize.x , _MainTex_TexelSize.y) * offset;
		   o.uv45.xy = uv + float2(_MainTex_TexelSize.x * 2.0, 0) * offset;
		   o.uv45.zw = uv + float2(_MainTex_TexelSize.x , -_MainTex_TexelSize.y) * offset;
		   o.uv67.xy = uv + float2(_MainTex_TexelSize.x , -_MainTex_TexelSize.y * 2.0) * offset;
		   o.uv67.zw = uv + float2(-_MainTex_TexelSize.x , -_MainTex_TexelSize.y) * offset;
		   return o;
		}

		//片元着色器，负责采样
		half4 frag_up_sample (v2f_UpSample i) : SV_Target{
		   half4 sum = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.xy);
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.xy);
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.xy);
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv67.xy);
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv01.zw) * 2.0;
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv23.zw) * 2.0;
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv45.zw) * 2.0;
		   sum += SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv67.zw) * 2.0;
		   return sum * 0.083;
		}

		ENDHLSL

		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert_down_sample
			#pragma fragment frag_down_sample
			ENDHLSL
		}
		
		Pass
		{
			HLSLPROGRAM
			#pragma vertex vert_up_sample
			#pragma fragment frag_up_sample
			ENDHLSL
		}
	}
}