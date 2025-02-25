//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// "Default" techniques for water shader
//////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// SHADER: Default
// ----------------------------------------------------------------------------
struct DefaultVSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 Bump1TexCoord : TEXCOORD0;
	float2 Bump2TexCoord : TEXCOORD1;
	float2 EnvTexCoord : TEXCOORD2;
	float3 ReflectionTexCoord : TEXCOORD3;
	float2 ShroudTexCoord : TEXCOORD4;
	float2 Wave1TexCoord : TEXCOORD5;
	float2 Wave2TexCoord : TEXCOORD6;
	float4 ShadowMapTexCoord : TEXCOORD7;
	float4 MainLightColor_Fog : COLOR1;
};

// ----------------------------------------------------------------------------
// SHADER: DefaultVertexShader
// ----------------------------------------------------------------------------
DefaultVSOutput DefaultVertexShader(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	DefaultVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World);
	float3 CP = ViewI[3];
	Out.MainLightColor_Fog.w = CalculateFog(Fog, WP, CP);
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	float modifier = dot(WN, float3(0, 0, 1));
	modifier *= modifier;
	modifier *= modifier;

#ifdef _WW3D_	
	Out.Color = MaterialColorDiffuse * DimmingFactor * modifier;
	
	Out.MainLightColor_Fog.xyz = DirectionalLight[0].Color * max(0, dot(WN, DirectionalLight[0].Direction));
#else // for Max
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(WN, DirectionalLight[i].Direction));
		
		if (i == 0)
			Out.MainLightColor_Fog.xyz = diffuseLight;
	}
	
	Out.Color = (AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1)) * DimmingFactor;
#endif	

	float TerrainDepth = Normal.z;
	float WaterDepth = WP.z - TerrainDepth;
	Out.Color.a = ComputeWaterTransparency(WaterDepth);

	BumpAngle += Time * BumpRotation;
	BumpAngle = fmod(BumpAngle, 6.28);
	BumpMatrix[0][0] = BumpScale * cos(BumpAngle);
	BumpMatrix[1][0] = BumpScale * sin(BumpAngle);
	BumpMatrix[0][1] = -BumpMatrix[1][0];
	BumpMatrix[1][1] = BumpMatrix[0][0];
	
	float2 uvScale = (1.0f/600.0f, 1.0f/600.0f);
	float2 TexCoord = (float2(WP[0], WP[1])) * uvScale; 
	
	// env map texture
	Out.EnvTexCoord = (TexCoord + 1.0 * WN.xy) * EnvUVScale;

	// reflection texture
	Out.ReflectionTexCoord = hPosition.xyw;
	
	// shroud
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, WP);
	
	// wave texture 	
	float HalfWaveAngle = WaveAngle/2.0f;
	float Wave1Angle = WindAngle-HalfWaveAngle;
	float Wave2Angle = WindAngle+HalfWaveAngle;
	
	Wave1Direction[0] = cos(Wave1Angle);
	Wave1Direction[1] = sin(Wave1Angle);

	Wave2Direction[0] = cos(Wave2Angle);
	Wave2Direction[1] = sin(Wave2Angle);

	Wave1Matrix[0][0] = Wave1Direction[0];
	Wave1Matrix[1][0] = Wave1Direction[1];
	Wave1Matrix[0][1] = -Wave1Matrix[1][0];
	Wave1Matrix[1][1] = Wave1Matrix[0][0];
	
	Wave2Matrix[0][0] = Wave2Direction[0];
	Wave2Matrix[1][0] = Wave2Direction[1];
	Wave2Matrix[0][1] = -Wave2Matrix[1][0];
	Wave2Matrix[1][1] = Wave2Matrix[0][0];

	// bump map texture	
	Out.Bump1TexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+BumpSpeed) * Time, Wave1Matrix) * BumpUVScale * BumpScale; 
	Out.Bump2TexCoord = mul(TexCoord + Wave2Direction * (WindSpeed+BumpSpeed) * Time, Wave2Matrix) * BumpUVScale * BumpScale; 

	Out.Wave1TexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;
	Out.Wave2TexCoord = mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * WaveUVScale;
	
	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, WP);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: DefaultPixelShader
