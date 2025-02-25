//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// "PCA" techniques for water shader
//////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// SHADER: PCA Ultra
// ----------------------------------------------------------------------------
struct PCAVSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float Fog : COLOR1;
	float4 PCATexCoord : TEXCOORD0;
	float4 EnvShroudTexCoord : TEXCOORD1;
	float3 ReflectionTexCoord : TEXCOORD2;
	float4 ShadowMapTexCoord : TEXCOORD3;
	float4 WorldPosition : TEXCOORD4;
	float4 WorldNormal : TEXCOORD5;
	float4 WaveTexCoord : TEXCOORD6;
//	float3 GerstParams : TEXCOORD7;
//	float3 SpecularDirection : COLOR1;
};

// ----------------------------------------------------------------------------
// SHADER: PCAUltraVertexShader
// ----------------------------------------------------------------------------
PCAVSOutput PCAUltraVertexShader(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0, 
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	PCAVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));
	float3 WP = mul(float4(Position, 1), World).xyz;

	float AmpMult = 0.075f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z; 
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	if (WaterDepth < DepthThres && Radius < RadiusThres)
	{
		// gw1
		float2 Pos = WP.xy; 
		float amp = AmpMult * GWAmpFreqPhaseSteepness1.x; 
		float freq = GWAmpFreqPhaseSteepness1.y + frac(WP.x) * 0.0005f;
		float phase = GWAmpFreqPhaseSteepness1.z;
		float steep = GWAmpFreqPhaseSteepness1.w;
		float2 dir = TexCoord0; 
		float2 perp = float2(-TexCoord0.y, TexCoord0.x);
		
		float a = freq * dot(Pos, dir) + phase * Time;
		float wa = amp * freq;
		float sa = sin(a);
		float ca = cos(a);
		float q = 0.33f * steep / wa;
		float px = q * amp * dir.x * ca;
		float py = q * amp * dir.y * ca;
		float pz = amp * sa;
		float nx = dir.x * wa * ca;
		float ny = dir.y * wa * ca;
		float nz = q * wa * sa;
		
		// gw2
		amp = AmpMult * GWAmpFreqPhaseSteepness2.x;
		freq = GWAmpFreqPhaseSteepness2.y + frac(WP.y) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness2.z;
		steep = GWAmpFreqPhaseSteepness2.w;
		dir = normalize(TexCoord0 + 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.33f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;
			
		// gw3
		amp = AmpMult * GWAmpFreqPhaseSteepness3.x;
		freq = GWAmpFreqPhaseSteepness3.y + frac(WP.z) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness3.z;
		steep = GWAmpFreqPhaseSteepness3.w;
		dir = normalize(TexCoord0 - 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.33f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;

		WP.xyz += float3(0.75f * px, 0.75f * py, pz);		
		gerstNormal = normalize(float3(-nx, -ny, 1-nz));
		
		WaterDepth = WP.z - TerrainDepth;

		// add extra froth near leading edge of the wave
		float blendRadius = 0.5f * RadiusThres;
		float blendFactor = 0.75f;
		if (Radius > blendRadius) 
		{
			blendFactor = (RadiusThres - Radius)/(RadiusThres-blendRadius);
		}

		float DepthFactor = (DepthThres - WaterDepth)/DepthThres;
		float HeightThres = WaterPlaneHeight + 4.0f;
		float blendHeight = WaterPlaneHeight + 0.2f; 
		float Height = WP.z;
		if (Height > blendHeight) 
		{
			heightBlendFactor = (Height - blendHeight)/(HeightThres-blendHeight);
			heightBlendFactor *= heightBlendFactor;
			heightBlendFactor = DepthFactor * blendFactor * heightBlendFactor;
		}						
	}
		
	float shoreBlendFactor = 0.125f;
	float ShoreDepthThres = 15.0f;
	if (WaterDepth < ShoreDepthThres)
	{
		shoreBlendFactor += 0.5 * (ShoreDepthThres - WaterDepth)/ShoreDepthThres;
	}	
	heightBlendFactor += shoreBlendFactor;	

	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];
	Out.Fog = CalculateFog(Fog, WP, CP);
	Out.WorldPosition = float4(WP, heightBlendFactor);
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal = float4(gerstNormal, WaterDepth); 

#ifdef _WW3D_	
	Out.Color = 2.0f * MaterialColorDiffuse * DimmingFactor;
#else // for Max
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(WN, DirectionalLight[i].Direction));
	}
	
	Out.Color = (AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1)) * DimmingFactor;
