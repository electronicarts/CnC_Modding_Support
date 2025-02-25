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
                    string SasBindAddress = "Sas.AmbientLight";
                    string UIWidget = "None";,
					= float3(0.3, 0.3, 0.3));

	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT0_FIRST, 
					float4, DirectionalLight_0_Color,
                    string SasBindAddress = "Sas.DirectionalLight_0_Color";
                    string UIWidget = "None";,
					NO_INITIALIZER);
					
	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT0_LAST, 
					float4, DirectionalLight_0_Direction,
                    string SasBindAddress = "Sas.DirectionalLight_0_Direction";
                    string UIWidget = "None";,
					NO_INITIALIZER);
					
	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT1_FIRST, 
					float4, DirectionalLight_1_Color,
                    string SasBindAddress = "Sas.DirectionalLight_1_Color";
                    string UIWidget = "None";,
					NO_INITIALIZER);
					
	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT1_LAST, 
					float4, DirectionalLight_1_Direction,
                    string SasBindAddress = "Sas.DirectionalLight_1_Direction";
                    string UIWidget = "None";,
					NO_INITIALIZER);
					
	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT2_FIRST, 
					float4, DirectionalLight_2_Color,
                    string SasBindAddress = "Sas.DirectionalLight_2_Color";
                    string UIWidget = "None";,
					NO_INITIALIZER);
					
	REGISTER_BIND( REGISTER_DIRECTIONAL_LIGHT2_LAST, 
					float4, DirectionalLight_2_Direction,
                    string SasBindAddress = "Sas.DirectionalLight_2_Direction";
                    string UIWidget = "None";,
					NO_INITIALIZER);

#if defined(USE_INTERACTIVE_LIGHTS)
    DECLARE_DIRECTIONAL_LIGHT_INTERACTIVE(DirectionalLight_0);
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
	

    REGISTER_BIND_ARRAY(  REGISTER_POINT_LIGHTS_FIRST,
                    SasPointLight, PointLight, MaxNumPointLights,
                    string SasBindAddress = "Sas.PointLight";
                    string SasBindType = "Flat";	// make a flat array of vector constants
                	string UIWidget = "None"; ,
					NO_INITIALIZER)
#if defined(USE_INITIALIZERS)
	// This initializer is too complex to be part of the macro
    = 
    {
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED,
        DEFAULT_POINT_LIGHT_DISABLED
    }
#endif
	;

	#if defined(USE_POINTLIGHT_ATTENUATION_INFO)
		SasPointLightsAttenuationInfo PointLightsAttenuationInfo[MaxPointLightGroups]
		<
			string UIWidget = "None";
            string SasBindType = "Flat";	// make a flat array of vector constants
			string SasBindAddress = "Sas.PointLightsAttenuationInfo";
		>;
	#endif // #if defined(USE_POINTLIGHT_ATTENUATION_INFO)


#endif // #if define(USE_INDIRECT_CONSTANT) || SUPPORT_LOCAL_LIGHTS

