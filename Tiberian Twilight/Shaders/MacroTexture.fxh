//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// A simple include file that has everything needed to use the macro texture.
//////////////////////////////////////////////////////////////////////////////

float2 MapCellSize
<
	string UIWidget = "None";
	string SasBindAddress = "Terrain.Map.CellSize";
> = float2(10.0f, 10.0f);

SAMPLER_2D_BEGIN( MacroSampler,
	string UIWidget = "None";
	string SasBindAddress = "Terrain.MacroTexture";
	string ResourceName = "ShaderPreviewMacro.dds";
	)
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
	AddressU = Wrap;
	AddressV = Wrap;
SAMPLER_2D_END


// ----------------------------------------------------------------------------
float2 CalculateMacroTexCoord(float3 worldPosition)
{
	float cloudAndMacroScale = 1.0 / (66.0 * MapCellSize.x);
	return worldPosition.xy * float2(cloudAndMacroScale, -cloudAndMacroScale);
}