#endif	

	Out.Color.a = ComputeWaterTransparency(WaterDepth);

	float2 uvScale = (1.0f/600.0f, 1.0f/600.0f);
	float2 TexCoord = (float2(WP[0], WP[1])) * uvScale; 
	
	// env map texture
	Out.EnvShroudTexCoord.xy = TexCoord * EnvUVScale;

	// reflection texture
	Out.ReflectionTexCoord.z = hPosition.w;
  	Out.ReflectionTexCoord.xy = 0.5 * (hPosition.xy + hPosition.w * float2(1.0, 1.0));
	
	// shroud
	Out.EnvShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, WP);
	
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
	Out.PCATexCoord.xy = mul(TexCoord, Wave1Matrix) * PCABumpUVScale.x; 
	Out.PCATexCoord.zw = mul(TexCoord, Wave2Matrix) * PCABumpUVScale.y; 

	Out.WaveTexCoord.xy = WP.xy * PCAWaveUVScale.x;
	Out.WaveTexCoord.zw = WP.xy * PCAWaveUVScale.y;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, WP);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PCAUltraPixelShader
// ----------------------------------------------------------------------------
float4 PCAUltraPixelShader(PCAVSOutput In, uniform int numShadows) : COLOR
{
	float4 Noise = tex2D( SAMPLER(PCANoiseTexture), float2(In.PCATexCoord.x*0.015f+0.3f, In.PCATexCoord.y*0.015+0.1f));

	// add some deep water swells
	float4 pcaTex1 = tex2D( SAMPLER(WaterPCATexture1), In.PCATexCoord.xy)+tex2D( SAMPLER(WaterPCATexture1), In.PCATexCoord.zw)+tex2D( SAMPLER(WaterPCATexture3), In.PCATexCoord.xy)-1.5f;
	float3 bumpNormal = (PCA.Mean + float3(dot(PCA.Bases03X, pcaTex1), dot(PCA.Bases03Y, pcaTex1), dot(PCA.Bases03Z, pcaTex1)));
		
	float4 pcaTex2 = tex2D( SAMPLER(WaterPCATexture2), In.PCATexCoord.xy)+tex2D( SAMPLER(WaterPCATexture2), In.PCATexCoord.zw)+tex2D( SAMPLER(WaterPCATexture3), In.PCATexCoord.zw)-1.5f;
	bumpNormal += float3(dot(PCA.Bases47X, pcaTex2), dot(PCA.Bases47Y, pcaTex2), dot(PCA.Bases47Z, pcaTex2));
	
  	bumpNormal = bumpNormal * 4 - 2;

	bumpNormal += In.WorldNormal;
	bumpNormal = normalize(float4(bumpNormal, 0.00001f));
	bumpNormal = lerp(bumpNormal, float3(0.0f, 0.0f, 1.0f), saturate(Noise.w * Noise.x * 0.25f));

	float2 bumpOffset = ReflectionPerturbation * bumpNormal.xy; 
	
	// environment map
	float2 envCoord = bumpOffset + In.EnvShroudTexCoord.xy;
	float4 diffuseColor = In.Color * tex2D( SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	// Compute lighting
	float3 eyeDirection = normalize(ViewI[3] - In.WorldPosition.xyz);
	float3 light0Direction = DirectionalLight[0].Direction;
	float3 light1Direction = DirectionalLight[1].Direction;
	float3 halfEyeLightVector = normalize(eyeDirection+light1Direction);

  	float4 lightingColor = lit(dot(bumpNormal, light0Direction.xyz),
  							dot(bumpNormal, halfEyeLightVector), SpecularExponent);
			
	// control shadow darkness	
	if (numShadows >= 1)
	{
		float4 shadowTexCoord = In.ShadowMapTexCoord;
		shadowTexCoord.xy += bumpOffset; 
		float ShadowDarkness = shadow(SAMPLER(ShadowMap), shadowTexCoord, ShadowInfo); 
		
		if (ShadowDarkness < 1.0f)
		{
			ShadowDarkness = min(ShadowLightness + ShadowDarkness, 0.999f);	
		}	
		
		lightingColor.yz *= ShadowDarkness;
	}
	
	// do the lighting 
	pixelColor.xyz = DirectionalLight[0].Color * (diffuseColor * lightingColor.y + SpecularColor * lightingColor.z);
    	    			
	// reflection 
	float2 ReflectionCoord = In.ReflectionTexCoord.xy/In.ReflectionTexCoord.z;
	float2 reflCoord = bumpOffset + ReflectionCoord;
	float3 reflColor = tex2D( SAMPLER(WaterReflectionTexture), reflCoord);
		
	// shroud and waves
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.EnvShroudTexCoord.zw);
	
	float2 whiteTexCoord = In.WaveTexCoord.xy + bumpOffset; 
	float2 whiteTexCoord2 = In.WaveTexCoord.zw + bumpOffset; 
	float3 wave1 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord);
	float3 wave2 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord2);
	
	// Calculate fresnel
  float fresnel = pow( 1-dot( eyeDirection, bumpNormal.xyz ), 2.0 );
    
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz = lerp(pixelColor.xyz, reflColor, fresnel);
#endif

	pixelColor.xyz += In.WorldPosition.w * wave1.rgb * wave2.rgb;
	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz *= shroud;