//////////////////////////////////////////////////////////////////////////////
// Cloud
//////////////////////////////////////////////////////////////////////////////
#if defined(USE_INDIRECT_CONSTANT) || SUPPORT_CLOUDS

    REGISTER_BIND(  REGISTER_CLOUD_WORLDPOSITIONMULTIPLIER_XYZZ,
                    float4, Cloud_WorldPositionMultiplier_XYZZ,
                	string UIWidget = "None";
                    string SasBindAddress = "Terrain.Cloud.WorldPositionMultiplier_XYZZ"; ,
                    = DEFAULT_CLOUD);

    REGISTER_BIND(  REGISTER_CLOUD_CURRENTOFFSETUV,
                    float4, Cloud_CurrentOffsetUV,
                	string UIWidget = "None";
                    string SasBindAddress = "Terrain.Cloud.CurrentOffsetUV"; ,
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
	
		  // $todo (MD) -- Only using secondary house color, need to update code & shaders to remove unused 
		  //               RecolorColor
		float3 RecolorSecondaryColor
        <
	        string UIName = "Preview House Color";
	        string UIWidget = "Color";
	        bool ExportValue = false;
        > = float3(0, .59, .59);
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

		REGISTER_BIND(  REGISTER_RECOLOR_SECONDARY_COLOR,
                        float3, RecolorSecondaryColor,
	                    string UIWidget = "None";
	                    string SasBindAddress = "WW3D.RecolorSecondaryColor[0]";
	                    bool ExportValue = false; ,
                        = float3(1, 1, 0));

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

		REGISTER_BIND(  REGISTER_RECOLOR_SECONDARY_COLOR,
                        float3, RecolorSecondaryColorDummy,
	                    string UIWidget = "None";
	                    string SasBindAddress = "WW3D.RecolorSecondaryColor[0]";
	                    bool ExportValue = false; ,
                        = float3(1, 0, 0));
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

	// StealthEnabled cannot be an indirect constant on Windows, as it is used in array expressions.
	// Declare it regularly, just don't declare it at all outside the shaders
	#if defined(EA_PLATFORM_WINDOWS)
		#if !defined(__cplusplus)
			bool StealthEnabled
			<
				string UIWidget = "None";
				string SasBindAddress = "WW3D.StealthEnabled";
				bool ExportValue = false;
			> = false;
		#endif
	#else
        REGISTER_BIND_BOOL( BREGISTER_STEALTH_ENABLED,
                        bool, StealthEnabled,
	                    string UIWidget = "None";
	                    string SasBindAddress = "WW3D.StealthEnabled";
	                    bool ExportValue = false; ,
                        = false);
	#endif

	//RenderBuffEffectA Vector.
	//Similar to Stealth, RenderBuffEffect vectors cannot be an indirect constant on Windows, as it is used in array expressions.
	// Declare it regularly, just don't declare it at all outside the shaders
	#if defined(EA_PLATFORM_WINDOWS)
		#if !defined(__cplusplus)
			float4 RenderBuffEffectA
			<
				string UIWidget = "None";
				string SasBindAddress = "WW3D.RenderBuffEffectA";
				bool ExportValue = false;
			> = float4(0.0f,0.0f,0.0f,0.0f);
		#endif
	#else
		REGISTER_BIND(REGISTER_RENDERBUFFEFFECTA,
						float4, RenderBuffEffectA,
						string UIWidget = "None";
						string SasBindAddress = "WW3D.RenderBuffEffectA";
						bool ExportValue = false; ,
						= false);
	#endif
	
	//RenderBuffEffectB Vector.
	//Similar to Stealth, RenderBuffEffect vectors cannot be an indirect constant on Windows, as it is used in array expressions.
	// Declare it regularly, just don't declare it at all outside the shaders
	#if defined(EA_PLATFORM_WINDOWS)
		#if !defined(__cplusplus)
			float4 RenderBuffEffectB
			<
				string UIWidget = "None";
				string SasBindAddress = "WW3D.RenderBuffEffectB";
				bool ExportValue = false;
			> = float4(0.0f,0.0f,0.0f,0.0f);
		#endif
	#else
		REGISTER_BIND(REGISTER_RENDERBUFFEFFECTB,
						float4, RenderBuffEffectB,
						string UIWidget = "None";
						string SasBindAddress = "WW3D.RenderBuffEffectB";
						bool ExportValue = false; ,
						= false);
	#endif

   //flash
   REGISTER_BIND( REGISTER_FLASHPCT,
						float, FlashPct,
						string UIWidget = "None";
						string SasBindAddress = "WW3D.FlashPct"; ,
						 = 1.0f ); 

	//HouseColor Bloom Intensity
	REGISTER_BIND( REGISTER_HOUSECOLORBLOOMINTENSITY,
						float4, HouseColorBloomIntensity,
						string UIWidget = "None";
						string SasBindAddress = "WW3D.HouseColorBloomIntensity"; ,
						= float4(1.0,1.0,1.0,1.0) );



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
     
#if !defined(__cplusplus)               
	float4x3		World : World : REGISTER_EVAL_VS(REGISTER_NON_SKINNING_WORLD_MATRIX_FIRST);
#endif

#else // #if define(USE_INDIRECT_CONSTANT)

#if !defined(__cplusplus)               
	float4x3		World : World;
#endif
	
#endif



//////////////////////////////////////////////////////////////////////////////
// These are the indirect constant that don't have to be defined, as every draw call will re-apply them anyway
//////////////////////////////////////////////////////////////////////////////
#if defined(USE_INDIRECT_CONSTANT) && !defined(NO_SKINNING_MATRICES)
	// Bone transformations 
	REGISTER_BIND_ARRAY_VS(REGISTER_SKINNING_BONE_TRANSFORMS,
                    float4, WorldBones, MaxSkinningBones * NUM_CONSTANTS_PER_BONE,
	                string UIWidget = "None";
	                string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]"; ,
                    NO_INITIALIZER);
