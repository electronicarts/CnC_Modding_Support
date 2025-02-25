//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain FX Shader
//////////////////////////////////////////////////////////////////////////////

#define SUPPORT_SSAO 1	// enable SSAO
#define SUPPORT_CLOUDS 1
#define SUPPORT_FOG 1
#define SUPPORT_GLOBAL_LIGHTS 1
#define SUPPORT_LOCAL_LIGHTS 1
#define MaxNumPointLights 6

#include "Common.fxh"
#include "SSAO.fxh"
#include "Gamma.fxh"
#include "MacroTexture.fxh"

#if defined(EA_PLATFORM_XENON)
	#define TERRAIN_USE_MULTIPLE_STREAM
#endif

static const float SpecularExponent = 40;
static const float BumpScale = .75;
static const bool EnableNormalMap = true;
static const float HDRColorRange = 2.0f;
static const float3 SpecularColor = float3(1.0, 1.0, 1.0) * HDRColorRange;

//  The Blendweight is the alpha value at the corner
// 
//	0-----3
//  |     |
//  |     |
//	|     |
//  1-----2

// Since the values is normalize to be > 0, we need to add 1 so -1 become 0 in the lookup table
static const float4 BLENDWEIGHT_LUT[2][13] =
{
	// Normal
	{
		{  1.0,  1.0,  1.0,  1.0 },	// BLENDTYPE_NONE							
		{  1.0,  1.0,  2.0,  2.0 },	// BLENDTYPE_HORIZONTAL,
		{  2.0,  2.0,  1.0,  1.0 },	// BLENDTYPE_HORIZONTAL_INVERTED,
		{  2.0,  1.0,  1.0,  2.0 },	// BLENDTYPE_VERTICAL,
		{  1.0,  2.0,  2.0,  1.0 },	// BLENDTYPE_VERTICAL_INVERTED,
		{  1.0,  0.0,  1.0,  2.0 },	// BLENDTYPE_RIGHTDIAGONAL,
		{  0.0,  1.0,  2.0,  1.0 },	// BLENDTYPE_RIGHTDIAGONAL_INVERTED,
		{  2.0,  1.0,  2.0,  3.0 },	// BLENDTYPE_RIGHTDIAGONAL_LONG,
		{  1.0,  2.0,  3.0,  2.0 },	// BLENDTYPE_RIGHTDIAGONAL_LONG_INVERTED,
		{  2.0,  1.0,  0.0,  1.0 },	// BLENDTYPE_LEFTDIAGONAL,
		{  1.0,  2.0,  1.0,  0.0 },	// BLENDTYPE_LEFTDIAGONAL_INVERTED,
		{  3.0,  2.0,  1.0,  2.0 },	// BLENDTYPE_LEFTDIAGONAL_LONG,
		{  2.0,  3.0,  2.0,  1.0 },	// BLENDTYPE_LEFTDIAGONAL_LONG_INVERTED,
	},
	// Flipped (first column from Normal is moved to the last)
	{
		{  1.0,  1.0,  1.0,  1.0 },	// BLENDTYPE_NONE							
		{  1.0,  2.0,  2.0,  1.0 },	// BLENDTYPE_HORIZONTAL,
		{  2.0,  1.0,  1.0,  2.0 },	// BLENDTYPE_HORIZONTAL_INVERTED,
		{  1.0,  1.0,  2.0,  2.0 },	// BLENDTYPE_VERTICAL,
		{  2.0,  2.0,  1.0,  1.0 },	// BLENDTYPE_VERTICAL_INVERTED,
		{  0.0,  1.0,  2.0,  1.0 },	// BLENDTYPE_RIGHTDIAGONAL,
		{  1.0,  2.0,  1.0,  0.0 },	// BLENDTYPE_RIGHTDIAGONAL_INVERTED,
		{  1.0,  2.0,  3.0,  2.0 },	// BLENDTYPE_RIGHTDIAGONAL_LONG,
		{  2.0,  3.0,  2.0,  1.0 },	// BLENDTYPE_RIGHTDIAGONAL_LONG_INVERTED,
		{  1.0,  0.0,  1.0,  2.0 },	// BLENDTYPE_LEFTDIAGONAL,
		{  2.0,  1.0,  0.0,  1.0 },	// BLENDTYPE_LEFTDIAGONAL_INVERTED,
		{  2.0,  1.0,  2.0,  3.0 },	// BLENDTYPE_LEFTDIAGONAL_LONG,
		{  3.0,  2.0,  1.0,  2.0 },	// BLENDTYPE_LEFTDIAGONAL_LONG_INVERTED,
	}
};


// The vertex generated in the order is
// v3-----v2
//  |     |
//  |     |
//  |     |
// v0-----v1
//
// The 2 tri we are building is 0,1,3 and 3,1,2
// 0-----3  3-----2
// |   / |  |\    |
// |  /  |  |  \  |
// |/    |  |    \|
// 1-----2  0-----1
// Normal   Flipped
//
// The reference point for x,y is v0, the following table holds the adjustment of x and y depends on the index (0-3)
// For UV offset, the reference point is v3

#define UV_OFFSET_PER_CELL 469
static const float4 TERRAIN_CORNER_INDEX_OFFSET_LUT[2][4] =
{
//		float4(x, y, UV offset x (per cell), UV offset y (per cell) )
	// Normal
	{
		float4(	1.0, 0.0,                  0,                  0 ),
		float4(	0.0, 0.0,                  0, UV_OFFSET_PER_CELL ),
		float4(	0.0, 1.0, UV_OFFSET_PER_CELL, UV_OFFSET_PER_CELL ),
		float4(	1.0, 1.0, UV_OFFSET_PER_CELL,                  0 ),
	}
	, // Flipped
	{
		float4(	0.0, 0.0,                  0,                  0 ),
		float4(	0.0, 1.0, UV_OFFSET_PER_CELL,                  0 ),
		float4(	1.0, 1.0, UV_OFFSET_PER_CELL,-UV_OFFSET_PER_CELL ),
		float4(	1.0, 0.0,                  0,-UV_OFFSET_PER_CELL ),
	}
};