#endif

	return pixelColor;
}

// ----------------------------------------------------------------------------
// SHADER: PCAUltraPixelShader_Xenon
// ----------------------------------------------------------------------------
float4 PCAUltraPixelShader_Xenon( PCAVSOutput In ) : COLOR
{
	return PCAUltraPixelShader( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: PCA Ultra
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PSPCAUltra_Multiplier_Final = 2 );

#define PSPCAUltra_NumShadows \
	compile ps_3_0 PCAUltraPixelShader(0), \
	compile ps_3_0 PCAUltraPixelShader(1),

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSPCAUltra_Array[PSPCAUltra_Multiplier_Final] =
{
	PSPCAUltra_NumShadows
};
#endif

technique _PCA_U
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Water")
	>
	{
		VertexShader = compile vs_3_0 PCAUltraVertexShader();
		PixelShader  = ARRAY_EXPRESSION_PS( PSPCAUltra_Array,
						min(NumShadows, 1),
						compile PS_VERSION PCAUltraPixelShader_Xenon() );

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
		FogEnable = false; // Fog handled in pixel shader
#endif
	}
}


// ----------------------------------------------------------------------------
// SHADER: PCAVertexShader
// ----------------------------------------------------------------------------
PCAVSOutput PCAVertexShader(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0, 
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	PCAVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World).xyz;

	float AmpMult = 0.075f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z;
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	if (WaterDepth < DepthThres && Radius < RadiusThres)
	{
		// gw1
		float2 Pos = WP.xy; 
		float amp = AmpMult * GWAmpFreqPhaseSteepness1.x; 
		float freq = GWAmpFreqPhaseSteepness1.y + frac(WP.x) * 0.0005f;
		float phase = GWAmpFreqPhaseSteepness1.z;
		float steep = GWAmpFreqPhaseSteepness1.w;
		float2 dir = TexCoord0; 
		float2 perp = float2(-TexCoord0.y, TexCoord0.x);
		
		float a = freq * dot(Pos, dir) + phase * Time;
		float wa = amp * freq;
		float sa = sin(a);
		float ca = cos(a);
		float q = 0.15f * steep / wa;
		float px = q * amp * dir.x * ca;
		float py = q * amp * dir.y * ca;
		float pz = amp * sa;
		float nx = dir.x * wa * ca;
		float ny = dir.y * wa * ca;
		float nz = q * wa * sa;
		
		// gw2
		amp = AmpMult * GWAmpFreqPhaseSteepness2.x;
		freq = GWAmpFreqPhaseSteepness2.y + frac(WP.y) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness2.z;
		steep = GWAmpFreqPhaseSteepness2.w;
		dir = normalize(TexCoord0 + 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.15f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;
			
		// gw3
		amp = AmpMult * GWAmpFreqPhaseSteepness3.x;
		freq = GWAmpFreqPhaseSteepness3.y + frac(WP.z) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness3.z;
		steep = GWAmpFreqPhaseSteepness3.w;
		dir = normalize(TexCoord0 - 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.15f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;

		WP.xyz += float3(0.75f * px, 0.75f * py, pz);		
		gerstNormal = normalize(float3(-nx, -ny, 1-nz));
		
		WaterDepth = WP.z - TerrainDepth;

		// add extra froth near leading edge of the wave
		float blendFactor = 0.75f;
		float DepthFactor = (DepthThres - WaterDepth)/DepthThres;
		float HeightThres = WaterPlaneHeight + 4.0f;
		float blendHeight = WaterPlaneHeight + 0.2f; 
		float Height = WP.z;

		if (Height > blendHeight) 
		{
			heightBlendFactor = (Height - blendHeight)/(HeightThres-blendHeight);
			heightBlendFactor *= heightBlendFactor;
			heightBlendFactor = DepthFactor * blendFactor * heightBlendFactor;
		}						
	}
	
	float shoreBlendFactor = 0.125f;
	float ShoreDepthThres = 15.0f;
	if (WaterDepth < ShoreDepthThres)
	{
		shoreBlendFactor += 0.5 * (ShoreDepthThres - WaterDepth)/ShoreDepthThres;
	}	
	heightBlendFactor += shoreBlendFactor;
	
	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];
	Out.Fog = CalculateFog(Fog, WP, CP);
	Out.WorldPosition = float4(WP, heightBlendFactor);
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal = float4(gerstNormal, WaterDepth); 

#ifdef _WW3D_	
	Out.Color = 2.0f * MaterialColorDiffuse * DimmingFactor;
#else // for Max

	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(WN, DirectionalLight[i].Direction));
	}
	
	Out.Color = (AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1)) * DimmingFactor;