// ----------------------------------------------------------------------------
float4 DefaultPixelShader(DefaultVSOutput In, uniform int numShadows) : COLOR
{
	// bump map
	float4 bump1 = tex2D( SAMPLER(WaterBumpTexture), In.Bump1TexCoord);
	float2 bumpCoord1 = 2.0 * bump1 - float2(1.0, 1.0);
	float4 bump2 = tex2D( SAMPLER(WaterBumpTexture), In.Bump2TexCoord);
	float2 bumpCoord2 = 2.0 * bump2 - float2(1.0, 1.0);
	float2 bumpCoord = normalize(float3(bumpCoord1, 0.00001f) + float3(bumpCoord2, 0.00001f)).xy;

	bumpCoord = mul(bumpCoord, BumpMatrix); 
	
	// environment map
	float2 envCoord = 0.05 * bumpCoord + In.EnvTexCoord;
	float4 diffuse = tex2D( SAMPLER(WaterEnvTexture), envCoord);

	// reflection stuff -- based on experiments only. It works ok but may change later
	float2 TCoord2 = 0.5 * In.ReflectionTexCoord.xy/In.ReflectionTexCoord.z + float2(0.5, 0.5);
	float2 reflCoord = 0.003 * bumpCoord + TCoord2;
	float3 reflColor = saturate(tex2D( SAMPLER(WaterReflectionTexture), reflCoord));
		
	// shroud and waves
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	float3 wave1 = tex2D( SAMPLER(WaveTexture1), In.Wave1TexCoord);
	float3 wave2 = tex2D( SAMPLER(WaveTexture2), In.Wave2TexCoord);

	// Calculate final color
	float4 color;
	color.xyz = In.Color * diffuse;

	if (numShadows >= 1)
	{
		color.xyz -= In.MainLightColor_Fog.xyz * (1.0 - shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord, ShadowInfo));
	}
	
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz = lerp(color.xyz, reflColor, ReflectionStrength);
#endif

	color.xyz += wave1 * wave2 * 2.0f;

	color.xyz = lerp(Fog.Color, color.xyz, In.MainLightColor_Fog.w);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	color.xyz *= shroud;
#endif
 
	color.a = In.Color.a;

	return color;
}

// ----------------------------------------------------------------------------
// SHADER: DefaultPixelShader_Xenon
// ----------------------------------------------------------------------------
float4 DefaultPixelShader_Xenon( DefaultVSOutput In ) : COLOR
{
	return DefaultPixelShader( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: DefaultTechnique (High LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PSDefault_Multiplier_Final = 2 );

#define PSDefault_NumShadows \
	compile ps_2_0 DefaultPixelShader(0), \
	compile ps_2_0 DefaultPixelShader(1),

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSDefault_Array[PSDefault_Multiplier_Final] =
{
	PSDefault_NumShadows
};
#endif

technique Default
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Water")
	>
	{
		VertexShader = compile vs_2_0 DefaultVertexShader();
		PixelShader  = ARRAY_EXPRESSION_PS( PSDefault_Array, min( NumShadows, 1 ), 
											compile PS_VERSION DefaultPixelShader_Xenon() );

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		ColorWriteEnable = 7;

		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false; // Fog handled by pixel shader
#endif
	}
}



#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: Default_LowQuality
// ----------------------------------------------------------------------------
struct DefaultVSLowOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BumpTexCoord : TEXCOORD0;
	float2 EnvTexCoord : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
	float2 WaveTexCoord : TEXCOORD3;
};

// ----------------------------------------------------------------------------
// SHADER: DefaultVertexShaderLow
// ----------------------------------------------------------------------------
DefaultVSLowOutput DefaultVertexShaderLow(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	DefaultVSLowOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));
	float3 WP = mul(float4(Position, 1), World);	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	float modifier = dot(WN, float3(0, 0, 1));
	modifier *= modifier;
	modifier *= modifier;

#ifdef _WW3D_	
	Out.Color = MaterialColorDiffuse * DimmingFactor * modifier;
#else // for Max
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(WN, DirectionalLight[i].Direction));
	}
	
	Out.Color = (AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1)) * DimmingFactor;
