//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// FX Shader for Lightning FX (unlit, 2 texture solution, assumed additive)
//////////////////////////////////////////////////////////////////////////////

//#define SUPPORT_FOG 1
//#define SUPPORT_PROTONCOLLIDER 1

#include "Common.fxh"
#include "Gamma.fxh"
#include "Random.fxh"


// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
static const int MaxSkinningBonesPerVertex = 2;

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------
#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

float4x4 GetViewProjection()
{
	return ViewProjection;
}

float3 GetEyePosition()
{
    return EyePosition;
}
#else // #if defined(_WW3D_)
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

float3 GetEyePosition()
{
    return ViewI[3];
}
#endif // #if defined(_WW3D_)

float Time : Time;

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

float3 ColorDiffuse
<
	string UIName = "Diffuse Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);

float EmissiveHDRMultipler
<
	string UIName = "Emissive HDR Multiplier";
    string UIWidget = "Slider";
    float UIMax = 200;
> = 1.0;

bool MultiTextureEnable
<
	string UIName = "Multi-Texture Enable";
> = false;

float4 DiffuseCoordOffset
<
	string UIName = "Diffuse Coord Offset/Scale"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.001f;
> = float4(0.00, 0.00, 1.0, 1.0);

#if !defined(SUPPORT_PROTONCOLLIDER)
	bool MultiplyBlendEnable
	<
		string UIName = "Multiply Blend Enable";
	> = false;

	float EdgeFadeOut
	<
		string UIName = "Edge fade out";
		string UIWidget = "Slider";
	> = 0.0f;
#endif //SUPPORT_PROTONCOLLIDER

// ----------------------------------------------------------------------------
// Displace Mapping
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( Texture_1,
	string UIName = "Displace Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END

bool UniqueWorldCoordEnable
<
	string UIName = "Unique World Coords Enable";
> = false;

float UniqueWorldCoordScalar
<
	string UIName = "Unique World Coords Scale"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.001f;
> = 0.01;

float UniqueWorldCoordStrength
<
	string UIName = "Unique World Coords Strength"; 
    string UIWidget = "Slider";
	float UIMax = 1.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float DisplaceScalar
<
	string UIName = "Displace Scale"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float DisplaceAmp
<
	string UIName = "Displace Amplitude"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

float DisplaceDivergenceAngle
<
	string UIName = "Displace Divergence Angle"; 
    string UIWidget = "Slider";
	float UIMax = 180.0f;
	float UIMin = 0;
	float UIStep = 0.5f;
> = 0.0;

float DisplaceSpeed
<
	string UIName = "Displace Speed"; 
    string UIWidget = "Slider";
	float UIMax = 50.0f;
	float UIMin = 0;
	float UIStep = 0.01f;
> = 1.0;

#if defined(SUPPORT_PROTONCOLLIDER)

// ----------------------------------------------------------------------------
// Mask Mapping for Proton Collider FX
// ----------------------------------------------------------------------------

SAMPLER_2D_BEGIN( Texture_2,
	string UIName = "Mask Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

#endif

// ----------------------------------------------------------------------------
// House coloring
// ----------------------------------------------------------------------------
bool UseRecolorColors
<
	string UIName = "Allow House Color";
> = false;

bool CullingEnable
<
	string UIName = "Culling Enable";
> = true;

#if !defined(USE_INDIRECT_CONSTANT)
float OpacityOverride
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.OpacityOverride";
> = 1.0;
#endif // #if !defined(USE_INDIRECT_CONSTANT)

// ----------------------------------------------------------------------------
// SHADER : DEFAULT
// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position			: POSITION;
	float4 DiffuseColor		: TEXCOORD0;
	float4 DiffuseTexCoord	: TEXCOORD1;
	float4 DisplaceTexCoord	: TEXCOORD2;
#if defined(SUPPORT_PROTONCOLLIDER)	
	float  MaskTexCoord		: TEXCOORD3;
#endif
#if defined(SUPPORT_FOG)
	float  Fog				: TEXCOORD4;
#endif // #if defined(SUPPORT_FOG)
};

// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningMultipleBones InSkin,
		float2 TexCoord0 : TEXCOORD0,
		float4 VertexColor: COLOR0)
{
	
	VSOutput Out;
	
	float3 worldPosition = 0;
	float3 worldNormal = 0;

	const int numJointsPerVertex = 0;
	CalculatePositionAndNormal(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	
	#if defined(_3DSMAX_)
		// Default vertex color is 0 in Max, that's bad.
		VertexColor = 1.0;
		
		// A little bit better motion previewing in MAX
		Time *= .25;
	#endif

	//Calculate the displace texture coordinates
	DisplaceSpeed *= Time * .01; // animate Displace as a multiplier of Time with a a happy MAX modifier

	//This is the wrong way, but there have been too many FX based on this to fix it now
	float2 DisplaceTexCoords = TexCoord0 * DisplaceScalar;

	if (UniqueWorldCoordEnable == true )
	{
		#if defined(SUPPORT_PROTONCOLLIDER)
			// This is the right way
			DisplaceTexCoords.xy = (worldPosition.xy * UniqueWorldCoordScalar * .01) * UniqueWorldCoordStrength; //the ".01" helps max with a small spinner
		#else
			//This is the wrong way, but there have been too many FX based on this to fix it now
			DisplaceTexCoords.y += (worldPosition.y + worldPosition.x) * UniqueWorldCoordScalar * .1; //the ".1" helps max with a small spinner
		#endif
	} 

	// Build Displace Texture Rotation Matrix And Convert Degrees to Radians -----
	float cosAngle, sinAngle;
	cosAngle = 0;
	sinAngle = 0;
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	
	sincos (DisplaceDivergenceAngle * .017453, sinAngle, cosAngle);
					 
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];

	// Rotate and Animate Displace Divergence Texture Coords --------------------
	float2 DisplaceTexCoordsDiverge = mul(DisplaceTexCoords, uvCoordRotate);
	DisplaceTexCoordsDiverge.x += DisplaceSpeed;
	float2 DisplaceTexCoordsDivergeInv = mul(DisplaceTexCoords, transpose(uvCoordRotate));	
	DisplaceTexCoordsDivergeInv.x += DisplaceSpeed;	

#if defined(SUPPORT_PROTONCOLLIDER)
	float3 DiffuseColor = VertexColor.xyz * ColorDiffuse;
	float Opacity = VertexColor.w;
#else //SUPPORT_PROTONCOLLIDER	
	float3 DiffuseColor = VertexColor.xyz * (MultiplyBlendEnable?(1-ColorDiffuse):ColorDiffuse);
	// Compute view direction in world space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	float viewingAngle = abs(dot(worldEyeDir,worldNormal));
	float fadeOut = smoothstep(0, EdgeFadeOut, viewingAngle);
	// This is a hack, the particle system can only adjust OpacityOverride so we use that for now. MJ
	float Opacity = VertexColor.w * fadeOut * OpacityOverride;
#endif //SUPPORT_PROTONCOLLIDER	

	// Compute all registers
	Out.Position = mul(float4(worldPosition, 1), GetViewProjection());
	Out.DiffuseColor = Opacity * float4(DiffuseColor * EmissiveHDRMultipler, 1.0);

#if defined(EA_PLATFORM_PS3)
	// $note(WSK) 2008/12/18 On PS3, for additive alpha blending, we need to set the diffuse color to 1.0
	Out.DiffuseColor.w = 1.0;
#endif // #if defined(EA_PLATFORM_PS3)
	
	TexCoord0.xy *= DiffuseCoordOffset.zw;
	
	// Restrict the numerical range to 0..1 to hide precision issues in the texture sampling when Time goes really large
	float2 offset = frac(DiffuseCoordOffset.xy * Time);
	
	Out.DiffuseTexCoord.xyzw = TexCoord0.xyxy + offset.xyxy;
	if (MultiTextureEnable == true )
	{	
		Out.DiffuseTexCoord.zw = TexCoord0.xy * DiffuseCoordOffset.zw - offset;
	}
	Out.DisplaceTexCoord = float4(DisplaceTexCoordsDiverge, DisplaceTexCoordsDivergeInv);
#if defined(SUPPORT_FOG)
	Out.Fog = CalculateFog(Fog, worldPosition, GetEyePosition());
#endif // #if defined(SUPPORT_FOG)
	
#if defined(SUPPORT_PROTONCOLLIDER)	
	Out.MaskTexCoord = (OpacityOverride * 3)- 1;
#endif	
	
	return Out;
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	float4 color = In.DiffuseColor;

	float3 textureDisplace = tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.xy).xyz;
	textureDisplace += tex2D( SAMPLER(Texture_1), In.DisplaceTexCoord.zw).xyz;	
	textureDisplace = textureDisplace - 1;
	
	float4 displacedTextureCoords = In.DiffuseTexCoord + (textureDisplace.xyxy * DisplaceAmp);
	
	float4 textures = tex2D( SAMPLER(Texture_0), displacedTextureCoords.xy);

	if (MultiTextureEnable)
	{
		textures *= tex2D( SAMPLER(Texture_0), displacedTextureCoords.zw);
	}

	textures.xyz = GammaToLinear(textures.xyz);
	color *= textures;