#endif	

	Out.Color.a = ComputeWaterTransparency(WaterDepth);

	float2 uvScale = (1.0f/600.0f, 1.0f/600.0f);
	float2 TexCoord = (float2(WP[0], WP[1])) * uvScale; 
	
	// env map texture
	Out.EnvShroudTexCoord.xy = TexCoord * EnvUVScale;

	// reflection texture
	Out.ReflectionTexCoord.z = hPosition.w;
   	Out.ReflectionTexCoord.xy = 0.5 * (hPosition.xy + hPosition.w * float2(1.0, 1.0));
	
	// shroud
	Out.EnvShroudTexCoord.zw = CalculateShroudTexCoord(Shroud, WP).yx;
	
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
	Out.PCATexCoord.xy = mul(TexCoord, Wave1Matrix) * PCABumpUVScale.x; 
	Out.PCATexCoord.zw = (mul(TexCoord, Wave2Matrix) * PCABumpUVScale.y).yx; 

	Out.WaveTexCoord.xy = WP.xy * PCAWaveUVScale.x;
	Out.WaveTexCoord.zw = (WP.xy * PCAWaveUVScale.y).yx;

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, WP);
	
	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: PCAPixelShader
// ----------------------------------------------------------------------------
float4 PCAPixelShader(PCAVSOutput In, uniform int numShadows) : COLOR
{
	// add some deep water swells
	float4 pcaTex1 = tex2D( SAMPLER(WaterPCATexture1), In.PCATexCoord.xy)+tex2D( SAMPLER(WaterPCATexture1), In.PCATexCoord.wz)-1.0f; // +tex2D( SAMPLER(WaterPCATexture3), In.PCATexCoord.xy)-1.5f;
	float3 bumpNormal = (PCA.Mean + float3(dot(PCA.Bases03X, pcaTex1), dot(PCA.Bases03Y, pcaTex1), dot(PCA.Bases03Z, pcaTex1)));
		
	float4 pcaTex2 = tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.xy)+tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.wz)-1.0f; // +tex2D(SAMPLER(WaterPCATexture3), In.PCATexCoord.wz)-1.5f;
	bumpNormal += float3(dot(PCA.Bases47X, pcaTex2), dot(PCA.Bases47Y, pcaTex2), dot(PCA.Bases47Z, pcaTex2));

  	bumpNormal = bumpNormal * 4 - 2;
	bumpNormal += In.WorldNormal;
	bumpNormal = normalize(float4(bumpNormal, 0.00001f));

	float2 bumpOffset = ReflectionPerturbation * bumpNormal.xy; 
	
	// environment map
	float2 envCoord = bumpOffset + In.EnvShroudTexCoord.xy;
	float4 diffuseColor = In.Color * tex2D(SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	// Compute lighting
	float3 eyeDirection = normalize(ViewI[3] - In.WorldPosition.xyz);
	float3 light0Direction = DirectionalLight[0].Direction;
	float3 light1Direction = DirectionalLight[1].Direction;
	float3 halfEyeLightVector = normalize(eyeDirection+light1Direction);

    float4 lightingColor = lit(dot(bumpNormal, light0Direction.xyz),
			dot(bumpNormal, halfEyeLightVector), SpecularExponent);
				
	// do the lighting 
	pixelColor.xyz = DirectionalLight[0].Color * (diffuseColor * lightingColor.y + SpecularColor * lightingColor.z);
    	    			
	// reflection 
	float2 ReflectionCoord = In.ReflectionTexCoord.xy/In.ReflectionTexCoord.z;
	float2 reflCoord = bumpOffset + ReflectionCoord;
	float3 reflColor = tex2D(SAMPLER(WaterReflectionTexture), reflCoord);
		
	// shroud and waves
	float3 shroud = tex2D(SAMPLER(ShroudTexture), In.EnvShroudTexCoord.wz);
	
	float2 whiteTexCoord = In.WaveTexCoord.xy + bumpOffset; 
	float2 whiteTexCoord2 = In.WaveTexCoord.wz + bumpOffset; 
	float3 wave1 = tex2D(SAMPLER(PCAFrothTexture), whiteTexCoord);
	float3 wave2 = tex2D(SAMPLER(PCAFrothTexture), whiteTexCoord2);
	
	// Calculate fresnel
  float fresnel = pow( 1-dot( eyeDirection, bumpNormal.xyz ), 2.0 );
   
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz = lerp(pixelColor.xyz, reflColor, fresnel);
#endif

	pixelColor.xyz += In.WorldPosition.w * wave1.rgb * wave2.rgb;
	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz *= shroud;
#endif
 
	return pixelColor;
}

