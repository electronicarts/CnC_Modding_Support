//////////////////////////////////////////////////////////////////////////////
// ©2005 Electronic Arts Inc
//
// Terrain Tile FX Shader
//////////////////////////////////////////////////////////////////////////////

#define TERRAIN_TILE

#if defined(EA_PLATFORM_XENON)
	#define TERRAIN_USE_MULTIPLE_STREAM_VFETCH
#endif

#if defined(EA_PLATFORM_PS3)
	#define TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY
#endif // #if defined(EA_PLATFORM_PS3)

#include "Terrain.fxh"

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

const float4 BLENDWEIGHT_LUT_FREQUENCY[13] =
{
	// Normal
	{  1.0,  1.0,  1.0,  1.0, },  	// BLENDTYPE_NONE							
	{  1.0,  1.0,  2.0,  2.0, },  	// BLENDTYPE_HORIZONTAL,
	{  2.0,  2.0,  1.0,  1.0, },  	// BLENDTYPE_HORIZONTAL_INVERTED,
	{  1.0,  2.0,  1.0,  2.0, },  	// BLENDTYPE_VERTICAL,
	{  2.0,  1.0,  2.0,  1.0, },  	// BLENDTYPE_VERTICAL_INVERTED,
	{  0.0,  1.0,  1.0,  2.0, },  	// BLENDTYPE_RIGHTDIAGONAL,
	{  1.0,  0.0,  2.0,  1.0, },  	// BLENDTYPE_RIGHTDIAGONAL_INVERTED,
	{  1.0,  2.0,  2.0,  3.0, },  	// BLENDTYPE_RIGHTDIAGONAL_LONG,
	{  2.0,  1.0,  3.0,  2.0, },  	// BLENDTYPE_RIGHTDIAGONAL_LONG_INVERTED,
	{  1.0,  2.0,  0.0,  1.0, },  	// BLENDTYPE_LEFTDIAGONAL,
	{  2.0,  1.0,  1.0,  0.0, },  	// BLENDTYPE_LEFTDIAGONAL_INVERTED,
	{  2.0,  3.0,  1.0,  2.0, },  	// BLENDTYPE_LEFTDIAGONAL_LONG,
	{  3.0,  2.0,  2.0,  1.0, },  	// BLENDTYPE_LEFTDIAGONAL_LONG_INVERTED,
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

// Each tile (pixel of 256*256) is split into 8 cells, and 2048 is our altas size. We could consider uploading 1/texture size in the multiplier and use 0, 1 and -1 only in the LUT.
static const float UV_OFFSET_PER_CELL=((256.0/8.0)/2048.0)*30000.0;

float2 AtlasUVOffsetMultiplier
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.AtlasUVOffsetMultiplier";
> = float2(1.0f, 1.0f);

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

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainTile(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
	float3 Position	= Position_BlendWeight1.xyz;
    float BlendWeight1 = 0.0;
    float BlendWeight2 = 0.0;

	if (isTextureAtlasEnabled)
	{
		BaseTexCoord   = (BaseTexCoord   / 30000.0);
		BlendTex1Coord = (BlendTex1Coord / 30000.0);
		BlendTex2Coord = (BlendTex2Coord / 30000.0);
	    BlendWeight1 = Position_BlendWeight1.w - 1.0;
	    BlendWeight2 = Normal_BlendWeight2.w - 1.0;
	}

	// Delegate main computations to VS_Default
	Out = VS_Default(Position, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}

	float2 ScorchMarkTexCoord = saturate((Position.xy - ScorchMarkUVOffsetMultiplier.xy)*ScorchMarkUVOffsetMultiplier.zw);
	ScorchMarkTexCoord.y = 1.0f - ScorchMarkTexCoord.y;
	Out.MacroTexCoord_ScorchMarkTexCoord.zw = ScorchMarkTexCoord;
	
	return Out;
}

#if defined(TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY)

// $Todo (WSK) - need to find ways to deal with this, ideally, we just want to return BLENDWEIGHT_LUT_FREQUENCY[blendType][vertexIndex]
// ---------------------------------------------------------------------------
float GetBlendWeight(float blendType, float vertexIndex)
{
	float4 Blends = BLENDWEIGHT_LUT_FREQUENCY[blendType];
	if(vertexIndex > 2.5)
	{
		return Blends.w;
	}
	else if (vertexIndex > 1.5)
	{
		return Blends.z;
	}
	else if (vertexIndex > 0.5)
	{
		return Blends.y;
	}
	else
	{
		return Blends.x;
	}
}

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainTileFrequency(
	float4 Position_BlendWeight1 : POSITION, 
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BaseTexCoord : TEXCOORD0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2,
    float2 BlendWeights : TEXCOORD3,
    float2 ColRowIndex : TEXCOORD4
)
{
	VSOutputDefault Out;

	float vertexIndex = 2.0 * ((Position_BlendWeight1.x - TileOrigin.x) / MapCellSize.x - ColRowIndex.x ) + ( (Position_BlendWeight1.y - TileOrigin.y) / MapCellSize.y - ColRowIndex.y );

	Position_BlendWeight1.w	= GetBlendWeight(BlendWeights.x, vertexIndex);
	Normal_BlendWeight2.w	= GetBlendWeight(BlendWeights.y, vertexIndex);

	float2 uvOffset;
	uvOffset.x			= floor(vertexIndex * 0.5);
	uvOffset.y			= 1.0 - fmod(vertexIndex, 2.0);
	uvOffset 			*= UV_OFFSET_PER_CELL * AtlasUVOffsetMultiplier;
	BaseTexCoord.xy		+= uvOffset.xy;
	BlendTex1Coord.xy	+= uvOffset.xy;
	BlendTex2Coord.xy	+= uvOffset.xy;
	
	// Call the original TerrainTile info
	Out = VS_TerrainTile( Position_BlendWeight1, Normal_BlendWeight2, BaseTexCoord,	BlendTex1Coord, BlendTex2Coord, true);

    return Out;
}
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY)