#if !defined(SUPPORT_PROTONCOLLIDER)	
	if (MultiplyBlendEnable)
	{
		color = .5 - color;
	}
#endif //SUPPORT_PROTONCOLLIDER	

	
#if defined(SUPPORT_PROTONCOLLIDER)
	color.w = 1;
	float3 maskDiffuse = tex2D( SAMPLER(Texture_2), (In.DiffuseTexCoord.xy - In.MaskTexCoord)).xyz;
	#if !defined(_3DSMAX_)
		color.xyz *= maskDiffuse; // MAX does not play well with multiple textures
	#endif

#endif //SUPPORT_PROTONCOLLIDER
	
	// Overbrighten	
	color.xyz += color.xyz;

#if defined(SUPPORT_FOG)
	float fogStrength = In.Fog;
 	// Fog used with additive blending just needs to reduce the additive influence, not blend towards the fog color
	color.xyz *= fogStrength;
#endif // #if defined(SUPPORT_FOG)

	return color;
}

// ----------------------------------------------------------------------------
// Technique: Default
// ----------------------------------------------------------------------------
technique Default
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
			
		PixelShader = compile PS_2_0 PS();

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		AlphaTestEnable = false;
		AlphaBlendEnable = true;
		
#if defined(EA_PLATFORM_WINDOWS)
		CullMode = ( CullingEnable ? D3DCULL_CW : D3DCULL_NONE );

		#if !defined(SUPPORT_PROTONCOLLIDER)
			// Additive or Multiply Blend Mode
			SrcBlend = ( MultiplyBlendEnable == true ? D3DBLEND_DESTCOLOR : D3DBLEND_ONE );
			DestBlend = ( MultiplyBlendEnable == true ? D3DBLEND_ZERO : D3DBLEND_ONE );
		#else
			// Force Additive for SUPPORT_PROTONCOLLIDER
			SrcBlend = One;
			DestBlend = One;
		#endif //SUPPORT_PROTONCOLLIDER
#else
		CullMode = None;

		// Additive or Multiply Blend Mode
		SrcBlend = One;
		DestBlend = One;
#endif

	}  
}