// ----------------------------------------------------------------------------
// SHADER: PCAPixelShader
// ----------------------------------------------------------------------------
float4 PCAPixelShader_Xenon( PCAVSOutput In ) : COLOR
{
	return PCAPixelShader( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: PCA (High LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PSPCA_Multiplier_Final = 2 );

#define PSPCA_NumShadows \
	compile ps_2_0 PCAPixelShader(0), \
	compile ps_2_0 PCAPixelShader(1),

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSPCA_Array[PSPCA_Multiplier_Final] =
{
	PSPCA_NumShadows
};
#endif

technique PCA
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Water")
	>
	{
		VertexShader = compile vs_2_0 PCAVertexShader();
		PixelShader  = ARRAY_EXPRESSION_PS( PSPCA_Array, min(NumShadows, 1),
						compile PS_VERSION PCAPixelShader_Xenon() );

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
		FogEnable = false; // Fog handled in pixel shader
#endif
	}
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// SHADER: PCAVertexShader_M
// ----------------------------------------------------------------------------
struct PCAVSOutput_M
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float Fog : COLOR1;
	float4 PCATexCoord : TEXCOORD0;
	float2 WaveTexCoord[2] : TEXCOORD1;
	float2 EnvTexCoord : TEXCOORD3;
	float2 ShroudTexCoord : TEXCOORD4;
	float4 WorldNormal_WaterHeight : TEXCOORD5;
};

PCAVSOutput_M PCAVertexShader_M(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0, 
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	PCAVSOutput_M Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World).xyz;

	float AmpMult = 0.075f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z;
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	if (WaterDepth < DepthThres && Radius < RadiusThres)
	{
		// gw1
		float2 Pos = WP.xy; 
		float amp = AmpMult * GWAmpFreqPhaseSteepness1.x; 
		float freq = GWAmpFreqPhaseSteepness1.y + frac(WP.x) * 0.0005f;
		float phase = GWAmpFreqPhaseSteepness1.z;
		float steep = GWAmpFreqPhaseSteepness1.w;
		float2 dir = TexCoord0; 
		float2 perp = float2(-TexCoord0.y, TexCoord0.x);
		
		float a = freq * dot(Pos, dir) + phase * Time;
		float wa = amp * freq;
		float sa = sin(a);
		float ca = cos(a);
		float q = 0.15f * steep / wa;
		float px = q * amp * dir.x * ca;
		float py = q * amp * dir.y * ca;
		float pz = amp * sa;
		float nx = dir.x * wa * ca;
		float ny = dir.y * wa * ca;
		float nz = q * wa * sa;
		
		// gw2
		amp = AmpMult * GWAmpFreqPhaseSteepness2.x;
		freq = GWAmpFreqPhaseSteepness2.y + frac(WP.y) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness2.z;
		steep = GWAmpFreqPhaseSteepness2.w;
		dir = normalize(TexCoord0 + 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.15f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;
			
		// gw3
		amp = AmpMult * GWAmpFreqPhaseSteepness3.x;
		freq = GWAmpFreqPhaseSteepness3.y + frac(WP.z) * 0.0003f;
		phase = GWAmpFreqPhaseSteepness3.z;
		steep = GWAmpFreqPhaseSteepness3.w;
		dir = normalize(TexCoord0 - 0.4f * perp); 
		
		a = freq * dot(Pos, dir) + phase * Time;
		wa = amp * freq;
		sa = sin(a);
		ca = cos(a);
		q = 0.15f * steep / wa;
		px += q * amp * dir.x * ca;
		py += q * amp * dir.y * ca;
		pz += amp * sa;
		nx += dir.x * wa * ca;
		ny += dir.y * wa * ca;
		nz += q * wa * sa;

		WP.xyz += float3(0.75f * px, 0.75f * py, pz);		
		gerstNormal = normalize(float3(-nx, -ny, 1-nz));
		
		WaterDepth = WP.z - TerrainDepth;

		// add extra froth near leading edge of the wave
		float blendFactor = 0.75f;
		float DepthFactor = (DepthThres - WaterDepth)/DepthThres;
		float HeightThres = WaterPlaneHeight + 4.0f;
		float blendHeight = WaterPlaneHeight + 0.2f; 
		float Height = WP.z;
		if (Height > blendHeight) 
		{
			heightBlendFactor = (Height - blendHeight)/(HeightThres-blendHeight);
			heightBlendFactor *= heightBlendFactor;
			heightBlendFactor = DepthFactor * blendFactor * heightBlendFactor;
		}						
	}
	
	float shoreBlendFactor = 0.125f;
	float ShoreDepthThres = 15.0f;
	if (WaterDepth < ShoreDepthThres)
	{
		shoreBlendFactor += 0.5 * (ShoreDepthThres - WaterDepth)/ShoreDepthThres;
	}	
	heightBlendFactor += shoreBlendFactor;
	
	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];
	Out.Fog = CalculateFog(Fog, WP, CP);
	Out.WorldNormal_WaterHeight.w = heightBlendFactor;
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal_WaterHeight.xyz = gerstNormal;

#ifdef _WW3D_	
	Out.Color.xyz = 2.0f * DirectionalLight[0].Color * MaterialColorDiffuse.xyz * DimmingFactor;
#else // for Max
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(WN, DirectionalLight[i].Direction));
	}
	
	Out.Color = (AmbientLightColor + MaterialColorDiffuse * float4(diffuseLight, 1)) * DimmingFactor;