#if !HIZ_CULLING
#define SCORCHMARK_Z_BIAS -0.0002
#define ROAD_Z_BIAS -0.0004
#else
#define SCORCHMARK_Z_BIAS 0.0002
#define ROAD_Z_BIAS 0.0004
#endif

int _SasGlobal : SasGlobal
<
	string UIWidget = "None";
	int3 SasVersion = int3(1, 0, 0);
	
	int MaxLocalLights = MaxNumPointLights;
> = 0;

// ----------------------------------------------------------------------------
// Terrain specific textures
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( BaseSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;	
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerClamped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	MaxAnisotropy = 1;
    AddressU = Clamp;
    AddressV = Clamp;	
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = MipFilterBest;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( BaseSamplerWrapped_L,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.BaseTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Point;
	MaxAnisotropy = 1;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerClamped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

SAMPLER_2D_BEGIN( NormalSamplerWrapped,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.NormalTexture";
	int WW3DDynamicSet = DS_CUSTOM_FIRST;
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	MaxAnisotropy = 8;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Shroud
// ----------------------------------------------------------------------------
ShroudSetup Shroud
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud";
> = DEFAULT_SHROUD;


SAMPLER_2D_BEGIN( ShroudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Shroud.Texture";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Clamp;
    AddressV = Clamp;
SAMPLER_2D_END

// ----------------------------------------------------------------------------
// Cloud textures
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN( CloudSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Cloud.Texture";
	string ResourceName = "ShaderPreviewCloud.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
    AddressU = Wrap;
    AddressV = Wrap;
SAMPLER_2D_END


static const int RenderingMode_TerrainTile = 0;
static const int RenderingMode_Cliff = 1;
static const int RenderingMode_Road = 2;
static const int RenderingMode_Scorch = 3;
static const int RenderingMode_NumOf = 4;



// ----------------------------------------------------------------------------
// Using Terrain Atlas for rendering
// ----------------------------------------------------------------------------

#if defined(EA_PLATFORM_WINDOWS)
bool IsTerrainAtlasEnabled
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.IsTerrainAtlasEnabled";
> = false;
#endif // #if defined(EA_PLATFORM_WINDOWS)


// ----------------------------------------------------------------------------
// Shadow mapping
// ----------------------------------------------------------------------------
// Note (WSK) 2008/05/28 - leaving this here since if we move this up, the registers are shifted and 
//							some register seems to get stomped on if we don't define these here on Xenon.
#include "ShadowMap.fxh"

// ----------------------------------------------------------------------------
// Transformations
// ----------------------------------------------------------------------------

#if defined(_WW3D_)
#if !defined(USE_INDIRECT_CONSTANT)
float3 EyePosition
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.Position";
>;

float4x4 ViewProjection
<
	string UIWidget = "None";
	string SasBindAddress = "Sas.Camera.WorldToProjection";
>;

#endif // #if !defined(USE_INDIRECT_CONSTANT)

float3 GetEyePosition()
{
    return EyePosition;
}

float4x4 GetViewProjection()
{
	return ViewProjection;
}
#else // #if defined(_WW3D_)
float4x4 View           : View;
float4x3 ViewI          : ViewInverse;
float4x4 Projection     : Projection;

float3 GetEyePosition()
{
    return ViewI[3];
}

float4x4 GetViewProjection()
{
	return mul(View, Projection);
}

#endif // #if defined(_WW3D_)

// Time (ie. material is animated)
float Time : Time;

// ---------------------------------------------------------------------------
struct VSOutputDefault
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float  Fog : COLOR1;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float2 ShroudTexCoord : TEXCOORD2;
    float3 WorldPosition : TEXCOORD3;
	float4 MainLightDirection_Falloff : TEXCOORD4;
	float3 MainHalfEyeLightDirection : TEXCOORD5_CENTROID;
	float4 ShadowMapTexCoord : TEXCOORD6;
};
	
// ---------------------------------------------------------------------------
VSOutputDefault VS_Default(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	float3 Tangent : TANGENT,
	float3 Binormal : BINORMAL,
	uniform int renderingMode,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
	
	ISOLATE Out.Position = mul(float4(Position, 1), GetViewProjection());

	float3 worldPosition = Position;
	Out.Fog = CalculateFog(Fog, worldPosition, GetEyePosition());
	
	float3 worldNormal = Normal;

	float3 tangent;
	float3 binormal;
	if(renderingMode == RenderingMode_Scorch)
	{
		tangent = Tangent;
		binormal = Binormal;
	}
	else
	{
		tangent = cross(worldNormal, float3(-1, 0, 0));
		binormal = cross(worldNormal, float3(0, 1, 0));
	}
	
	// Build 3x3 tranform from object to tangent space
	float3x3 worldToTangentSpace = transpose(float3x3(-binormal, -tangent, Normal));

	// Compute lighting direction in tangent space
	float3 worldLightDir = DirectionalLight[0].Direction;
	Out.MainLightDirection_Falloff.xyz = mul(worldLightDir, worldToTangentSpace);
	Out.MainLightDirection_Falloff.w = max(0, dot(worldNormal, DirectionalLight[0].Direction));
	
	// Compute view direction in tangent space
	float3 worldEyeDir = normalize(GetEyePosition() - worldPosition);
	Out.MainHalfEyeLightDirection = normalize(mul(worldLightDir + worldEyeDir, worldToTangentSpace));

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	diffuseColor /= HDRColorRange; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
//	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
//	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);

	Out.ShroudTexCoord = ShroudTexCoord;
	Out.WorldPosition = worldPosition;
//    Out.CloudTexCoord_MacroTexCoord.xy = CloudTexCoord.xy;
//    Out.CloudTexCoord_MacroTexCoord.zw = MacroTexCoord.yx;

	if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord_PerspectiveCorrect(worldPosition);
	}
	else
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
	}

	return Out;
}

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainTile(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	float3 Tangent : TANGENT,
	float3 Binormal : BINORMAL,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
	float3 Position	= Position_BlendWeight1.xyz;
	float3 Normal	= Normal_BlendWeight2.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
	if (isTextureAtlasEnabled)		// [PS3] TODO - this 'if' causes issues when running.
#endif
	{
		// Unpack vertex data
		Normal = (Normal_BlendWeight2.xyz / 100.0) - 1.0;

		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default(Position, Normal, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, Tangent, Binormal, RenderingMode_TerrainTile, isTextureAtlasEnabled);
	
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
	if (isTextureAtlasEnabled)		// [PS3] TODO - this 'if' causes issues when running.
#endif
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	return Out;
}

#if defined(TERRAIN_USE_MULTIPLE_STREAM)

VSOutputDefault VS_TerrainTileVFetch(
    int Index : INDEX,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
    float4 BaseTexCoord;
    float4 BlendTex1Coord;
    float4 BlendTex2Coord;
	float3 Tangent = float3(-1, 0, 0);
	float3 Binormal = float3(0, 1, 0);

	float4 FlipVisibleFlag;
	float4 BlendWeights;

	// Fetching the cell index for UV info
	float cellIndex		= trunc(Index / 4.0);

	// Fetch the UV information
    asm
    {
        vfetch BaseTexCoord,		cellIndex, texcoord3;
        vfetch BlendTex1Coord,		cellIndex, texcoord4;
        vfetch BlendTex2Coord,		cellIndex, texcoord5;
		vfetch BlendWeights,		cellIndex, texcoord6;
		vfetch FlipVisibleFlag,		cellIndex, texcoord7;
    };

	// Getting the flags
	float IsFlipped = FlipVisibleFlag.x;
	float IsVisible = FlipVisibleFlag.y;

	// Calculate the index within a cell (0-3)
	float vertexIndex	= fmod(Index, 4.0);

	// Calculate the base row and column index for the corner vertex
	const float vertsPerTile = 16.0;
	float2 xy			= float2(trunc(cellIndex / vertsPerTile), fmod(cellIndex, vertsPerTile)) + TERRAIN_CORNER_INDEX_OFFSET_LUT[IsFlipped][vertexIndex].xy;

	// Update the UV offset based on the vertexIndex
	float2 uvOffset		= TERRAIN_CORNER_INDEX_OFFSET_LUT[IsFlipped][vertexIndex].zw;
	BaseTexCoord.xy		+= uvOffset.xy;
	BlendTex1Coord.xy	+= uvOffset.xy;
	BlendTex2Coord.xy	+= uvOffset.xy;

	// Calculate the corner index, after all the offset
	float cornerIndex	= xy.y + xy.x * (vertsPerTile + 1.0);

	float4 Position_BlendWeight1;
	float4 Normal_BlendWeight2;

	// Fetch the position and normal data
	asm
	{
		vfetch Position_BlendWeight1,	cornerIndex, position0;
		vfetch Normal_BlendWeight2,		cornerIndex, normal0;
	};

	// Multiply xy by visible, to force x,y be 0,0 for invisible tile
	Position_BlendWeight1.xy *= IsVisible;

	// Look up the blend weights
	Position_BlendWeight1.w = BLENDWEIGHT_LUT[IsFlipped][BlendWeights.x][vertexIndex];
	Normal_BlendWeight2.w   = BLENDWEIGHT_LUT[IsFlipped][BlendWeights.y][vertexIndex];

	// Call the original TerrainTile info
	Out = VS_TerrainTile( Position_BlendWeight1, Normal_BlendWeight2, BaseTexCoord,	BlendTex1Coord, BlendTex2Coord, Tangent, Binormal, isTextureAtlasEnabled);

    return Out;
}

#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM)

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainScorch(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_unpack : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
    float4 Tangent_unpack : TANGENT,
    float4 Binormal_unpack : BINORMAL
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

	// Unpack vertex data
	float3 Normal = (Normal_unpack.xyz * 255 / 100.0) - 1.0;
	float3 Tangent = (Tangent_unpack.xyz * 255 / 100.0) - 1.0;
	float3 Binormal = (Tangent_unpack.xyz * 255 / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to VS_Default
    return VS_Default(Position, Normal, Color, BaseTexCoord, Tangent, Binormal, RenderingMode_Scorch, false);
}

// ---------------------------------------------------------------------------
#if defined(EA_PLATFORM_PS3)
float4 PS_Default_PS3(VSOutputDefault In, uniform int renderingMode,
    uniform sampler2D baseSampler, uniform sampler2D normalSampler,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC )
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, In.WorldPosition.xyz, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(In.WorldPosition.xyz);

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
        float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
        float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

        baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }
    
	float3 baseColor = GammaToLinear(baseTextureValue.xyz);

	float3 color = In.Color.xyz;
	float opacity = In.Color.w;

	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	// Add normal mapping lighting with main light source
	float3 normal;
	float specularIntensity;
	
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		float4 normal_specular = tex2D(normalSampler, BaseTexCoord);
		
		normal = normal_specular.xyz * 2 - 1;
		specularIntensity = normal_specular.w;
	}
	else
	{
		float3 normal_specular = tex2D(normalSampler, BaseTexCoord).xyz;

        if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
        {
            float3 normal_specular1 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.xy).xyz;
            float3 normal_specular2 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.wz).xyz;

			specularIntensity = baseTextureValue.w;
            normal = lerp(lerp(normal_specular, normal_specular1, blendWeight[0]), normal_specular2, blendWeight[1]) * 2 - 1;
        }
		else
		{
			specularIntensity = normal_specular.z;
			normal.xy = normal_specular.xy * 2 - 1;
			normal.z = sqrt(1 - normal.x * normal.x - normal.y * normal.y);
		}
	}
	
	normal.xy *= BumpScale;
	normal = normalize(normal);

	if (!EnableNormalMap)
		normal = float3(0, 0, 1);
		
	// Compute point lights
