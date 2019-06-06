Shader "Custom/Card/Reflection CardFrame (Fast)" 
{
	Properties 
	{
		_AOREFSPEC ("AO (R) Ref (G) Spec (B)", 2D) = "black" {}
		_BumpMap ("Normalmap", 2D) = "bump" { }
		_Color ("Main Color", Color) = (1,1,1,1)
		_SpecPow ("Spec Power", Float) = 20.0 // higher value (whiten) makes specular stronger
		_GlossPow ("Gloss Power", Float) = 2.5 // higher value (whiten) makes specular weaker
	}

	SubShader 
	{ 
		Tags 
		{ 
			"Queue" = "Geometry+1"
			"RenderType"="Opaque"
		}

		Fog { Mode Off }
		LOD 250

		Pass
		{
			Tags { "LightMode" = "ForwardBase" }
			Blend One SrcAlpha
			ZWrite Off

		CGPROGRAM

		#pragma vertex vert
		#pragma fragment frag
		#pragma multi_compile_fwdbase noshadow nolightmap nodynlightmap novertexlight
		#pragma fragmentoption ARB_precision_hint_fastest
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"

			sampler2D _AOREFSPEC;
			sampler2D _BumpMap;

			fixed4 _Color;
			half4 _AOREFSPEC_ST;
			half _SpecPow;
			half _GlossPow;
		
			struct v2f
			{
				float4 pos : SV_POSITION;
				float2 pack0 : TEXCOORD0;
				float4 tSpace0 : TEXCOORD1;
				float4 tSpace1 : TEXCOORD2;
				float4 tSpace2 : TEXCOORD3;
				fixed4 color : COLOR;
			};

			v2f vert (appdata_full v)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);

				o.pos = UnityObjectToClipPos (v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _AOREFSPEC);

				float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				float tangentSign = v.tangent.w * unity_WorldTransformParams.w;
				float3 worldBinormal = cross(worldNormal, worldTangent) * tangentSign;
				o.tSpace0 = float4(worldTangent.x, worldBinormal.x, worldNormal.x, worldPos.x);
				o.tSpace1 = float4(worldTangent.y, worldBinormal.y, worldNormal.y, worldPos.y);
				o.tSpace2 = float4(worldTangent.z, worldBinormal.z, worldNormal.z, worldPos.z);

				o.color = v.color;

				return o;
			}

			fixed4 frag (v2f IN) : SV_Target
			{
				float3 worldPos = float3(IN.tSpace0.w, IN.tSpace1.w, IN.tSpace2.w);
				fixed3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
				fixed3 worldViewDir = normalize(UnityWorldSpaceViewDir(worldPos));
				worldViewDir = normalize(worldViewDir + lightDir);

				fixed3 bumpNormal = UnpackNormal(tex2D(_BumpMap, IN.pack0.xy));

				fixed3 worldNormal;
				worldNormal.x = dot (IN.tSpace0.xyz, bumpNormal);
				worldNormal.y = dot (IN.tSpace1.xyz, bumpNormal);
				worldNormal.z = dot (IN.tSpace2.xyz, bumpNormal);

				fixed diffuse = max (0.0, dot (worldNormal, lightDir));
				fixed nh = max (0.0, dot (worldNormal, worldViewDir));

				fixed4 texAOREF = tex2D(_AOREFSPEC, IN.pack0.xy);
				fixed glossPow = texAOREF.g * _SpecPow;
				fixed specPow = texAOREF.b * _GlossPow;

				half spec = (pow (nh, (specPow * 128.0)) * glossPow);
				fixed4 col;

				col.xyz = ((((_Color.xyz * texAOREF.r * texAOREF.a) * _LightColor0.xyz) * diffuse) + (_LightColor0.xyz * spec));
				col.w = IN.color.a * texAOREF.r;

				return col;
			}
		ENDCG
		}
	}
	FallBack off
}