#endif	
	float TerrainDepth = Normal.z;
	float WaterDepth = WP.z - TerrainDepth;
	Out.Color.a = ComputeWaterTransparency(WaterDepth);
			
	float2 uvScale = (1.0f/600.0f, 1.0f/600.0f);
	float2 TexCoord = (float2(WP[0], WP[1])) * uvScale; 
	
	// env map texture
	Out.EnvTexCoord = (TexCoord + 1.0 * WN.xy) * EnvUVScale;
	
	// shroud
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, WP);
	
	// wave texture 	
	float HalfWaveAngle = WaveAngle/2.0f;
	float Wave1Angle = WindAngle-HalfWaveAngle;
	
	Wave1Direction[0] = cos(Wave1Angle);
	Wave1Direction[1] = sin(Wave1Angle);

	Wave1Matrix[0][0] = Wave1Direction[0];
	Wave1Matrix[1][0] = Wave1Direction[1];
	Wave1Matrix[0][1] = -Wave1Matrix[1][0];
	Wave1Matrix[1][1] = Wave1Matrix[0][0];
	
	// bump map texture	
	Out.BumpTexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+BumpSpeed) * Time, Wave1Matrix) * BumpUVScale * BumpScale; 
	Out.WaveTexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;

	return Out;
}

// ----------------------------------------------------------------------------
// TECHNIQUE Default (Low Quality)
// ----------------------------------------------------------------------------
technique _Default_L
{
	pass P0
	{
		VertexShader = compile vs_1_1 DefaultVertexShaderLow();
		PixelShader  = asm 
						{
							ps_1_1
							def c1, 0.1, 0.1, 0.1, 0.0
							tex t0				// bump map
							texbem t1, t0		// environment map
							tex t2				// shroud
							tex t3				// waves
							mul r1.rgb, t3, c1	// scale waves
							mul r0.rgb, t1, v0	// tint env map with vertex color
							add r0.rgb, r0, r1	// add waves 
							mul r0.rgb, r0, t2	// multiply shroud
							+mov r0.a, v0.a		// pass through alpha
						};

		Texture[0] = ( WaterBumpTexture );
		AddressU[0] = WRAP; 
		AddressV[0] = WRAP; 
		MipFilter[0] = LINEAR;
	    MinFilter[0] = ANISOTROPIC;
	    MagFilter[0] = LINEAR;
	    MaxAnisotropy[0] = 4;
			
		Texture[1] = ( WaterEnvTexture );
		AddressU[1] = WRAP; 
		AddressV[1] = WRAP; 
		MipFilter[1] = LINEAR;
	    MinFilter[1] = ANISOTROPIC;
	    MagFilter[1] = LINEAR;
	    MaxAnisotropy[1] = 4;

		BumpEnvMat00[1] = 0.05f;
		BumpEnvMat01[1] = 0.0f;
		BumpEnvMat10[1] = 0.0f;
		BumpEnvMat11[1] = 0.05f;

		Texture[2] = ( ShroudTexture );
		AddressU[2] = CLAMP; 
		AddressV[2] = CLAMP; 
		MipFilter[2] = LINEAR;
	    MinFilter[2] = LINEAR;
	    MagFilter[2] = LINEAR;

		Texture[3] = ( WaveTexture1 );
		AddressU[3] = WRAP; 
		AddressV[3] = WRAP; 
		MipFilter[3] = LINEAR;
	    MinFilter[3] = LINEAR;
	    MagFilter[3] = LINEAR;

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		CullMode = CW;
		AlphaBlendEnable = true;
		AlphaTestEnable = false;
		ColorWriteEnable = 7;

		SrcBlend = SRCALPHA;
		DestBlend = INVSRCALPHA;

#if !defined( _NO_FIXED_FUNCTION_ )
		FogEnable = false;
#endif

	}
}

#endif // ENABLE_LOD


// ----------------------------------------------------------------------------
// SHADER: DepthOnly
// ----------------------------------------------------------------------------
struct DepthOnlyVSOutput
{
	float4 Position : POSITION;
};

// ----------------------------------------------------------------------------
// SHADER: DepthOnlyVertexShader
// ----------------------------------------------------------------------------
DepthOnlyVSOutput DepthOnlyVertexShader(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0)
{
	DepthOnlyVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: DepthOnlyPixelShader
// ----------------------------------------------------------------------------
float4 DepthOnlyPixelShader(DepthOnlyVSOutput In) : COLOR
{	
	float4 color = float4(1.0f, 0.0f, 0.0f, 1.0f);
	return color;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: DepthOnly
// ----------------------------------------------------------------------------
technique _DepthOnly
{
	pass P0
	{
		VertexShader = compile vs_1_1 DepthOnlyVertexShader();
		PixelShader  = compile ps_1_1 DepthOnlyPixelShader();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = true;
		AlphaBlendEnable = false;
		AlphaTestEnable = false;
		CullMode = CW;
		ColorWriteEnable = 0;
	}
}