#endif	

	Out.Color.a = ComputeWaterTransparency(WaterDepth);

	float2 uvScale = (1.0f/600.0f, 1.0f/600.0f);
	float2 TexCoord = (float2(WP[0], WP[1])) * uvScale; 
	
	// env map texture
	Out.EnvTexCoord = TexCoord * EnvUVScale;

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
	Out.PCATexCoord.xy = mul(TexCoord, Wave1Matrix) * PCABumpUVScale.x; 
	Out.PCATexCoord.zw = (mul(TexCoord, Wave2Matrix) * PCABumpUVScale.y).yx; 

	Out.WaveTexCoord[0] = WP.xy * PCAWaveUVScale.x;
	Out.WaveTexCoord[1] = WP.xy * PCAWaveUVScale.y;
	
	Out.WorldNormal_WaterHeight.xyz = Out.WorldNormal_WaterHeight.xyz * 0.4 + PCASetup_M.Mean;
	return Out;
}

// Force following shader to partial precsion
#define float half
#define float2 half2
#define float3 half3
#define float4 half4

// ----------------------------------------------------------------------------
// SHADER: PCAPixelShader_M
// ----------------------------------------------------------------------------
float4 PCAPixelShader_M(PCAVSOutput_M In) : COLOR
{
#if 0
	// add some deep water swells
	float4 pcaTex1 = tex2D(SAMPLER(WaterPCATexture1), In.PCATexCoord.xy) - 0.5;//+tex2D(SAMPLER(WaterPCATexture1), In.PCATexCoord.wz)-1.0f; // +tex2D(SAMPLER(WaterPCATexture3), In.PCATexCoord.xy)-1.5f;
	float3 bumpNormal = PCA.Mean + float3(dot(PCA.Bases03X, pcaTex1), dot(PCA.Bases03Y, pcaTex1), dot(PCA.Bases03Z, pcaTex1));

	float4 pcaTex2 = tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.xy) - 0.5;//+tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.wz)-1.0f; // +tex2D(SAMPLER(WaterPCATexture3), In.PCATexCoord.wz)-1.5f;
	bumpNormal += float3(dot(PCA.Bases47X, pcaTex2), dot(PCA.Bases47Y, pcaTex2), dot(PCA.Bases47Z, pcaTex2));

    //bumpNormal = 0.4 * (bumpNormal * 4 - 2/*- 2 in VS */ + In.WorldNormal_WaterHeight.xyz);
    bumpNormal = bumpNormal * 1.6 - 0.8 + In.WorldNormal_WaterHeight.xyz;
    //bumpNormal = normalize(bumpNormal * 4 - 2/* - 2 in VS */ + In.WorldNormal_WaterHeight.xyz);
	//return float4(bumpNormal * 0.5 + 0.5, 1.0f);