#if !defined(EA_PLATFORM_PS3)
	for (int i = 0; i < NumPointLights; i++)
	{
		color += CalculatePointLightDiffuse(PointLight[i], In.WorldPosition, normal);
	}
#endif

	// Apply texture color
	// Note: we need to divide by 2 in VS and restore it in PS since COLOR register is clamped to 1
	color *= HDRColorRange * baseColor;

	float3 mainLightColor = DirectionalLight[0].Color;
	float4 lighting = lit(dot(normal, In.MainLightDirection_Falloff.xyz), dot(normal, In.MainHalfEyeLightDirection), SpecularExponent);

#if 0 // Disable shadow for now.
	if (hasShadow)
	{
		if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
		{
			lighting.yz *= shadow_PerspectiveCorrect( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
		else
		{
			lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
 	}
#endif

#if 0 // Disable for now.
	float3 cloud = GammaToLinear(tex2D( SAMPLER(CloudSampler), CloudTexCoord));
	color += mainLightColor * cloud * (lighting.y * baseColor + lighting.z * SpecularColor * specularIntensity);
#endif

#if SUPPORT_SSAO
	color *= ComputeSSAO(vPos);
#endif

#if 0 // Disable for now.
    // Apply macro
	float3 macro = GammaToLinear(tex2D( SAMPLER(MacroSampler), MacroTexCoord));
    color *= macro;

    // Apply fog
	color = lerp(Fog.Color, color, In.Fog);
#endif

    // Apply shroud
    float2 shroudTexCoord = In.ShroudTexCoord;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	baseColor *= shroud;

#if 0 // Disable for now.
	return float4(color, opacity);
#else
	return float4(baseColor, 1);
#endif
}

float4 PS_Default_PS3_Terrain(VSOutputDefault In, uniform int renderingMode,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC ) : COLOR
{
    // $note (WSK) : these are temporarily methods (hopefully) to pass the right parameters in since RNAFxCompiler doesn't seem to recognize 
    //               the uniform arguments specified in technique
    return PS_Default_PS3(In, RenderingMode_TerrainTile, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), true, true, vPos);
}

float4 PS_Default_PS3_Road(VSOutputDefault In, uniform int renderingMode,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC ) : COLOR
{
    // $note (WSK) : these are temporarily methods (hopefully) to pass the right parameters in since RNAFxCompiler doesn't seem to recognize 
    //               the uniform arguments specified in technique
    return PS_Default_PS3(In, RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), true, true, vPos);
}

