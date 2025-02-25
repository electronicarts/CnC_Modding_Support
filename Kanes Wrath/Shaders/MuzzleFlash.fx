//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// FX Shader for Muzzle Flash
// NOTE: This is using Vertex Alpha as a Material ID to render multiple
//       materials in one draw call, eg. tag all verts as 0-3 vertex alpha
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

#if defined(EA_PLATFORM_WINDOWS)
// ----------------------------------------------------------------------------
// SAMPLER : nhendricks : had to pull these in here for MAX to compile
// ----------------------------------------------------------------------------
#define SAMPLER_2D_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	sampler2D samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_2D_END	};

#define SAMPLER( samplerName )	samplerName##Sampler

#define SAMPLER_CUBE_BEGIN(samplerName, annotations) \
	texture samplerName \
	< \
		annotations \
	>; \
	samplerCUBE samplerName##Sampler = sampler_state \
	{ \
		Texture = < samplerName >;
		
#define SAMPLER_CUBE_END };
#endif

// ----------------------------------------------------------------------------
// Skinning
// ----------------------------------------------------------------------------
static const int MaxSkinningBonesPerVertex = 2;

#include "Skinning.fxh"

// ----------------------------------------------------------------------------
// Material parameters
// ----------------------------------------------------------------------------
float3 ColorEmissive
<
	string UIName = "Emissive Material Color";
    string UIWidget = "Color";
> = float3(1.0, 1.0, 1.0);


SAMPLER_2D_BEGIN( Texture_0,
	string UIName = "Diffuse Texture";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
//	AddressU = Clamp;
//	AddressV = Clamp;
SAMPLER_2D_END

bool MultiTextureEnable
<
	string UIName = "Multi Texture Enable";
> = true;

float TexCoordTransformAngle_0 // Note all rotation matricies ues this number
<
	string UIName = "Radian Delta Rate per Frame";
    string UIWidget = "Slider";
	float UIMin = -100;
	float UIMax = 100;
> = float(1.0);

float TexCoordTransformU_0
<
	string UIName = "Vertex ID 0 Rotation Center in U";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

float TexCoordTransformV_0
<
	string UIName = "Vertex ID 0 Rotation Center in V";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

float TexCoordTransformU_1
<
	string UIName = "Vertex ID 1 Rotation Center in U";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

float TexCoordTransformV_1
<
	string UIName = "Vertex ID 1 Rotation Center in V";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

float TexCoordTransformU_2
<
	string UIName = "Vertex ID 2 Rotation Center in U";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

float TexCoordTransformV_2
<
	string UIName = "Vertex ID 2 Rotation Center in V";
    string UIWidget = "Slider";
	float UIMin = 0;
	float UIMax = 1;
> = float(.5);

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
#if !defined(_W3DVIEW_)
	string SasBindAddress = "Terrain.Shroud";
#endif
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudTexture,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

WW3DFog Fog
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.Fog";
> = DEFAULT_FOG_DISABLED;

// Variations for handling fog in the pixel shader
static const int FogMode_Disabled = 0;
static const int FogMode_Opaque = 1;
static const int FogMode_Additive = 2;
static const int FogMode_Multiplicative = 3;
static const int FogMode_MultiplicativeWAlpha = 4;

// Transformations
float4x4 View : View;
float4x3 ViewI : ViewInverse;
float4x4 Projection : Projection;

half Time : Time;

// ----------------------------------------------------------------------------
struct VSOutput
{
	float4 Position : POSITION;
	float3 DiffuseColor : COLOR0;
	float Fog : COLOR1;
	float2 TexCoord0 : TEXCOORD0;
	float2 TexCoord1 : TEXCOORD1;
	float2 ShroudTexCoord : TEXCOORD2;
};

// ----------------------------------------------------------------------------
VSOutput VS(VSInputSkinningMultipleBones InSkin,
	float4 VertexColor : COLOR0, 
	float2 TexCoord0 : TEXCOORD0,
	uniform int numJointsPerVertex)
{
	VSOutput Out;

	float3 worldPosition = 0;
	float3 worldNormal = 0;

	CalculatePositionAndNormal_L(InSkin, numJointsPerVertex, worldPosition, worldNormal);
	Out.Position = mul(float4(worldPosition, 1), mul(View, Projection));

	// --------------------- Unlit colorization -----------------------
	#if defined(_3DSMAX_)
		// Default vertex color is 0 in Max, that's bad.
		VertexColor = 1.0;
	#endif
	
	// ----- Rotate with animated offset on texture coordinate 0 -----
		//Collapse MAX UI spinners to something useful
		float angle = TexCoordTransformAngle_0 * Time;
		float2 UVPivot0 = float2(TexCoordTransformU_0, TexCoordTransformV_0);
		float2 UVPivot1 = float2(TexCoordTransformU_1, TexCoordTransformV_1);
		float2 UVPivot2 = float2(TexCoordTransformU_2, TexCoordTransformV_2);

	float cosAngle, sinAngle;
	sincos (angle, sinAngle, cosAngle);
					 
	float2x2 uvCoordRotate = { 1.0f, 0.0f, 1.0f, 0.0f };
	uvCoordRotate[0][0] = cosAngle;
	uvCoordRotate[0][1] = -sinAngle;
	uvCoordRotate[1][1] = uvCoordRotate[0][0];
	uvCoordRotate[1][0] = -uvCoordRotate[0][1];


	float2 texCoord0 = TexCoord0;
	float2 texCoord1 = TexCoord0;

	// Vertex alpha can be 0, 1 or 2 (in percent)
	VertexColor.w *= 100;
	
//	VertexColor.w = 2.4; //Debug for MAX as it does not read Vertex Color
	
	if (VertexColor.w < 0.5)
	{
		float2 texCoordCentered = TexCoord0 - UVPivot0;
		texCoord0 = mul(texCoordCentered, uvCoordRotate) + UVPivot0;
		if (MultiTextureEnable == true )
		{
			texCoord1 = mul(texCoordCentered, transpose(uvCoordRotate)) + UVPivot0;
		}
		else
		{
			texCoord1 = mul(texCoordCentered, uvCoordRotate) + UVPivot0;
		}
	}
	else if (VertexColor.w < 1.5)
	{
		float2 texCoordCentered = TexCoord0 - UVPivot1;
		texCoord0 = mul(texCoordCentered, uvCoordRotate) + UVPivot1;
		if (MultiTextureEnable == true )
		{
			texCoord1 = mul(texCoordCentered, transpose(uvCoordRotate)) + UVPivot1;
		}
		else
		{
			texCoord1 = mul(texCoordCentered, uvCoordRotate) + UVPivot1;
		}		
	}
	else if (VertexColor.w < 2.5)
	{
		float2 texCoordCentered = TexCoord0 - UVPivot2;
		texCoord0 = mul(texCoordCentered, uvCoordRotate) + UVPivot2;
		if (MultiTextureEnable == true )
		{
			texCoord1 = mul(texCoordCentered, transpose(uvCoordRotate)) + UVPivot2;
		}
		else
		{
			texCoord1 = mul(texCoordCentered, uvCoordRotate) + UVPivot2;
		}
	}
	
	Out.TexCoord0 = texCoord0;
	Out.TexCoord1 = texCoord1;
	Out.DiffuseColor = VertexColor * ColorEmissive;
	
	// Calculate shroud texture coordinates
	Out.ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	
	// Calculate fog
	Out.Fog = CalculateFog(Fog, worldPosition, ViewI[3]);
	
	return Out;
}

VSOutput VS_Xenon(VSInputSkinningMultipleBones InSkin,
	float4 VertexColor : COLOR0, 
	float2 TexCoord0 : TEXCOORD0)
{
	return VS(InSkin, VertexColor, TexCoord0, NumJointsPerVertex);
}

// ----------------------------------------------------------------------------
float4 PS(VSOutput In, uniform int fogMode) : COLOR0
{
	// Get vertex color
	float4 color = float4 (In.DiffuseColor, 1.0);
	color *= tex2D(SAMPLER(Texture_0), In.TexCoord0);// * MultiTextureEnable;
	color *= tex2D(SAMPLER(Texture_0), In.TexCoord1);
	
/*	
	if (MultiTextureEnable == true )
	{	
		color *= tex2D(SAMPLER(Texture_0), In.TexCoord1);
		color *= 2;
	}
*/
	if (fogMode == FogMode_Additive)
	{
	 	// Fog used with additive blending just needs to reduce the additive influence
		color.xyz *= In.Fog;
	}
	else if (fogMode == FogMode_Multiplicative)
	{
	 	// Fog used with multiply blending just needs to blend towards 1
		color.xyz = 1 - (1 - color.xyz) * In.Fog;
	}
        else if( fogMode == FogMode_MultiplicativeWAlpha)
        {
                // Fog used with multiply blending just needs to blend towards 1
                // needed to include alpha for rotor blades
		color.xyz = 1 - (1 - color.xyz) * In.Fog;
        }

	// Apply shroud
#if defined(_WW3D_) && !defined(_W3DVIEW_)
	if(fogMode == FogMode_MultiplicativeWAlpha)
	{
		color.xyz *= lerp( float3(1.0f,1.0f,1.0f), tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord),color.www);
	}
	else
	{
	color.xyz *= (tex2D( SAMPLER(ShroudTexture), In.ShroudTexCoord));
	}
	
#endif

	return color;
}

// ----------------------------------------------------------------------------
// Arrays
// ----------------------------------------------------------------------------
#define VS_NumJointsPerVertex \
	compile VS_VERSION_LOW VS(0), \
	compile VS_VERSION_LOW VS(1), \
	compile VS_VERSION_LOW VS(2)

DEFINE_ARRAY_MULTIPLIER( VS_Multiplier_Final = 3 );

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_Array[VS_Multiplier_Final] =
{
	VS_NumJointsPerVertex
};
#endif

// ----------------------------------------------------------------------------
// Techniques: Medium and up
// ----------------------------------------------------------------------------
technique Additive_M
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_HIGH PS(FogMode_Additive);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique Multiply_M
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_HIGH PS(FogMode_Multiplicative);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique MultiplyAlpha_M
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_HIGH PS(FogMode_MultiplicativeWAlpha);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		AlphaTestEnable = false;
	}  
}

#if ENABLE_LOD

// ----------------------------------------------------------------------------
// Techniques: Low
// ----------------------------------------------------------------------------
technique _Additive_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_LOW PS(FogMode_Disabled);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = One;
		DestBlend = One;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique _Multiply_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_LOW PS(FogMode_Disabled);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
technique _MultiplyAlpha_L
<
	int MaxSkinningBones = MaxSkinningBones_L;
>
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_Array,
			min(NumJointsPerVertex, 2),
			compile VS_VERSION VS_Xenon()
		);
		PixelShader = compile PS_VERSION_LOW PS(FogMode_Disabled);

		ZEnable = true;
		ZFunc = ZFUNC_INFRONT;
		ZWriteEnable = false;
		CullMode = none;
		AlphaBlendEnable = true;
		SrcBlend = DestColor;
		DestBlend = Zero;
		AlphaTestEnable = false;
	}  
}

#endif // #if ENABLE_LOD