#else
	// add some deep water swells
	float4 pcaTex1 = tex2D(SAMPLER(WaterPCATexture1), In.PCATexCoord.xy);//-0.5;//+tex2D(SAMPLER(WaterPCATexture1), In.PCATexCoord.wz)-1.0f; // +tex2D(SAMPLER(WaterPCATexture3), In.PCATexCoord.xy)-1.5f;
	float3 bumpNormal = /*PCASetup_M.Mean + */float3(dot(PCASetup_M.Bases03X, pcaTex1), dot(PCASetup_M.Bases03Y, pcaTex1), dot(PCASetup_M.Bases03Z, pcaTex1));

	float4 pcaTex2 = tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.xy);//-0.5;//+tex2D(SAMPLER(WaterPCATexture2), In.PCATexCoord.wz)-1.0f; // +tex2D(SAMPLER(WaterPCATexture3), In.PCATexCoord.wz)-1.5f;
	bumpNormal += float3(dot(PCASetup_M.Bases47X, pcaTex2), dot(PCASetup_M.Bases47Y, pcaTex2), dot(PCASetup_M.Bases47Z, pcaTex2));

    //bumpNormal = 0.4 * (bumpNormal * 4 - 2 + In.WorldNormal_WaterHeight.xyz);
    bumpNormal = bumpNormal + In.WorldNormal_WaterHeight.xyz;
    //bumpNormal = normalize(bumpNormal * 4 - 2/* - 2 in VS */ + In.WorldNormal_WaterHeight.xyz);
	//return float4(bumpNormal * 0.5 + 0.5, 1.0f);