float4 PS_Default_PS3_Scorch(VSOutputDefault In, uniform int renderingMode,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC ) : COLOR
{
    // $note (WSK) : these are temporarily methods (hopefully) to pass the right parameters in since RNAFxCompiler doesn't seem to recognize 
    //               the uniform arguments specified in technique
    return PS_Default_PS3(In, RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), true, true, vPos);
}

float4 PS_Default_PS3_Cliff(VSOutputDefault In, uniform int renderingMode,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC ) : COLOR
{
    // $note (WSK) : these are temporarily methods (hopefully) to pass the right parameters in since RNAFxCompiler doesn't seem to recognize 
    //               the uniform arguments specified in technique
    return PS_Default_PS3(In, RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), true, true, vPos);
}

#else

float4 PS_Default(VSOutputDefault In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform sampler2D normalSampler,
	uniform bool hasShadow, uniform bool isTextureAtlasEnabled,
	float2 vPos : PIXELLOC ) COLORTARGET
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, In.WorldPosition.xyz, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(In.WorldPosition.xyz);


    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
        float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
        float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

        baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }
    
	float3 baseColor = GammaToLinear(baseTextureValue.xyz);

	float3 color = In.Color.xyz;
	float opacity = In.Color.w;

	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	// Add normal mapping lighting with main light source
	float3 normal;
	float specularIntensity;
	
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		float4 normal_specular = tex2D(normalSampler, BaseTexCoord);
		
		normal = normal_specular * 2 - 1;

		if (renderingMode == RenderingMode_Scorch)
			specularIntensity = 0;
		else
			specularIntensity = normal_specular.w;
	}
	else
	{
		float3 normal_specular = tex2D(normalSampler, BaseTexCoord);

        if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
        {
            float3 normal_specular1 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
            float3 normal_specular2 = tex2D(normalSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

			specularIntensity = baseTextureValue.w;
            normal = lerp(lerp(normal_specular, normal_specular1, blendWeight[0]), normal_specular2, blendWeight[1]) * 2 - 1;
        }
		else
		{
			specularIntensity = normal_specular.z;
			normal.xy = normal_specular.xy * 2 - 1;
			normal.z = sqrt(1 - normal.x * normal.x - normal.y * normal.y);
		}
	}
	
	normal.xy *= BumpScale;
	normal = normalize(normal);

	if (!EnableNormalMap)
		normal = float3(0, 0, 1);
		
	// Compute point lights
#if !defined(EA_PLATFORM_PS3)
	for (int i = 0; i < NumPointLights; i++)
	{
		color += CalculatePointLightDiffuse(PointLight[i], In.WorldPosition, normal);
	}
#endif

	// Apply texture color
	// Note: we need to divide by 2 in VS and restore it in PS since COLOR register is clamped to 1
	color *= HDRColorRange * baseColor;

	float3 mainLightColor = DirectionalLight[0].Color;
	float4 lighting = lit(dot(normal, In.MainLightDirection_Falloff.xyz), dot(normal, In.MainHalfEyeLightDirection), SpecularExponent);

	if (hasShadow)
	{
		if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
		{
			lighting.yz *= shadow_PerspectiveCorrect( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
		else
		{
			lighting.yz *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
 	}

	float3 cloud = GammaToLinear(tex2D( SAMPLER(CloudSampler), CloudTexCoord));
	color += mainLightColor * cloud * (lighting.y * baseColor + lighting.z * SpecularColor * specularIntensity);

#if SUPPORT_SSAO
	color *= ComputeSSAO(vPos);
#endif

    // Apply macro
	float3 macro = GammaToLinear(tex2D( SAMPLER(MacroSampler), MacroTexCoord));
    color *= macro;

    // Apply fog
	color = lerp(Fog.Color, color, In.Fog);

    // Apply shroud
    float2 shroudTexCoord = In.ShroudTexCoord;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color *= shroud;
	
	return float4(color, opacity);
}

float4 PS_Default_Xenon(VSOutputDefault In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform sampler2D normalSampler, float2 vPos : PIXELLOC ) : COLOR
{
	return PS_Default(In, renderingMode, baseSampler, normalSampler, 1, true, vPos);
}
#endif // EA_PLATFORM_WINDOWS || EA_PLATFORM_XENON

// ---------------------------------------------------------------------------
// TECHNIQUE : TerrainTile ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_Multiplier_IsTextureAtlasEnabled = 1);

#define VS_TerrainTile_IsTextureAtlasEnabled \
 	compile VS_3_0 VS_TerrainTile(false), \
	compile VS_3_0 VS_TerrainTile(true)

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_Multiplier_Final = VS_TerrainTile_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_TerrainTile_Array[VS_TerrainTile_Multiplier_Final] =
{
	VS_TerrainTile_IsTextureAtlasEnabled
};
#endif


DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_NumShadows = 1);

#define PS_TerrainTile_NumShadows(isTextureAtlasEnabled) \
	compile PS_3_0 PS_Default(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 0, isTextureAtlasEnabled), \
	compile PS_3_0 PS_Default(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 1, isTextureAtlasEnabled)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_IsTextureAtlasEnabled = PS_TerrainTile_Multiplier_NumShadows * 2);

#define PS_TerrainTile_IsTextureAtlasEnabled \
	PS_TerrainTile_NumShadows(false), \
	PS_TerrainTile_NumShadows(true)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_Final = PS_TerrainTile_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_TerrainTile_Array[PS_TerrainTile_Multiplier_Final] =
{
	PS_TerrainTile_IsTextureAtlasEnabled
};
#endif


// ---------------------------------------------------------------------------
technique TerrainTile
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
#if defined(TERRAIN_USE_MULTIPLE_STREAM)
	        compile VS_VERSION VS_TerrainTileVFetch(true)
#else
  			compile VS_VERSION VS_TerrainTile(true)
#endif
		);
		
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_Array,
			HasShadow * PS_TerrainTile_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
			compile PS_VERSION PS_Default_Xenon(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);
