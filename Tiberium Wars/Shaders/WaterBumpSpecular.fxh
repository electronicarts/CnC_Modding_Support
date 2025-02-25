//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// "BumpSpecular" techniques for water shader
//////////////////////////////////////////////////////////////////////////////

// ----------------------------------------------------------------------------
// SHADER: BumpSpecular
// ----------------------------------------------------------------------------
struct BumpSpecularVSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float Fog : COLOR1;
	float4 BumpTexCoord : TEXCOORD0;
	float2 EnvTexCoord : TEXCOORD1;
	float3 ReflectionTexCoord : TEXCOORD2;
	float2 ShroudTexCoord : TEXCOORD3;
	float4 WaveTexCoord : TEXCOORD4;
	float4 ShadowMapTexCoord : TEXCOORD5;
	float3 WorldPosition : TEXCOORD6;
	float4 WorldNormal_WaterHeight : TEXCOORD7;
};

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularVertexShader
// ----------------------------------------------------------------------------
BumpSpecularVSOutput BumpSpecularVertexShader_U(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0,
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	BumpSpecularVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World);

//	float AmpMult = 0.55f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z;
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	
	float2 Pos = WP.xy; 
//	float amp = AmpMult * 4; 
//	float freq = 1; + frac(WP.x) * 0.5f;
//	float phase = .3;
//	float steep = 0;

	float amp = GWAmpFreqPhaseSteepness1.x;
	float freq = GWAmpFreqPhaseSteepness1.y;
	float phase = GWAmpFreqPhaseSteepness1.z;
	float steep = GWAmpFreqPhaseSteepness1.w;
	

	float2 dir = float2(-0.01f, -0.01f);
		
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
	amp = GWAmpFreqPhaseSteepness2.x;
	freq = GWAmpFreqPhaseSteepness2.y;
	phase = GWAmpFreqPhaseSteepness2.z;
	steep = GWAmpFreqPhaseSteepness2.w;
//	amp = AmpMult * 4;
//	freq = 3.5;
//	phase = .4;
//	steep = 0;
	dir = float2(-0.005f, -0.01f); 
	
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
	amp = GWAmpFreqPhaseSteepness3.x;
	freq = GWAmpFreqPhaseSteepness3.y;
	phase = GWAmpFreqPhaseSteepness3.z;
	steep = GWAmpFreqPhaseSteepness3.w;
	
//	amp = AmpMult * 2;
//	freq = 3;
//	phase = 2;
//	steep = 2;
	dir = float2(-0.015f, -0.01f);		
	
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