#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)

// ---------------------------------------------------------------------------
VSOutputDefault VS_TerrainTileVFetch(
    int Index : INDEX,
	uniform bool isTextureAtlasEnabled
)
{
	VSOutputDefault Out;
    float4 BaseTexCoord;
    float4 BlendTex1Coord;
    float4 BlendTex2Coord;

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
	float2 uvOffset		= AtlasUVOffsetMultiplier * TERRAIN_CORNER_INDEX_OFFSET_LUT[IsFlipped][vertexIndex].zw;
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
	Out = VS_TerrainTile( Position_BlendWeight1, Normal_BlendWeight2, BaseTexCoord,	BlendTex1Coord, BlendTex2Coord, isTextureAtlasEnabled);

    return Out;
}

// ---------------------------------------------------------------------------

VSOutput_CreateShadowMap VS_CreateShadowMapVFetch(int Index: INDEX)
{
	// Fetch the vertex info from Terrain
	VSOutputDefault TerrainVertex = VS_TerrainTileVFetch(Index, true);
	return VS_CreateShadowMap(TerrainVertex.Position);
}

// ---------------------------------------------------------------------------

VSOutput_CreateDepthNormalMap VS_CreateDepthNormalMapVFetch(int Index: INDEX)
{
    float4 BaseTexCoord;
    float4 BlendTex1Coord;
    float4 BlendTex2Coord;

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
	float2 uvOffset		= AtlasUVOffsetMultiplier * TERRAIN_CORNER_INDEX_OFFSET_LUT[IsFlipped][vertexIndex].zw;
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

	return VS_CreateDepthNormalMap( Position_BlendWeight1, BaseTexCoord, Normal_BlendWeight2
#if !defined(TERRAIN_ROAD)
	, BlendTex1Coord, BlendTex2Coord
#endif
	);
}