#else // EA_PLATFORM_PS3
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_Array,
			HasShadow * PS_TerrainTile_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
			compile PS_VERSION PS_Default_PS3_Terrain()
		);
#endif

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_Multiplier_NumShadows = 1);

#define PS_Cliff_NumShadows \
	compile PS_3_0 PS_Default(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 0, false), \
	compile PS_3_0 PS_Default(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 1, false)
	
DEFINE_ARRAY_MULTIPLIER(PS_Cliff_Multiplier_Final = PS_Cliff_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Cliff_Array[PS_Cliff_Multiplier_Final] =
{
	PS_Cliff_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Cliff
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default(RenderingMode_Cliff, false);
		
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_Array,
			HasShadow * PS_Cliff_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_Xenon(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);
#else
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_Array,
			HasShadow * PS_Cliff_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_PS3_Cliff()
		);
#endif

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Road ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Road_Multiplier_NumShadows = 1);

#define PS_Road_NumShadows \
	compile PS_3_0 PS_Default(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 0, false), \
	compile PS_3_0 PS_Default(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped), 1, false)

DEFINE_ARRAY_MULTIPLIER(PS_Road_Multiplier_Final = PS_Road_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Road_Array[PS_Road_Multiplier_Final] =
{
	PS_Road_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Road
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_Default(RenderingMode_Road, false);
		
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_Array,
			HasShadow * PS_Road_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_Xenon(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), SAMPLER(NormalSamplerWrapped))
		);
#else
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_Array,
			HasShadow * PS_Road_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_PS3_Road()
		);
#endif

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
		
		DepthBias = ROAD_Z_BIAS;
	}
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch ( HIGH QUALITY )
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_Multiplier_NumShadows = 1);