//-------------------------------------MIKEY------------------------------------------------
	// add extra froth near leading edge of the wave
	float blendRadius = 0.5f * RadiusThres;
	float blendFactor = 4.35f;

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

	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];

	Out.Fog = CalculateFog(Fog, WP, CP);
	Out.WorldPosition = float4(WP, heightBlendFactor);
	
  Out.WorldNormal_WaterHeight.w = heightBlendFactor;
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal_WaterHeight.xyz = WN + (gerstNormal* 0.75);

	
#ifdef _WW3D_	
	Out.Color = 2.0f * MaterialColorDiffuse * DimmingFactor; //THE OG MIKEY
	
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
	Out.EnvTexCoord = (TexCoord + 1.0 * WN.xy) * EnvUVScale;

	// reflection texture
 	Out.ReflectionTexCoord.xy = 0.5 * (hPosition.xy + hPosition.w * float2(1.0, 1.0));
 	Out.ReflectionTexCoord.z = hPosition.w;
	
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
	Out.BumpTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * BumpUVScale; 
	Out.BumpTexCoord.zw = (mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * BumpUVScale).yx;

	Out.WaveTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;
	Out.WaveTexCoord.zw = (mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * WaveUVScale).yx;
	
	float2 SpecularAngles = MySpecularDirection * DegreeToRadian;
	float sinAzimuth = sin(SpecularAngles.x);
	float cosAzimuth = cos(SpecularAngles.x);
	float sinElevation = sin(SpecularAngles.y);
	float cosElevation = cos(SpecularAngles.y);	

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, WP);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularPixelShader
// ----------------------------------------------------------------------------
float4 BumpSpecularPixelShader_U(BumpSpecularVSOutput In, uniform int numShadows) : COLOR
{
	// bump map
	float4 bump1 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.xy);
	float4 bump2 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.wz);
	float3 bumpNormal = In.WorldNormal_WaterHeight.xyz + 2.0f * (bump1 + bump2) - float3(2.0, 2.0, 2.0);
	
	bumpNormal.xy *= BumpScale;

	//---------------------------MIKEY-------------------------------
	float2 bumpOffset = ReflectionPerturbation * 1.3 * bumpNormal.xy; 
	bumpNormal = normalize(float4(bumpNormal, 0.00001f)).xyz;

	// environment map
	float2 envCoord = bumpOffset + In.EnvTexCoord;
	float4 diffuseColor = In.Color * tex2D( SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	//-------------------------------------------------------------------------------------------------------------
	// Compute lighting
	float3 eyeDirection = normalize(ViewI[3] - In.WorldPosition.xyz);
	float3 light0Direction = DirectionalLight[0].Direction;
	float3 light1Direction = DirectionalLight[1].Direction;
	float3 halfEyeLightVector = normalize(eyeDirection+light0Direction);
	SpecularExponent = 450; //TEMP MIKEY
	
    float4 lightingColor = lit(dot(bumpNormal, light0Direction.xyz),
			dot(bumpNormal, halfEyeLightVector), SpecularExponent);
			
	// control shadow darkness	
	float ShadowDarkness = 1; 
	if (numShadows >= 1)
	{
		float4 shadowTexCoord = In.ShadowMapTexCoord;
		shadowTexCoord.xy += bumpOffset *.05; 
		ShadowDarkness = shadow( SAMPLER(ShadowMap), shadowTexCoord, ShadowInfo); 
		
		if (ShadowDarkness < 1.0f)
		{
			ShadowDarkness = min(ShadowLightness + ShadowDarkness, 0.999f);	
		}	
		
		lightingColor.yz *= ShadowDarkness;
	}

//-------------------------------MIKEY SPECULAR SHADOWS------------------------------------------------------
	
	float4 shadowTexCoord = In.ShadowMapTexCoord;
	shadowTexCoord.xy += bumpOffset *.05;
	float3 MaskedSpecularColor = SpecularColor * ShadowDarkness;
	
	// Using the different weights for the red, green, and blue values (.3, .59, .11) are accepted global standards for color theory and saturation strengths.
	const float3 coef = float3(0.3, 0.59, 0.11);
	
	//Desaturate incoming DirectionalLight specular by 30%.		
	float3 GreyscaleSpecular = lerp(DirectionalLight[0].Color, dot(coef.xyz, DirectionalLight[0].Color), 0.1); 

	// do the lighting 
	pixelColor.xyz = GreyscaleSpecular * (diffuseColor * lightingColor.y + MaskedSpecularColor * 3 * lightingColor.z); //3x brighter specularity hardcoded.

//-------------------------------------------------------------------------------------------------------------
				
	// reflection 
	float2 ReflectionCoord = In.ReflectionTexCoord.xy/In.ReflectionTexCoord.z;

//----------------------MIKEY--------------------------------	
	float2 reflCoord = bumpOffset + ReflectionCoord;
	float3 reflColor = tex2D( SAMPLER(WaterReflectionTexture), reflCoord);

//----------------------MIKEY--------------------------------	
	
	// shroud and waves
	float2 whiteTexCoord = In.WaveTexCoord.xy + (bumpOffset * .5); 
	float2 whiteTexCoord2 = In.WaveTexCoord.zw + (bumpOffset * .5); 
	float3 wave1 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord);
	float3 wave2 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord2);
			
	// shroud and waves
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	
	// Calculate Fresnel Effect
	float fresnel = pow( 1-dot( eyeDirection * 1.0, bumpNormal.xyz ), 1.0 );
     
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz = lerp(pixelColor.xyz *.35 , reflColor *0.8, fresnel);
#endif

	pixelColor.xyz += wave1 * wave2 * (.15 + (.2 * (In.WorldNormal_WaterHeight.w) + 2 * max((.6 - In.Color.a),0)) * DirectionalLight[0].Color * (ShadowDarkness + .3));

	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz *= shroud;
