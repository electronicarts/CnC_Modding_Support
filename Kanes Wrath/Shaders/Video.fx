//////////////////////////////////////////////////////////////////////////////
// ©2006 Electronic Arts Inc
//
// FX Shader for video decoding
//////////////////////////////////////////////////////////////////////////////


#include "Common.fxh"

// ----------------------------------------------------------------------------
// Textures declaration
// ----------------------------------------------------------------------------
SAMPLER_2D_BEGIN(FrameY,
	string SasBindAddress = "Video.FrameY";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(FrameU,
	string SasBindAddress = "Video.FrameU";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

SAMPLER_2D_BEGIN(FrameV,
	string SasBindAddress = "Video.FrameV";
	)
	AddressU = Clamp;
	AddressV = Clamp;
	MinFilter = Linear;
	MagFilter = Linear;
	MipFilter = Linear;
SAMPLER_2D_END

// ---------------------------------------------------------------------------

struct VSOutput
{
	float4 Position : POSITION;
	float4 Color : COLOR0;
	float2 TexCoordY : TEXCOORD0;
	float2 TexCoordU : TEXCOORD1;
	float2 TexCoordV : TEXCOORD2;
};

// ---------------------------------------------------------------------------

VSOutput VS(float2 Position : POSITION, float2 TexCoord0 : TEXCOORD0, float4 color : COLOR0 )
{
	VSOutput Out;
	
	Out.Position = float4((Position * 2 - 1) * float2(1, -1), 0, 1);
	Out.Color = color;

	float2 texCoord = TexCoord0;
	Out.TexCoordY = texCoord;
	Out.TexCoordU = texCoord;
	Out.TexCoordV = texCoord;
	
	return Out;
}


// ---------------------------------------------------------------------------
float4 PS(VSOutput In) : COLOR
{
	// Get vertex color
	float4 color = In.Color;

	float3x3 yuvToRgbMatrixT =
	{
		1.164383,  1.164383, 1.164383,
		       0, -0.391762, 2.017232,
		1.596027, -0.812968,        0
	};
	float3 bias = mul(float3(-16, -128, -128) / 255, yuvToRgbMatrixT);

	// Sample YUV components
	float3 yuv;
	yuv = tex2D(SAMPLER(FrameY), In.TexCoordY).xxx * yuvToRgbMatrixT[0];
	yuv += tex2D(SAMPLER(FrameU), In.TexCoordU).xxx * yuvToRgbMatrixT[1];
	yuv += tex2D(SAMPLER(FrameV), In.TexCoordV).xxx * yuvToRgbMatrixT[2];
	yuv += bias;

	color.rgb *= yuv;

	return color;
}

// ---------------------------------------------------------------------------

technique Default
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();
		PixelShader  = compile PS_VERSION_HIGH PS();
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}

#if ENABLE_LOD

technique Default_L
{
	pass P0
	{
		VertexShader = compile VS_VERSION_LOW VS();

		PixelShader  = asm 
		{
			ps_1_1
			// 'Original' YUV-to-RGB constants
            //def c0, 1.16438305, 1.16438305, 1.16438305, 0
            //def c1, 0, -0.391761988, 2.01723194, 0
            //def c2, 1.59602702, -0.812968016, 0, 0
            //def c3, -0.874202311, 0.531667888, -1.08563066, 0

			// Divided by two due to PS1.1 range issues:
            def c0, 0.582191527, 0.582191527, 0.582191527, 0
            def c1, 0, -0.195880994, 1, 0
            def c2, 0.798013508, -0.406484008, 0, 0
			def c3, -0.43710115, 0.26583395, -0.54281534, 0

			tex t0
			tex t1
			tex t2
            
			mad r0.xyz, t0, c0, c3
			mad r0.xyz, t1, c1, r0
			mad_x2 r0.xyz, t2, c2, r0

			mul r0.xyz, r0, v0
			+ mov r0.w, v0.w
		};

		Texture[0] = ( FrameY );
		AddressU[0] = Clamp; 
		AddressV[0] = Clamp; 
		MipFilter[0] = Linear;
	    MinFilter[0] = Linear;
	    MagFilter[0] = Linear;
			
		Texture[1] = ( FrameU );
		AddressU[1] = Clamp; 
		AddressV[1] = Clamp; 
		MipFilter[1] = Linear;
	    MinFilter[1] = Linear;
	    MagFilter[1] = Linear;

		Texture[2] = ( FrameV );
		AddressU[2] = Clamp; 
		AddressV[2] = Clamp; 
		MipFilter[2] = Linear;
	    MinFilter[2] = Linear;
	    MagFilter[2] = Linear;
		
		ZEnable = false;
		ZWriteEnable = false;
		CullMode = None;
		
		AlphaBlendEnable = true;
		SrcBlend = SrcAlpha;
		DestBlend = InvSrcAlpha;

		AlphaTestEnable = false;
	}
}
#endif