#define PS_Scorch_NumShadows \
	compile PS_3_0 PS_Default(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 0, false), \
	compile PS_3_0 PS_Default(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), 1, false)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_Multiplier_Final = PS_Scorch_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Scorch_Array[PS_Scorch_Multiplier_Final] =
{
	PS_Scorch_NumShadows
};
#endif

// ---------------------------------------------------------------------------
technique Scorch
{
	pass P0
	{
		VertexShader = compile VS_3_0 VS_TerrainScorch();
		
#if defined(EA_PLATFORM_WINDOWS) || defined(EA_PLATFORM_XENON)
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_Array,
			HasShadow * PS_Scorch_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_Xenon(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped))
		);
#else
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_Array,
			HasShadow * PS_Scorch_Multiplier_NumShadows,
			// Non-array alternative:
			compile PS_VERSION PS_Default_PS3_Scorch()
		);
#endif

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;
		
		AlphaTestEnable = false;
		
		DepthBias = SCORCHMARK_Z_BIAS;
	}
}




// LOD techniques follow
#if ENABLE_LOD

// ============================================================================
// Default technique, medium quality
// ============================================================================
// ---------------------------------------------------------------------------
struct VSOutput_M
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float4 MainLightContribution_Fog : COLOR1;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float2 ShroudTexCoord : TEXCOORD2;
    float4 CloudTexCoord_MacroTexCoord : TEXCOORD3;
	float4 ShadowMapTexCoord : TEXCOORD5;
};
	
// ---------------------------------------------------------------------------
VSOutput_M VS_Default_M(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform int renderingMode,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_M Out;
	
	Out.Position = mul(float4(Position, 1), GetViewProjection());
	float3 worldPosition = Position;

	Out.MainLightContribution_Fog.w = CalculateFog(Fog, worldPosition, GetEyePosition());

	float3 worldNormal = Normal;
	
	float3 mainLight = DirectionalLight[0].Color * max(0, dot(worldNormal, DirectionalLight[0].Direction));
	mainLight /= 2; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.
	Out.MainLightContribution_Fog.xyz = mainLight;

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	for (int i = 1; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;
	diffuseColor /= HDRColorRange; // Overbright rendering is already applied in the light color, however we want to do it later in the pixel shader.

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	float2 CloudTexCoord = CalculateCloudTexCoord(Cloud, worldPosition, Time);
	float2 MacroTexCoord = CalculateMacroTexCoord(worldPosition);

	Out.ShroudTexCoord = ShroudTexCoord;
    Out.CloudTexCoord_MacroTexCoord.xy = CloudTexCoord.xy;
    Out.CloudTexCoord_MacroTexCoord.zw = MacroTexCoord.yx;
    
	if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord_PerspectiveCorrect(worldPosition);
	}
	else
	{
		Out.ShadowMapTexCoord = CalculateShadowMapTexCoord(worldPosition);
	}

	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_M VS_TerrainTile_M(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_M Out;
	float3 Position	= Position_BlendWeight1.xyz;
	float3 Normal	= Normal_BlendWeight2.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

	if (isTextureAtlasEnabled)
	{
		// Unpack vertex data
		Normal = (Normal_BlendWeight2.xyz / 100.0) - 1.0;

		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default_M(Position, Normal, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, RenderingMode_TerrainTile, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_M VS_TerrainScorch_M(
    float4 Position_BlendWeight1 : POSITION, 
    float4 Normal_unpack : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float3 Normal = (Normal_unpack.xyz * 255 / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to DefaultVertexShader_M
    return VS_Default_M(Position, Normal, Color, BaseTexCoord, RenderingMode_Scorch, false);
}

// ---------------------------------------------------------------------------
float4 PS_Default_M(VSOutput_M In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform bool hasShadow,
	uniform bool isTextureAtlasEnabled) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

    // Doing first and second blend
    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
		float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
		float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);
		
		baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }

	float3 baseColor = baseTextureValue.xyz;

	float2 CloudTexCoord = In.CloudTexCoord_MacroTexCoord.xy;
	float3 cloud = GammaToLinear(tex2D(SAMPLER(CloudSampler), CloudTexCoord));
	float3 mainLight = In.MainLightContribution_Fog.xyz * cloud;

	if (hasShadow)
	{
		if(renderingMode == RenderingMode_Road || renderingMode == RenderingMode_TerrainTile && !isTextureAtlasEnabled)
		{
			mainLight *= shadow_PerspectiveCorrect( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
		else
		{
			mainLight *= shadow( SAMPLER(ShadowMap), In.ShadowMapTexCoord );
		}
	}

	float3 color = (In.Color.xyz + mainLight) * baseColor;
	color *= 2; // Overbrightening

    // Apply reflection or macro
	float2 MacroTexCoord = In.CloudTexCoord_MacroTexCoord.wz;
	float4 macro = tex2D( SAMPLER(MacroSampler), MacroTexCoord);

    // Apply macro
    color *= macro;

    // Apply fog
	color = lerp(Fog.Color, color, In.MainLightContribution_Fog.w);

    // Apply shroud
    float2 shroudTexCoord = In.ShroudTexCoord;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color *= shroud;

	// Calculate opacity
	float opacity = In.Color.w;
	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		opacity *= baseTextureValue.w;
	}

	return float4(color, opacity);
}


// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain Tile (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled = 1);

#define VS_TerrainTile_M_IsTextureAtlasEnabled \
 	compile VS_2_0 VS_TerrainTile_M(false), \
	compile VS_2_0 VS_TerrainTile_M(true)

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_Final = VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_TerrainTile_M_Array[VS_TerrainTile_M_Multiplier_Final] =
{
	VS_TerrainTile_M_IsTextureAtlasEnabled
};
#endif

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_NumShadows = 1);

#define PS_TerrainTile_M_NumShadows(isTextureAtlasEnabled) \
	compile PS_2_0 PS_Default_M(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), 0, isTextureAtlasEnabled), \
	compile PS_2_0 PS_Default_M(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped), 1, isTextureAtlasEnabled)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled = PS_TerrainTile_M_Multiplier_NumShadows * 2);

