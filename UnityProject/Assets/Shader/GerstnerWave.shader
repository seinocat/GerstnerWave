Shader "ShaderLib/GerstnerWave"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1)
        _WaveA ("WaveA", Vector) = (1.0, 1.0, 0.0, 0.0)
        _WaveB ("WaveB", Vector) = (1.0, 1.0, 0.0, 0.0)
        _WaveC ("WaveC", Vector) = (1.0, 1.0, 0.0, 0.0)
        _Gloss ("Gloss", Float) = 4.0
        [Toggle]_RESOLVE("Resolve Toggle", int) = 0
    	
    	_TessellaitionFactor("TessellaitionFactor", Range(1, 10)) = 1
        
    }
    SubShader
    {
        Cull Off  
        Tags{"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        Blend SrcAlpha OneMinusSrcAlpha
        
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        #pragma multi_complie _RESOLVE_ON
        
        CBUFFER_START(UnityPerMaterial)
        sampler2D _MainTex;
        float  _Gloss;
        float _TessellaitionFactor;
        float4 _Color;
        float4 _WaveA, _WaveB, _WaveC;
        bool ResloveOpen;
        CBUFFER_END

        struct appdata
        {
            float4 positionOS : POSITION;
            float3 narmalOS : NORMAL;
        };

        struct tessellaitionPoint
		{
			float4 positionOS : INTERNALTESSPOS;
            float3 narmalOS : NORMAL;
		};

        struct v2g
        {
            float4 positionCS : SV_POSITION;
            float3 normalWS : TEXCOORD1;
            float3 positionWS : TEXCOORD2;
        };
        
        struct v2f
        {
            float4 positionCS : SV_POSITION;
            float3 normalWS : TEXCOORD1;
            float3 positionWS : TEXCOORD2;
        };

        struct TessellationFactors {
		    float edge[3] : SV_TessFactor;
		    float inside : SV_InsideTessFactor;
		};
        
        tessellaitionPoint MyTessellationVertexProgram (appdata v) {
			tessellaitionPoint p;
			p.positionOS = v.positionOS;
			p.narmalOS = v.narmalOS;
			return p;
		}

        float3 GerstnerWave(float4 waveParam, float3 p, inout float3 tangent, inout float3 bitangent)
        {
            float steepness = waveParam.x;
            float waveLength = waveParam.y;
            float k = 2 * PI / max(1, waveLength);
            float c = sqrt(9.8 / k);
            float2 d = normalize(float2(waveParam.z, waveParam.w));
            float f = k * (dot(d, p.xz) - c * _Time.y);
            float a = steepness / k;
            tangent += float3(-d.x * d.x * (steepness * sin(f)),d.x * (steepness * cos(f)), -d.x * d.y * (steepness * sin(f)));
            bitangent += float3(-d.x * d.y * (steepness * sin(f)),d.y * (steepness * cos(f)),-d.y * d.y * (steepness * sin(f)));
            return float3(d.x * (a * cos(f)), a * sin(f), d.y * (a * cos(f)));
        }
        
        v2g vert (appdata v)
        {
            v2g o;
            float3 tangent = float3(1, 0, 0);
            float3 binormal = float3(0, 0, 1);
            v.positionOS.xyz += GerstnerWave(_WaveA, v.positionOS.xyz, tangent, binormal);
            v.positionOS.xyz += GerstnerWave(_WaveB, v.positionOS.xyz, tangent, binormal);
            v.positionOS.xyz += GerstnerWave(_WaveC, v.positionOS.xyz, tangent, binormal);
            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);

            float3 normal = normalize(cross(binormal, tangent));
            o.normalWS = TransformObjectToWorldNormal(normal);
            // o.normalWS = half3(0,1,0);
            o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
            return o;
        }

        
		TessellationFactors MyPatchConstantFunction(InputPatch<tessellaitionPoint, 3> patch)
		{

			float3 p0 = TransformObjectToWorld(patch[0].positionOS.xyz);
			float3 p1 = TransformObjectToWorld(patch[1].positionOS.xyz);
			float3 p2 = TransformObjectToWorld(patch[2].positionOS.xyz);
        	
			TessellationFactors f;
			f.edge[0] = _TessellaitionFactor;
			f.edge[1] = _TessellaitionFactor;
			f.edge[2] = _TessellaitionFactor;

			// float Height = p0.y + p1.y + p2.y;
   //      	
			f.inside = _TessellaitionFactor;

			return f;
		}

		[domain("tri")]
		[outputcontrolpoints(3)]
		[outputtopology("triangle_cw")]
		[partitioning("integer")]
		[patchconstantfunc("MyPatchConstantFunction")]
		tessellaitionPoint MyHullProgram(InputPatch<tessellaitionPoint, 3> patch, uint id : SV_OutputControlPointID)
		{
			return patch[id];
		}

		[domain("tri")]
		v2g MyDomainProgram(TessellationFactors factors, OutputPatch<tessellaitionPoint, 3> patch, float3 barycentricCoordinates : SV_DomainLocation)
		{
			appdata data;

			#define MY_DOMAIN_PROGRAM_INTERPOLATE(fieldName) data.fieldName =  patch[0].fieldName * barycentricCoordinates.x +  patch[1].fieldName * barycentricCoordinates.y +  patch[2].fieldName * barycentricCoordinates.z;

			MY_DOMAIN_PROGRAM_INTERPOLATE(positionOS);
			MY_DOMAIN_PROGRAM_INTERPOLATE(narmalOS);
			return vert(data);
		}

        [maxvertexcount(3)]
        void geo(triangle v2g input[3], inout LineStream<v2f> output)
        {
            v2f o = (v2f)0;
            o.positionWS = input[0].positionWS;
            o.normalWS = input[0].normalWS;
            o.positionCS = input[0].positionCS;
            output.Append(o);

            o.positionWS = input[1].positionWS;
            o.normalWS = input[1].normalWS;
            o.positionCS = input[1].positionCS;
            output.Append(o);

            o.positionWS = input[2].positionWS;
            o.normalWS = input[2].normalWS;
            o.positionCS = input[2].positionCS;
            output.Append(o);

            output.RestartStrip();
        }
        

        [maxvertexcount(2)]
        void geo_normal(point v2g input[1], inout LineStream<v2f> output)
        {
            v2f o = (v2f)0;
            o.positionWS = input[0].positionWS;
            o.normalWS = input[0].normalWS;
            o.positionCS = input[0].positionCS;
            output.Append(o);

            v2f q = (v2f)0;
            q.positionWS = input[0].positionWS + input[0].normalWS * 0.5;
            q.normalWS = input[0].normalWS;
            q.positionCS = TransformWorldToHClip(q.positionWS);
            
            output.Append(q);
            
            // output.RestartStrip();
        }
        
        half4 frag (v2f i) : SV_TARGET
        {
            half3 normalWS = normalize(i.normalWS);
            float3 positionWS = normalize(i.positionWS);
            half3 viewDir = normalize(GetWorldSpaceViewDir(positionWS));
            Light mainLight = GetMainLight();
            half3 lightDir = mainLight.direction;
            half3 halfVec = normalize(viewDir + lightDir);
            
            // diffuse
            half3 diffuse =  _Color.rgb * (dot(normalWS, lightDir) * 0.5 + 0.5) ;
        	
            // BRDF specular
            // half3 specular =  mainLight.color  * pow(max(0, dot(normalWS, halfVec)), _Gloss);
   			BRDFData brdfdata;
        	half alpha = 1;
			InitializeBRDFData(half3(0.0, 0.0, 0.0), 0.0, half3(1.0, 1.0, 1.0), 0.95, alpha, brdfdata);
			half3 specular = DirectBRDFSpecular(brdfdata, normalWS, mainLight.direction, viewDir) * mainLight.color;
            half4 finalColor = float4(specular + diffuse, 1.0);
            return finalColor;
        }


        v2f vert_geo(appdata v)
        {
            v2f o;

            o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
            o.normalWS = TransformObjectToWorldNormal(v.narmalOS.xyz);
            o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
            return o;
        }

        half4 frag_geo (v2f i) : SV_TARGET
        {
            return half4(0, 0.8, 0, 1);
        }
        
        half4 frag_geo_normal (v2f i) : SV_TARGET
        {
            return half4(0.8, 0, 0, 1);
        }
        
        ENDHLSL
        
    	//Shading Pass 
        Pass
        {
            Tags{"LightMode" = "SRPDefaultUnlit"}
            name "waveshading"
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            ENDHLSL
        }
        
    	//Tessellation Pass 
        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            name "mesh"
            HLSLPROGRAM
            #pragma vertex MyTessellationVertexProgram
            #pragma hull MyHullProgram
			#pragma domain MyDomainProgram
            #pragma fragment frag_geo
            #pragma geometry geo
            ENDHLSL
        }
		
		//Normal Pass  
    	     
//         Pass
//        {
//            Tags{"LightMode" = "LightweightForward"}
//            name "normal"
//            HLSLPROGRAM
//            #pragma vertex MyTessellationVertexProgram
//            #pragma hull MyHullProgram
//			  #pragma domain MyDomainProgram
//            #pragma fragment frag_geo_normal
//            #pragma geometry geo_normal
//            ENDHLSL
//        }
    }
}
