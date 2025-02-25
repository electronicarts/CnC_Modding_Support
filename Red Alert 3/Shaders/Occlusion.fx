//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for object occlusion coloring ("behind buildings marker")
//////////////////////////////////////////////////////////////////////////////

#include "Common.fxh"

// ----------------------------------------------------------------------------
// Constants
// ----------------------------------------------------------------------------
float4 FlatColor
<
	string UIWidget = "None";
	string SasBindAddress = "WW3D.FlatColor";
> = float4(0, 0, 0, 0);

// ----------------------------------------------------------------------------
// SHADER
// ----------------------------------------------------------------------------
float4 VS(float3 Position : POSITION) : POSITION
{
	return float4(Position, 1);
}

// ----------------------------------------------------------------------------
float4 PS(void) : COLOR
{
	return FlatColor;
}


// ----------------------------------------------------------------------------
// TECHNIQUE: _ClearStencil
// ----------------------------------------------------------------------------
technique _ClearStencil
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ColorWriteEnable = 0;//RED|GREEN|BLUE|ALPHA;
		
		ZEnable = true;
		ZFunc = Never; // Old code claims it's faster to use ZFail to fill the stencil buffer. Maybe
		
		ZWriteEnable = false;
		CullMode = None;
		
		StencilEnable = true;
		StencilFunc = Less;
		StencilPass = Replace;
		StencilZFail = Replace;
		StencilFail = Zero;
		StencilMask = 0; // To be overridden by code
		StencilWriteMask = 0; // To be overridden by code
		StencilRef = 0; // To be overridden by code
		
		AlphaBlendEnable = false;

		AlphaTestEnable = false;
	}  
}

// ----------------------------------------------------------------------------
// TECHNIQUE: _FillColor
// ----------------------------------------------------------------------------
technique _FillColor
{
	pass P0
	{
		VertexShader = compile VS_2_0 VS();
		PixelShader = compile PS_2_0 PS();

		ColorWriteEnable = RGBA;
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		StencilEnable = true;
		StencilFunc = Equal;
		StencilPass = Keep;
		StencilZFail = Keep;
		StencilFail = Keep;
		//StencilMask = 0; // To be overridden by code
		StencilWriteMask = 0xffffffff;
		//StencilRef = 0; // To be overridden by code
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}  
}