#define PS_TerrainTile_M_IsTextureAtlasEnabled \
	PS_TerrainTile_M_NumShadows(false), \
	PS_TerrainTile_M_NumShadows(true)

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_Final = PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_TerrainTile_M_Array[PS_TerrainTile_M_Multiplier_Final] =
{
	PS_TerrainTile_M_IsTextureAtlasEnabled
};
#endif

technique TerrainTile_M
{
	pass P0
	{
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_M_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled,
			NO_ARRAY_ALTERNATIVE
		);
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_M_Array,
			HasShadow * PS_TerrainTile_M_Multiplier_NumShadows
			+ IsTerrainAtlasEnabled * PS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled,
			NO_ARRAY_ALTERNATIVE
		);
		
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_NumShadows = 1);

#define PS_Cliff_M_NumShadows \
	compile PS_2_0 PS_Default_M(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), 0, false), \
	compile PS_2_0 PS_Default_M(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped), 1, false)

DEFINE_ARRAY_MULTIPLIER(PS_Cliff_M_Multiplier_Final = PS_Cliff_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Cliff_M_Array[PS_Cliff_M_Multiplier_Final] =
{
	PS_Cliff_M_NumShadows
};
#endif

technique Cliff_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_M(RenderingMode_Cliff, false);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Cliff_M_Array,
			HasShadow * PS_Cliff_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Road (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_NumShadows = 1);

#define PS_Road_M_NumShadows \
	compile PS_2_0 PS_Default_M(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), 0, false), \
	compile PS_2_0 PS_Default_M(RenderingMode_Road, SAMPLER(BaseSamplerWrapped), 1, false)

DEFINE_ARRAY_MULTIPLIER(PS_Road_M_Multiplier_Final = PS_Road_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Road_M_Array[PS_Road_M_Multiplier_Final] =
{
	PS_Road_M_NumShadows
};
#endif

technique Road_M
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_M(RenderingMode_Road, false);
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Road_M_Array,
			HasShadow * PS_Road_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
		
		DepthBias = ROAD_Z_BIAS;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Medium Quality)
// ---------------------------------------------------------------------------

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_NumShadows = 1);

#define PS_Scorch_M_NumShadows \
	compile PS_2_0 PS_Default_M(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), 0, false), \
	compile PS_2_0 PS_Default_M(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped), 1, false)

DEFINE_ARRAY_MULTIPLIER(PS_Scorch_M_Multiplier_Final = PS_Scorch_M_Multiplier_NumShadows * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_Scorch_M_Array[PS_Scorch_M_Multiplier_Final] =
{
	PS_Scorch_M_NumShadows
};
#endif

technique Scorch_M
{
	pass P0
	{
        VertexShader = compile VS_2_0 VS_TerrainScorch_M();
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_Scorch_M_Array,
			HasShadow * PS_Scorch_M_Multiplier_NumShadows,
			NO_ARRAY_ALTERNATIVE
		);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;

		DepthBias = SCORCHMARK_Z_BIAS;
	}
}






// ============================================================================
// Default technique, low quality
// ============================================================================
// ---------------------------------------------------------------------------
struct VSOutput_L
{
	float4 Position : POSITION;
 	float4 BaseTexCoord_BlendWeight : TEXCOORD0;
 	float4 BlendTex1Coord_BlendTex2Coord : TEXCOORD1;
    float2 ShroudTexCoord : TEXCOORD2;
	float4 Color : TEXCOORD3;
};
	