#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)

SAMPLER_2D_BEGIN( ScorchMark,
	string SasBindAddress = "WW3D.EXScorch01";
	)
	MinFilter = MinFilterBest;
	MagFilter = MagFilterBest;
	MipFilter = Linear;
	AddressU = Clamp;
	AddressV = Clamp;
SAMPLER_2D_END

// ---------------------------------------------------------------------------
float4 PS_Default_Terrain(VSOutputDefault In, float2 vPos : PIXELLOC ) : COLOR
{
    return PS_Default(In, SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), true, SCORCHMARK_TEXTURE_ENABLED, vPos);
}

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


DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_IsTextureAtlasEnabled = 1);

#define PS_TerrainTile_IsTextureAtlasEnabled \
 	compile PS_3_0 PS_Default(SAMPLER(BaseSamplerClamped), SAMPLER(NormalSamplerClamped), false, SCORCHMARK_TEXTURE_ENABLED), \
	compile PS_3_0 PS_Default_Terrain()

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_Multiplier_Final = PS_TerrainTile_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
pixelshader PS_TerrainTile_Array[PS_TerrainTile_Multiplier_Final] =
{
	PS_TerrainTile_IsTextureAtlasEnabled
};
#endif

// ---------------------------------------------------------------------------
technique Default
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY)
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
  			compile VS_VERSION VS_TerrainTileFrequency()
		);
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY)
		VertexShader = ARRAY_EXPRESSION_DIRECT_VS(VS_TerrainTile_Array,
			IsTerrainAtlasEnabled * VS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
	        compile VS_VERSION VS_TerrainTileVFetch(true)
#else
  			compile VS_VERSION VS_TerrainTile(true)
#endif
		);
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_FREQUENCY)
		
		PixelShader = ARRAY_EXPRESSION_DIRECT_PS(PS_TerrainTile_Array,
			IsTerrainAtlasEnabled * PS_TerrainTile_Multiplier_IsTextureAtlasEnabled,
			// Non-array alternative:
			compile PS_VERSION PS_Default_Terrain()
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

VSOutput_CreateDepthNormalMap VS_CreateDepthNormalMap(
	float4 Position_BlendWeight1 : POSITION, 
    float2 BaseTexCoord : TEXCOORD0,
	float4 Normal_BlendWeight2 : NORMAL0,
    float2 BlendTex1Coord : TEXCOORD1,
    float2 BlendTex2Coord : TEXCOORD2
	)
{
	VSOutput_CreateDepthNormalMap Out;
	
	VSOutputDefault OutDefault;
	OutDefault = VS_TerrainTile(Position_BlendWeight1, Normal_BlendWeight2,	BaseTexCoord, BlendTex1Coord, BlendTex2Coord, true);

    Out.BaseTexCoord_BlendWeight		= OutDefault.BaseTexCoord_BlendWeight;
	Out.BlendTex1Coord_BlendTex2Coord	= OutDefault.BlendTex1Coord_BlendTex2Coord;
	Out.Position						= OutDefault.Position;
	Out.Normal							= (Normal_BlendWeight2.xyz / 100.0) - 1.0;
	Out.Tangent							= cross(Out.Normal, float3(-1, 0, 0));
	Out.Binormal						= cross(Out.Normal, float3(0, 1, 0));

#if !defined(EA_PLATFORM_XENON)
	Out.Depth							= Out.Position.z / Out.Position.w;
#endif	

	return Out;
}

// ---------------------------------------------------------------------------

#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
VSOutput_CreateDepthNormalMap VS_CreateDepthNormalMapVFetch(int Index: INDEX);
#endif

// ---------------------------------------------------------------------------
// TECHNIQUE: CreateDepthNormalMap
// ---------------------------------------------------------------------------
technique _CreateDepthNormalMap
{
	pass P0
	{
#if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_3_0 VS_CreateDepthNormalMapVFetch();
#else // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)
		VertexShader = compile VS_3_0 VS_CreateDepthNormalMap();
#endif // #if defined(TERRAIN_USE_MULTIPLE_STREAM_VFETCH)

		PixelShader = compile PS_3_0 PS_CreateDepthNormalMap();

		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

// ---------------------------------------------------------------------------

// LOD techniques follow
#if ENABLE_LOD

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
	Out = VS_Default_M(Position, Normal, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}
	
	Out.ScorchMarkTexCoord.xy = saturate((Position.xy - ScorchMarkUVOffsetMultiplier.xy)*ScorchMarkUVOffsetMultiplier.zw);
	Out.ScorchMarkTexCoord.y = 1.0 - Out.ScorchMarkTexCoord.y;

	return Out;
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain Tile (Medium Quality)
// ---------------------------------------------------------------------------
DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled = 1);

#define VS_TerrainTile_M_IsTextureAtlasEnabled \
 	compile VS_3_0 VS_TerrainTile_M(false), \
	compile VS_3_0 VS_TerrainTile_M(true)

DEFINE_ARRAY_MULTIPLIER(VS_TerrainTile_M_Multiplier_Final = VS_TerrainTile_M_Multiplier_IsTextureAtlasEnabled * 2);

#if SUPPORTS_SHADER_ARRAYS
vertexshader VS_TerrainTile_M_Array[VS_TerrainTile_M_Multiplier_Final] =
{
	VS_TerrainTile_M_IsTextureAtlasEnabled
};
#endif

DEFINE_ARRAY_MULTIPLIER(PS_TerrainTile_M_Multiplier_NumShadows = 1);

#define PS_TerrainTile_M_NumShadows(isTextureAtlasEnabled) \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerClamped), 0, isTextureAtlasEnabled, SCORCHMARK_TEXTURE_ENABLED), \
	compile PS_3_0 PS_Default_M(SAMPLER(BaseSamplerClamped), 1, isTextureAtlasEnabled, SCORCHMARK_TEXTURE_ENABLED)

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

// ---------------------------------------------------------------------------
technique Default_M
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
	Out = VS_Default_L(Position, Normal, float4(1.0, 1.0, 1.0, 1.0), BaseTexCoord, isTextureAtlasEnabled);
	
	if (isTextureAtlasEnabled)
	{
    	// Note: intentionally switch 1 and 2
    	Out.BaseTexCoord_BlendWeight.z  = BlendWeight2;
    	Out.BaseTexCoord_BlendWeight.w  = BlendWeight1;
    	Out.BlendTex1Coord_BlendTex2Coord.xy = BlendTex1Coord.xy;
    	Out.BlendTex1Coord_BlendTex2Coord.zw = BlendTex2Coord.yx;
	}

	float2 ScorchMarkTexCoord; 
	ScorchMarkTexCoord.xy = saturate((Position.xy - ScorchMarkUVOffsetMultiplier.xy)*ScorchMarkUVOffsetMultiplier.zw);
	ScorchMarkTexCoord.y = 1.0 - ScorchMarkTexCoord.y;

	Out.ShroudTexCoord_ScorchMarkTexCoord.zw = ScorchMarkTexCoord;
	
	return Out;
}

// ---------------------------------------------------------------------------
// TECHNIQUE : Terrain Tile (Low Quality)
// ---------------------------------------------------------------------------
technique Default_L
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS_TerrainTile_L(true);		
		PixelShader = compile PS_2_0 PS_Default_L(SAMPLER(BaseSamplerClamped_L), true, SCORCHMARK_TEXTURE_ENABLED);
		
		ZEnable = true;
		ZWriteEnable = true;
		ZFunc = ZFUNC_INFRONT;
		CullMode = CW;

		AlphaBlendEnable = false;
		AlphaTestEnable = false;
	}
}

#endif // #if ENABLE_LOD