#endif
	float2 bumpOffset = ReflectionPerturbation * bumpNormal.xy; 
	
	// environment map
	float2 envCoord = bumpOffset + In.EnvTexCoord;
	float4 diffuseColor = In.Color * tex2D(SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	// Compute lighting
	float4 diffuseLight = saturate(dot(bumpNormal, DirectionalLight[0].Direction));
				
	// do the lighting 
	pixelColor.xyz = diffuseColor * diffuseLight;
    	    			
	// add waves
	float2 whiteTexCoord = In.WaveTexCoord[0];// + bumpOffset; 
	float2 whiteTexCoord2 = In.WaveTexCoord[1];// + bumpOffset; 
	float3 wave1 = tex2D(SAMPLER(PCAFrothTexture), whiteTexCoord);
	float3 wave2 = tex2D(SAMPLER(PCAFrothTexture), whiteTexCoord2);
	pixelColor.xyz += In.WorldNormal_WaterHeight.w * wave1.rgb * wave2.rgb;

	// fog
	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	// shroud
	float3 shroud = tex2D(SAMPLER(ShroudTexture), In.ShroudTexCoord);
	pixelColor.xyz *= shroud;
#endif
 
	return pixelColor;
}

// Remove partial precision defines
#undef float
#undef float2
#undef float3
#undef float4

// ----------------------------------------------------------------------------
// TECHNIQUE: PCA_MediumQuality
// ----------------------------------------------------------------------------
technique _PCA_M
{
	pass P0
	{
		VertexShader = compile vs_2_0 PCAVertexShader_M();
		PixelShader  = compile ps_2_0 PCAPixelShader_M(); 

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
		FogEnable = false; // Fog handled in pixel shader
	}
#endif
}


// ----------------------------------------------------------------------------
// TECHNIQUE: PCA_LowQuality
// ----------------------------------------------------------------------------
technique _PCA_L
{
	pass P0
	{
		VertexShader = compile vs_1_1 BumpSpecularVertexShaderLow();
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
							add r0.rgb, r0, r1  // add waves 
							mul r0.rgb, r0, t2  // multiply shroud
							+ mov r0.a, v0.a	// take vertex alpha
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


#endif