#endif
 
	return pixelColor;
}

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularPixelShader_Xenon
// ----------------------------------------------------------------------------
float4 BumpSpecularPixelShader_U_Xenon(BumpSpecularVSOutput In ) : COLOR
{
	return BumpSpecularPixelShader_U( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: BumpSpecular (High LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PSBumpSpecular_U_Multiplier_Final = 2 );

#define PSBumpSpecular_U_NumShadows \
	compile PS_VERSION_ULTRAHIGH BumpSpecularPixelShader_U(0), \
	compile PS_VERSION_ULTRAHIGH BumpSpecularPixelShader_U(1),

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSBumpSpecular_U_Array[PSBumpSpecular_U_Multiplier_Final] =
{
	PSBumpSpecular_U_NumShadows
};
#endif

technique _BumpSpecular_U
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Water")
	>
	{
		VertexShader = compile VS_VERSION_ULTRAHIGH BumpSpecularVertexShader_U();
		PixelShader  = ARRAY_EXPRESSION_PS( PSBumpSpecular_U_Array, min(NumShadows, 1),
										compile PS_VERSION BumpSpecularPixelShader_U_Xenon() );

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
// SHADER: BumpSpecularVertexShader
// ----------------------------------------------------------------------------
BumpSpecularVSOutput BumpSpecularVertexShader(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0,
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	BumpSpecularVSOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World);

//	float AmpMult = 0.55f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z;
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	
	float2 Pos = WP.xy; 

	float amp = GWAmpFreqPhaseSteepness1.x;
	float freq = GWAmpFreqPhaseSteepness1.y;
	float phase = GWAmpFreqPhaseSteepness1.z;
	float steep = GWAmpFreqPhaseSteepness1.w;
	

	float2 dir = float2(-0.01f, -0.01f);
		
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
	amp = GWAmpFreqPhaseSteepness2.x;
	freq = GWAmpFreqPhaseSteepness2.y;
	phase = GWAmpFreqPhaseSteepness2.z;
	steep = GWAmpFreqPhaseSteepness2.w;
	dir = float2(-0.005f, -0.01f); 
	
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
	amp = GWAmpFreqPhaseSteepness3.x;
	freq = GWAmpFreqPhaseSteepness3.y;
	phase = GWAmpFreqPhaseSteepness3.z;
	steep = GWAmpFreqPhaseSteepness3.w;
	
	dir = float2(-0.015f, -0.01f);		
	
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

//-------------------------------------MIKEY------------------------------------------------
	// add extra froth near leading edge of the wave
	float blendRadius = 0.5f * RadiusThres;
	float blendFactor = 4.35f;

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

	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];

	Out.Fog = CalculateFog(Fog, WP, CP);
	Out.WorldPosition = float4(WP, heightBlendFactor);
	
  Out.WorldNormal_WaterHeight.w = heightBlendFactor;
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal_WaterHeight.xyz = WN + (gerstNormal* 0.75);

	
#ifdef _WW3D_	
	Out.Color = MaterialColorDiffuse * DimmingFactor / 2.0f;
	
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
	Out.EnvTexCoord = (TexCoord + 1.0 * WN.xy) * EnvUVScale;

	// reflection texture
 	float3 eyeDirection = normalize(ViewI[3] - WP);
	// Compute env map reflection direction
	Out.ReflectionTexCoord = -reflect(eyeDirection, WN);

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
	Out.BumpTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * BumpUVScale; 
	Out.BumpTexCoord.zw = (mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * BumpUVScale).yx;

	Out.WaveTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;
	Out.WaveTexCoord.zw = (mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * WaveUVScale).yx;
	
	float2 SpecularAngles = MySpecularDirection * DegreeToRadian;
	float sinAzimuth = sin(SpecularAngles.x);
	float cosAzimuth = cos(SpecularAngles.x);
	float sinElevation = sin(SpecularAngles.y);
	float cosElevation = cos(SpecularAngles.y);	

	Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(ShadowInfo, WP);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularPixelShader
// ----------------------------------------------------------------------------
float4 BumpSpecularPixelShader(BumpSpecularVSOutput In, uniform int numShadows) : COLOR
{
	// bump map
	float4 bump1 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.xy);
	float4 bump2 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.wz);
	float3 bumpNormal = In.WorldNormal_WaterHeight.xyz + 2.0f * (bump1 + bump2) - float3(2.0, 2.0, 2.0);
	
	bumpNormal.xy *= BumpScale;

	//---------------------------MIKEY-------------------------------
	float2 bumpOffset = ReflectionPerturbation * 1.3 * bumpNormal.xy; 
	bumpNormal = normalize(bumpNormal);

	// environment map
	float2 envCoord = bumpOffset + In.EnvTexCoord;
	float4 diffuseColor = In.Color * 4 * tex2D( SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	//-------------------------------------------------------------------------------------------------------------
	// Compute lighting
	float3 eyeDirection = normalize(ViewI[3] - In.WorldPosition.xyz);
	float3 light0Direction = DirectionalLight[0].Direction;
	float3 light1Direction = DirectionalLight[1].Direction;
	float3 halfEyeLightVector = normalize(eyeDirection+light0Direction);
	SpecularExponent = 450; //TEMP MIKEY
	
    float4 lightingColor = lit(dot(bumpNormal, light0Direction.xyz),
			dot(bumpNormal, halfEyeLightVector), SpecularExponent);
			
	// control shadow darkness	
	float ShadowDarkness = 1; 
	if (numShadows >= 1)
	{
		float4 shadowTexCoord = In.ShadowMapTexCoord;
		ShadowDarkness = shadow( SAMPLER(ShadowMap), shadowTexCoord, ShadowInfo); 
		
		lightingColor.yz *= ShadowDarkness;
	}

//-------------------------------MIKEY SPECULAR SHADOWS------------------------------------------------------
	
	// do the lighting 
	pixelColor.xyz = DirectionalLight[0].Color * (diffuseColor * lightingColor.y + SpecularColor * 3 * lightingColor.z); //3x brighter specularity hardcoded.

//-------------------------------------------------------------------------------------------------------------
				
    // Apply the reflection map
	float3 reflectionDirection = In.ReflectionTexCoord + float3(bumpOffset, 0);

	float3 reflectionColor = texCUBE(SAMPLER(EnvironmentTexture), reflectionDirection);
	
	// shroud and waves
	float2 whiteTexCoord = In.WaveTexCoord.xy + (bumpOffset * .5); 
	float3 wave1 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord);
			
	
	// Calculate Fresnel Effect
	float fresnel = pow( 1-dot( eyeDirection * 1.0, bumpNormal.xyz ), 1.0 );
     
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz = lerp(pixelColor.xyz *.35 , reflectionColor *0.8, fresnel);
#endif

	pixelColor.xyz += wave1 * (0.1 + (0.1 * In.WorldNormal_WaterHeight.w));

	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	// shroud and waves
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
	pixelColor.xyz *= shroud;
#endif
 
	return pixelColor;
}

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularPixelShader_Xenon
// ----------------------------------------------------------------------------
float4 BumpSpecularPixelShader_Xenon(BumpSpecularVSOutput In ) : COLOR
{
	return BumpSpecularPixelShader( In, min(NumShadows, 1) );
}