// ---------------------------------------------------------------------------
VSOutput_L VS_Default_L(
	float3 Position : POSITION, 
	float3 Normal : NORMAL,
	float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0,
	uniform int renderingMode,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_L Out;
	
	Out.Position = mul(float4(Position, 1), GetViewProjection());
	float3 worldPosition = Position;
	float3 worldNormal = Normal;

	// Do vertex lighting for light 1 to n
	float3 diffuseLight = 0;
	for (int i = 0; i < NumDirectionalLights; i++)
	{
		diffuseLight += DirectionalLight[i].Color * max(0, dot(worldNormal, DirectionalLight[i].Direction));
	}

	float3 diffuseColor = (AmbientLightColor + diffuseLight) * Color.xyz;

	Out.Color = float4(diffuseColor, Color.w);

    // Output texture information
    Out.BaseTexCoord_BlendWeight.xy = BaseTexCoord;

	// Initialize terrain tile only data
    Out.BaseTexCoord_BlendWeight.zw = float2(0, 0);
    Out.BlendTex1Coord_BlendTex2Coord = float4(0, 0, 0, 0);

	float2 ShroudTexCoord = CalculateShroudTexCoord(Shroud, worldPosition);
	Out.ShroudTexCoord = ShroudTexCoord;

	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_L VS_TerrainTile_L(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutput_L Out;
	float3 Position	= Position_BlendWeight1.xyz;
	float3 Normal	= Normal_BlendWeight2.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

	if (isTextureAtlasEnabled)
	{
		// Unpack vertex data
		Normal = (Normal_BlendWeight2.xyz / 100.0) - 1.0;

		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default_L(Position, Normal, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, RenderingMode_TerrainTile, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	return Out;
}

// ---------------------------------------------------------------------------
VSOutput_L VS_TerrainScorch_L(
    float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_unpack : NORMAL0,
    float4 Color : COLOR0, 
    float2 BaseTexCoord : TEXCOORD0
)
{
    VSOutputDefault Out;
    float3 Position = Position_BlendWeight1.xyz;

    // Unpack vertex data
    float3 Normal = (Normal_unpack.xyz * 255 / 100.0) - 1.0;

    BaseTexCoord   = (BaseTexCoord   / 30000.0);

    // Delegate main computations to DefaultVertexShader_L
    return VS_Default_L(Position, Normal, Color, BaseTexCoord, RenderingMode_Scorch, false);
}

// ---------------------------------------------------------------------------
float4 PS_Default_L(VSOutput_L In, uniform int renderingMode,
	uniform sampler2D baseSampler, uniform bool isTextureAtlasEnabled) : COLOR
{
    float2 BaseTexCoord = In.BaseTexCoord_BlendWeight.xy;
	float4 baseTextureValue = tex2D(baseSampler, BaseTexCoord);

    if(renderingMode == RenderingMode_TerrainTile && isTextureAtlasEnabled)
    {
		float4 texColor1 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.xy);
		float4 texColor2 = tex2D(baseSampler, In.BlendTex1Coord_BlendTex2Coord.wz);

		// Doing first and second blend
	    float2 blendWeight = saturate(In.BaseTexCoord_BlendWeight.wz);
		
		// This double lerp is expensive on low lod.
		baseTextureValue = lerp(lerp(baseTextureValue, texColor1, blendWeight[0]), texColor2, blendWeight[1]);
    }

	float4 color = In.Color;

	if (renderingMode == RenderingMode_Road || renderingMode == RenderingMode_Scorch)
	{
		color *= baseTextureValue;
	}
	else
	{
		color.xyz *= baseTextureValue.xyz;
	}

    // Apply shroud
    float2 shroudTexCoord = In.ShroudTexCoord;
	float shroud = tex2D( SAMPLER(ShroudSampler), shroudTexCoord).x;
	color.xyz *= shroud;

	return color;
}


// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain Tile (Low Quality)
// ---------------------------------------------------------------------------

technique TerrainTile_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_TerrainTile_L(true);		
		PixelShader = compile PS_2_0 PS_Default_L(RenderingMode_TerrainTile, SAMPLER(BaseSamplerClamped_L), true);
		
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Cliff (Low Quality)
// ---------------------------------------------------------------------------

technique Cliff_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_L(RenderingMode_Cliff, false);
		PixelShader = compile PS_2_0 PS_Default_L(RenderingMode_Cliff, SAMPLER(BaseSamplerWrapped_L), false);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Road (Low Quality)
// ---------------------------------------------------------------------------

technique Road_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_Default_L(RenderingMode_Road, false);
		PixelShader = compile PS_2_0 PS_Default_L(RenderingMode_Road, SAMPLER(BaseSamplerWrapped_L), false);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
		
		DepthBias = ROAD_Z_BIAS;
	}
}



// ---------------------------------------------------------------------------
// TECHNIQUE : Scorch (Low Quality)
// ---------------------------------------------------------------------------

technique Scorch_L
{
	pass P0
	{
        VertexShader = compile VS_2_0 VS_TerrainScorch_L();
		PixelShader = compile PS_2_0 PS_Default_L(RenderingMode_Scorch, SAMPLER(BaseSamplerClamped_L), false);

		ZEnable = true;
		ZWriteEnable = false;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;

		DepthBias = SCORCHMARK_Z_BIAS;
	}
}

#endif // #if ENABLE_LOD


// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
struct VSOutput_CreateShadowMap
{
	float4 Position : POSITION;
	float Depth : TEXCOORD0;
};

// ---------------------------------------------------------------------------
VSOutput_CreateShadowMap VS_CreateShadowMap(float3 Position : POSITION)
{
	VSOutput_CreateShadowMap Out;
	
	Out.Position = mul(float4(Position, 1), GetViewProjection());
	Out.Depth = Out.Position.z / Out.Position.w;
	
	return Out;
}

#if defined(TERRAIN_USE_MULTIPLE_STREAM)
// ---------------------------------------------------------------------------
VSOutput_CreateShadowMap VS_CreateShadowMapVFetch(int Index: INDEX)
{
	VSOutput_CreateShadowMap Out;

	// Fetch the vertex info from Terrain
	VSOutputDefault TerrainVertex = VS_TerrainTileVFetch(Index, true);
	Out.Position = TerrainVertex.Position;
	Out.Depth = Out.Position.z / Out.Position.w;
	
	return Out;
}
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM)

// ---------------------------------------------------------------------------
float4 PS_CreateShadowMap(VSOutput_CreateShadowMap In) : COLOR
{
	return In.Depth;
}

// ---------------------------------------------------------------------------
// TECHNIQUE: CreateShadowMap
// ---------------------------------------------------------------------------
technique _CreateShadowMap
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM)
		VertexShader = compile VS_2_0 VS_CreateShadowMapVFetch();
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM)
		VertexShader = compile VS_2_0 VS_CreateShadowMap();
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM)
		PixelShader = compile PS_2_0 PS_CreateShadowMap();
	
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;
		
	}
}


// ---------------------------------------------------------------------------
// TECHNIQUE: CreateDepthMap
// ---------------------------------------------------------------------------
technique _CreateDepthMap
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM)
		VertexShader = compile VS_2_0 VS_CreateShadowMapVFetch();
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM)
		VertexShader = compile VS_2_0 VS_CreateShadowMap();
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM)

#if defined(EA_PLATFORM_XENON)
		PixelShader = NULL;
#else
		PixelShader = compile PS_2_0 PS_CreateShadowMap();
#endif

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		
		AlphaTestEnable = false;
		
	}
}
