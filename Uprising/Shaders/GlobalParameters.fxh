//////////////////////////////////////////////////////////////////////////////
// ©2008 Electronic Arts Inc
//
// Global parameters
//////////////////////////////////////////////////////////////////////////////

#ifndef _GLOBALLIGHTING_FXH_
#define _GLOBALLIGHTING_FXH_

// Use these defines to indicate whether features are needed for the specific shaders
// #define SUPPORT_GLOBAL_LIGHTS 1
// #define SUPPORT_LOCAL_LIGHTS 1

#include "RegisterMap.fxh"

//////////////////////////////////////////////////////////////////////////////
// Global Light - Ambient and Directional Light
//////////////////////////////////////////////////////////////////////////////
#if defined(USE_INDIRECT_CONSTANT) || SUPPORT_GLOBAL_LIGHTS

    // Ambient light
    REGISTER_BIND(  REGISTER_AMBIENT_LIGHT_COLOR,
                    float3, AmbientLightColor,
                    string SasBindAddress = "Sas.AmbientLight[0].Color";
                    string UIWidget = "None";,
					= float3(0.3, 0.3, 0.3));

    // Directional Light
    #define NumDirectionalLights	3

    REGISTER_BIND_ARRAY(  REGISTER_DIRECTIONAL_LIGHTS_FIRST,
                    SasDirectionalLight, DirectionalLight, NumDirectionalLights, 
                    string SasBindAddress = "Sas.DirectionalLight[*]";
                    string UIWidget = "None"; ,
					NO_INITIALIZER)
#if defined(USE_INITIALIZERS) && !defined(EA_PLATFORM_PS3)		// Crashes 'sce-cgc' if initialized
	// This initializer is too complex to be part of the macro
    = 
    {
        {
	        DEFAULT_DIRECTIONAL_LIGHT_1,
	        DEFAULT_DIRECTIONAL_LIGHT_2,
	        DEFAULT_DIRECTIONAL_LIGHT_3
        }
    }
#endif
	;

#if defined(USE_INTERACTIVE_LIGHTS)
    DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight, 0);
#endif

#endif // #if define(USE_INDIRECT_CONSTANT) || SUPPORT_GLOBAL_LIGHTS

//////////////////////////////////////////////////////////////////////////////
// Local Light - Point Light
//////////////////////////////////////////////////////////////////////////////

#if defined(USE_INDIRECT_CONSTANT) || SUPPORT_LOCAL_LIGHTS

	#if defined(EA_PLATFORM_WINDOWS)
		#if SUPPORT_LOCAL_LIGHTS
			// Don't make NumPointLights into an indirect constant on windows as it is 
			// sometimes used in integer and sometimes in float registers 
			// and the D3DX skipConstants code does not understand dual register bindings
				int NumPointLights
				<
					string SasBindAddress = "Sas.NumPointLights";
					string UIWidget = "None";
				> = 0;
		#endif
	#else
		// Point Light
		REGISTER_BIND_INT( IREGISTER_NUM_POINT_LIGHTS,
						int, NumPointLights,
						string SasBindAddress = "Sas.NumPointLights";
						string UIWidget = "None"; ,
						= 0);
	#endif

    // Default MaxNumPointLights to 8 unless the shader specifed it
    #if !defined(MaxNumPointLights)
        #define MaxNumPointLights 8
    #endif // #if !defined(MaxNumPointLights)

    REGISTER_BIND_ARRAY(  REGISTER_POINT_LIGHTS_FIRST,
                    SasPointLight, PointLight, MaxNumPointLights,
                    string SasBindAddress = "Sas.PointLight[*]";
                	string UIWidget = "None"; ,
					NO_INITIALIZER);

#endif // #if define(USE_INDIRECT_CONSTANT) || SUPPORT_LOCAL_LIGHTS

//////////////////////////////////////////////////////////////////////////////
// Cloud
//////////////////////////////////////////////////////////////////////////////
#if defined(USE_INDIRECT_CONSTANT) || SUPPORT_CLOUDS

    REGISTER_BIND(  REGISTER_CLOUD_SETUP,
                    CloudSetup, Cloud,
                	string UIWidget = "None";
                    string SasBindAddress = "Terrain.Cloud"; ,
                    = DEFAULT_CLOUD);

    // Cloud information for NoCloudMultiplier
    REGISTER_BIND(  REGISTER_NO_CLOUD_MULTIPLIER,
                    float3, NoCloudMultiplier,
                	string UIWidget = "None";
                	string SasBindAddress = "Terrain.Cloud.NoCloudMultiplier"; ,
                    = float3(1, 1, 1));

#endif // #if define(USE_INDIRECT_CONSTANT) || SUPPORT_CLOUDS