// ----------------------------------------------------------------------------
// TECHNIQUE: BumpSpecular (High LOD)
// ----------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER( PSBumpSpecular_Multiplier_Final = 2 );

#define PSBumpSpecular_NumShadows \
	compile PS_VERSION_HIGH BumpSpecularPixelShader(0), \
	compile PS_VERSION_HIGH BumpSpecularPixelShader(1),

#if SUPPORTS_SHADER_ARRAYS
pixelshader PSBumpSpecular_Array[PSBumpSpecular_Multiplier_Final] =
{
	PSBumpSpecular_NumShadows
};
#endif

technique BumpSpecular
{
	pass P0
	<
		USE_EXPRESSION_EVALUATOR("Water")
	>
	{
		VertexShader = compile VS_VERSION_HIGH BumpSpecularVertexShader();
		PixelShader  = ARRAY_EXPRESSION_PS( PSBumpSpecular_Array, min(NumShadows, 1),
										compile PS_VERSION BumpSpecularPixelShader_Xenon() );

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
// SHADER: BumpSpecular
// ----------------------------------------------------------------------------
struct BumpSpecularVSOutput_M
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float Fog : COLOR1;
	float4 BumpTexCoord : TEXCOORD0;
	float2 EnvTexCoord : TEXCOORD1;
	float3 HalfEyeLightDirection : TEXCOORD2;
	float2 ShroudTexCoord : TEXCOORD3;
	float2 WaveTexCoord : TEXCOORD4;
	float4 WorldNormal_WaterHeight : TEXCOORD5;
	float3 ReflectionTexCoord : TEXCOORD6;
};

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularVertexShader
// ----------------------------------------------------------------------------
BumpSpecularVSOutput_M BumpSpecularVertexShader_M(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0,
				float2 TexCoord1 : TEXCOORD1)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	BumpSpecularVSOutput_M Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));

	float3 WP = mul(float4(Position, 1), World);

	float AmpMult = 0.55f;
	float Radius = length(float2(WP.xy - Normal.xy));
	
	// add gerstner waves
	float3 gerstNormal = float3(0.0f, 0.0f, 1.0f);
	float TerrainDepth = Normal.z;
	float WaterPlaneHeight = WP.z; 
	float WaterDepth = WP.z - TerrainDepth;
	float DepthThres = TexCoord1.x; 
	float RadiusThres = TexCoord1.y; 
	float heightBlendFactor = 0.0f;
	
	float2 Pos = WP.xy; 