#endif

// $todo (WSK) - seperate this out of GlobalParameters_ps3.fxh to make this more clean
#if defined(EA_PLATFORM_PS3)
    float4 WorldBones[MaxSkinningBones*NUM_CONSTANTS_PER_BONE] : C[REGISTER_SKINNING_BONE_TRANSFORMS]
    <
		bool unmanaged = true; 
        string UIWidget = "None";
        string SasBindAddress = "Sas.Skeleton.MeshToJointToWorld[*]";
    >;

	float2 VertexCorners[MAX_VERTICES_PER_PARTICLE]  : C[REGISTER_VERTEXCORNERS_FIRST]
	<
		bool unmanaged = true; 
        string UIWidget = "None";
    >;

	float4 RandomValues[MAX_RANDOM_VALUES] : C[REGISTER_RANDOM_FIRST]
	<
		bool unmanaged = true; 
        string UIWidget = "None";
	>;

    float4 Draw_VideoTex_NumPerRow_LastFrame_SingleRow_isRand : C[REGISTER_PARTICLEDRAW_VIDEOTEX_LAYOUT]
    <
		bool unmanaged = true; 
	    string UIWidget = "None";
	    string SasBindAddress = "Particle.Draw.VideoTex_NumPerRow_LastFrame_SingleRow_isRand";
    >;

    float4 Draw_ColorAnimationFunctions[(PARTICLE_COLOR_ANIMATION_MAX_KEYFRAMES - 1) * 2] : C[REGISTER_PARTICLEDRAW_COLOR_ANIMATION_FIRST]
    <
		bool unmanaged = true; 
        string UIWidget = "None";
        string SasBindType = "Flat";	// make a flat array of vector constants
        string SasBindAddress = "Particle.Draw.ColorAnimationFunctions";
    >;

    float4 Draw_TimeKeys : C[REGISTER_PARTICLEDRAW_TIMEKEYS]
    <
		bool unmanaged = true; 
	    string UIWidget = "None";
	    string SasBindAddress = "Particle.Draw.TimeKeys";
    >;

    float Draw_SpeedMultiplier : C[REGISTER_PARTICLEDRAW_SPEEDMULTIPLIER]
    <
		bool unmanaged = true; 
	    string UIWidget = "None";
	    string SasBindAddress = "Particle.Draw.SpeedMultiplier";
    >;

    float2 Draw_ColorScaleRange : C[REGISTER_PARTICLEDRAW_COLORSCALERANGE]
    <
		bool unmanaged = true; 
	    string UIWidget = "None";
	    string SasBindAddress = "Particle.Draw.ColorScaleRange";
    >;

#endif // #if defined(EA_PLATFORM_PS3)

#endif // #define _GLOBALLIGHTING_FXH_