//////////////////////////////////////////////////////////////////////////////
// Recolor
//////////////////////////////////////////////////////////////////////////////
#if SUPPORT_RECOLORING || defined(__cplusplus)
    #if defined(_3DSMAX_)
        bool HasRecolorColors
        <
	        string UIName = "Preview House Color Enable";
	        bool ExportValue = false;
        > = false;

        float3 RecolorColor
        <
	        string UIName = "Preview House Color";
	        string UIWidget = "Color";
	        bool ExportValue = false;
        > = float3(.7, .05, .05);
    #else // #if defined(_3DSMAX_)

	// HasRecolorColors cannot be an indirect constant on Windows, as it is used in array expressions.
	// Declare it regularly, just don't declare it at all outside the shaders
	#if defined(EA_PLATFORM_WINDOWS)
		#if !defined(__cplusplus)
			bool HasRecolorColors
			<
				string UIWidget = "None";
				string SasBindAddress = "WW3D.HasRecolorColors";
				bool ExportValue = false;
			> = false;
		#endif
	#else
        REGISTER_BIND_BOOL( BREGISTER_HAS_RECOLOR_COLORS,
                        bool, HasRecolorColors,
	                    string UIWidget = "None";
	                    string SasBindAddress = "WW3D.HasRecolorColors";
	                    bool ExportValue = false; ,
                        = false);
	#endif

        REGISTER_BIND(  REGISTER_RECOLOR_COLOR,
                        float3, RecolorColor,
	                    string UIWidget = "None";
	                    string SasBindAddress = "WW3D.RecolorColor[0]";
	                    bool ExportValue = false; ,
                        = float3(0, 0, 0));
    #endif // #if defined(_3DSMAX_)
#else // #if SUPPORT_RECOLORING
	// Special case when SUPPORT_RECOLORING is not supported, we want to make these static const to optimize the shader better
	static const bool HasRecolorColors = false;
	static const float3 RecolorColor = float3(0, 0, 0);

    // Need to declare these dummy variables to block the registers
    #if defined(USE_INDIRECT_CONSTANT)
		#if !defined(EA_PLATFORM_WINDOWS)
        REGISTER_BIND_BOOL(  BREGISTER_HAS_RECOLOR_COLORS,
                        bool, HasRecolorColorsDummy,
                        string UIWidget = "None";
                        string SasBindAddress = "WW3D.HasRecolorColors";
                        bool ExportValue = false; ,
                        = 0);
		#endif

        REGISTER_BIND(  REGISTER_RECOLOR_COLOR,
                        float3, RecolorColorDummy,
                        string UIWidget = "None";
                        string SasBindAddress = "WW3D.RecolorColor[0]";
                        bool ExportValue = false; ,
                        = float3(0, 0, 0));
    #endif // #if defined(USE_INDIRECT_CONSTANT)
#endif // #if SUPPORT_RECOLORING

//////////////////////////////////////////////////////////////////////////////
// These are the indirect constant that need to be declare across all shaders
//////////////////////////////////////////////////////////////////////////////

#if defined(USE_INDIRECT_CONSTANT) && !defined(EA_PLATFORM_WINDOWS)
    // Indicate whether shadow is turn on for the pass
    REGISTER_BIND_BOOL( BREGISTER_HAS_SHADOW,
                    bool, HasShadow,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.HasShadow"; ,
					= false);
#endif

#if defined(USE_INDIRECT_CONSTANT)

    // Shadowmap transformation matrix
    REGISTER_BIND(  REGISTER_MAT_WORLD_TO_SHADOW,
                    float4x4, ShadowMapWorldToShadow,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.Shadow[0].WorldToShadow"; ,
                    NO_INITIALIZER);
    // Color Information
    REGISTER_BIND(  REGISTER_OPACITY_OVERRIDE,
                    float, OpacityOverride,
                	string UIWidget = "None";
                	string SasBindAddress = "WW3D.OpacityOverride"; ,
                    = 1.0);

    REGISTER_BIND(  REGISTER_TINT_COLOR,
                    float3, TintColor,
                	string UIWidget = "None";
                	string SasBindAddress = "WW3D.TintColor"; ,
                    = float3(1, 1, 1));

    // Camera related
    REGISTER_BIND(  REGISTER_CAMERA_POSITION,
                    float3, EyePosition,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.Camera.Position"; ,
                    NO_INITIALIZER);

    REGISTER_BIND(  REGISTER_VIEWPROJECTION_MATRIX_FIRST,
                    float4x4, ViewProjection,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.Camera.WorldToProjection"; ,
                    NO_INITIALIZER);

#endif // #if define(USE_INDIRECT_CONSTANT)

//////////////////////////////////////////////////////////////////////////////
// These are the indirect constant that don't have to be defined, as every draw call will re-apply them anyway
//////////////////////////////////////////////////////////////////////////////
#if defined(USE_INDIRECT_CONSTANT) && !defined(NO_SKINNING_MATRICES)
	// Bone transformations 
	REGISTER_BIND_ARRAY_VS(REGISTER_SKINNING_BONE_TRANSFORMS,
                    float4, WorldBones, MaxSkinningBones * 2,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]"; ,
                    NO_INITIALIZER);
#endif

#endif // #define _GLOBALLIGHTING_FXH_