//	float amp = AmpMult * 4; 
//	float freq = 1; + frac(WP.x) * 0.5f;
//	float phase = .3;
//	float steep = 0;
	float2 dir = float2(-0.01f, -0.01f);
	
	float amp = GWAmpFreqPhaseSteepness1.x;
	float freq = GWAmpFreqPhaseSteepness1.y;
	float phase = GWAmpFreqPhaseSteepness1.z;
	float steep = GWAmpFreqPhaseSteepness1.w;	
		
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
//	amp = AmpMult * 4;
//	freq = 3.5;
//	phase = .4;
//	steep = 0;
	dir = float2(-0.005f, -0.01f); 
	
	amp = GWAmpFreqPhaseSteepness2.x;
	freq = GWAmpFreqPhaseSteepness2.y;
	phase = GWAmpFreqPhaseSteepness2.z;
	steep = GWAmpFreqPhaseSteepness2.w;	
	
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
//	amp = AmpMult * 2;
//	freq = 3;
//	phase = 2;
//	steep = 2;
	dir = float2(-0.015f, -0.01f);		
	
	amp = GWAmpFreqPhaseSteepness3.x;
	freq = GWAmpFreqPhaseSteepness3.y;
	phase = GWAmpFreqPhaseSteepness3.z;
	steep = GWAmpFreqPhaseSteepness3.w;	
	
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

//-------------------------------------MIKEY------------------------------------------------
	// add extra froth near leading edge of the wave
	float blendRadius = 0.5f * RadiusThres;
	float blendFactor = 4.35f;

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

	hPosition = mul(float4(WP, 1), View);
	hPosition = mul(hPosition, Projection);
	Out.Position = hPosition;
	
	float3 CP = ViewI[3];

	Out.Fog = CalculateFog(Fog, WP, CP);
	
	Out.WorldNormal_WaterHeight.w = heightBlendFactor;
	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	Out.WorldNormal_WaterHeight.xyz = WN + (gerstNormal* 0.75);

	
#ifdef _WW3D_	
	Out.Color = MaterialColorDiffuse * DimmingFactor;
	
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
	Out.EnvTexCoord = (TexCoord + 1.0 * WN.xy) * EnvUVScale;

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
	Out.BumpTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * BumpUVScale; 
	Out.BumpTexCoord.zw = (mul(TexCoord + Wave2Direction * (WindSpeed+WaveSpeed) * Time, Wave2Matrix) * BumpUVScale).yx;

	Out.WaveTexCoord.xy = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;
	
	float2 SpecularAngles = MySpecularDirection * DegreeToRadian;
	float sinAzimuth = sin(SpecularAngles.x);
	float cosAzimuth = cos(SpecularAngles.x);
	float sinElevation = sin(SpecularAngles.y);
	float cosElevation = cos(SpecularAngles.y);	

	float3 eyeDirection = normalize(ViewI[3] - WP);
	Out.HalfEyeLightDirection = normalize(eyeDirection + DirectionalLight[0].Direction);

	// Compute env map reflection direction
	Out.ReflectionTexCoord = -reflect(eyeDirection, WN);

	return Out;
}

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularPixelShader
// ----------------------------------------------------------------------------


// Force partial precision for following shader
#define float half
#define float2 half2
#define float3 half3
#define float4 half4

float4 BumpSpecularPixelShader_M(BumpSpecularVSOutput_M In) : COLOR
{
	// bump map
	float4 bump1 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.xy);
	float4 bump2 = tex2D( SAMPLER(WaterBumpTexture), In.BumpTexCoord.wz);
	float3 bumpNormal = In.WorldNormal_WaterHeight.xyz + 2.0f * (bump1 + bump2) - float3(2.0, 2.0, 2.0);
	
	bumpNormal.xy *= BumpScale;

	//---------------------------MIKEY-------------------------------
	float2 bumpOffset = ReflectionPerturbation * 1.3 * bumpNormal.xy; 
	bumpNormal = normalize(bumpNormal);

	// environment map
	float2 envCoord = bumpOffset + In.EnvTexCoord;
	float4 diffuseColor = In.Color * 2 * tex2D( SAMPLER(WaterEnvTexture), envCoord);

	float4 pixelColor;
	pixelColor.a = In.Color.a;
		
	//-------------------------------------------------------------------------------------------------------------
	// Compute lighting
	SpecularExponent = 450; //TEMP MIKEY
	
    float4 lightingColor = lit(dot(bumpNormal,  DirectionalLight[0].Direction),
			dot(bumpNormal, In.HalfEyeLightDirection), SpecularExponent);

	// do the lighting 
	pixelColor.xyz = DirectionalLight[0].Color * (diffuseColor * lightingColor.y + SpecularColor * 3 * lightingColor.z); //3x brighter specularity hardcoded.
	

    // Apply the reflection map
	float3 reflectionDirection = In.ReflectionTexCoord + float3(bumpOffset, 0);

	float3 reflectionColor = texCUBE(SAMPLER(EnvironmentTexture), reflectionDirection);

	// Calculate Fresnel Effect
	//float fresnel = pow( 1-dot( In.EyeDirection * 1.0, bumpNormal.xyz ), 1.0 );
	float fresnel = pow( 1-dot( float3(0, -0.75, 0.7), float3(0, 0, 1)), 1.0 );

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	pixelColor.xyz = lerp(pixelColor.xyz *.35 , reflectionColor *0.8, fresnel);
#endif

	// shroud and waves
	float2 whiteTexCoord = In.WaveTexCoord.xy + (bumpOffset * .5); 
	float3 wave1 = tex2D( SAMPLER(PCAFrothTexture), whiteTexCoord);
			
	pixelColor.xyz += wave1 * (0.1 + (0.1 * In.WorldNormal_WaterHeight.w));

	pixelColor.xyz = lerp(Fog.Color, pixelColor.xyz, In.Fog);

#if defined(_WW3D_) && !defined(_W3DVIEW_)
	float3 shroud = tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord);
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
// TECHNIQUE: BumpSpecular (Medium LOD)
// ----------------------------------------------------------------------------

technique _BumpSpecular_M
{
	pass P0
	{
		VertexShader = compile VS_VERSION_HIGH BumpSpecularVertexShader_M();
		PixelShader  = compile PS_VERSION_HIGH BumpSpecularPixelShader_M();

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
// SHADER: BumpSpecular_LowQuality
// ----------------------------------------------------------------------------
struct BumpSpecularVSLowOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 BumpTexCoord : TEXCOORD0;
	float2 EnvTexCoord : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
	float2 WaveTexCoord : TEXCOORD3;
};

// ----------------------------------------------------------------------------
// SHADER: BumpSpecularVertexShaderLow
// ----------------------------------------------------------------------------
BumpSpecularVSLowOutput BumpSpecularVertexShaderLow(float3 Position : POSITION, 
				float3 Normal : NORMAL,
				float2 TexCoord0 : TEXCOORD0)
{
	USE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);

	BumpSpecularVSLowOutput Out;
	
	float4 hPosition = mul(float4(Position, 1), WorldViewProjection);
	Out.Position = hPosition;

	float3 N = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)WorldView));
	float3 WP = mul(float4(Position, 1), World);	
	float3 WN = normalize(mul(float3(0.0f, 0.0f, 1.0f), (float3x3)World));
	float modifier = dot(WN, float3(0, 0, 1));
	modifier *= modifier;
	modifier *= modifier;

	float TerrainDepth = Normal.z;
	float WaterDepth = WP.z - TerrainDepth;

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
	Out.BumpTexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+BumpSpeed) * Time, Wave1Matrix) * BumpUVScale; 
	Out.WaveTexCoord = mul(TexCoord + Wave1Direction * (WindSpeed+WaveSpeed) * Time, Wave1Matrix) * WaveUVScale;

	return Out;
}

// ----------------------------------------------------------------------------
float getBumpMatrixAngle()
{
	static const float RadiansPerSecond = 3.14 * 0.05;
	return Time * RadiansPerSecond;
}

// ----------------------------------------------------------------------------
// TECHNIQUE: BumpSpecular (Low LOD)
// ----------------------------------------------------------------------------
technique _BumpSpecular_L
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
    	
		BumpEnvMat00[1] = ( cos(getBumpMatrixAngle()) );// 0.05f;
		BumpEnvMat01[1] = ( -sin(getBumpMatrixAngle()) );//0.0f;
		BumpEnvMat10[1] = ( sin(getBumpMatrixAngle()) );//0.0f;
		BumpEnvMat11[1] = ( cos(getBumpMatrixAngle()) );// 0.05f;

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
