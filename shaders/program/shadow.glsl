/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying float mat;

varying vec2 texCoord, lmCoord;

varying vec4 color;
varying vec4 position;

//Uniforms//
uniform int isEyeInWater;
uniform int blockEntityId;

uniform vec3 cameraPosition;

uniform sampler2D tex;
uniform sampler2D noisetex;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
uniform int worldTime;
#else
uniform float frameTimeCounter;
#endif

#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//

//Common Functions//
void doWaterShadowCaustics(inout vec4 albedo) {
	#if defined WATER_CAUSTICS && defined OVERWORLD && defined LIGHTSHAFT_WATER_CAUSTICS
		vec3 worldPos = position.xyz + cameraPosition.xyz;
		worldPos *= 0.5;
		float noise = 0.0;
		float mult = 0.5;
		
		vec2 wind = vec2(frametime) * 0.3; //speed
		float verticalOffset = worldPos.y * 0.2;

		if (mult > 0.01) {
			float lacunarity = 1.0 / 750.0, persistance = 1.0, weight = 0.0;

			mult *= (lmCoord.y*0.9 + 0.1);

			for(int i = 0; i < 8; i++){
				float windSign = mod(i,2) * 2.0 - 1.0;
				vec2 noiseCoord = worldPos.xz + wind * windSign - verticalOffset;
				if (i < 7) noise += texture2D(noisetex, noiseCoord * lacunarity).r * persistance;
				else {
					noise += texture2D(noisetex, noiseCoord * lacunarity * 0.125).r * persistance * 10.0;
					noise = -noise;
					float noisePlus = 1.0 + 0.125 * -noise;
					noisePlus *= noisePlus;
					noisePlus *= noisePlus;
					noise *= noisePlus;
				}

				if (i == 0) noise = -noise;

				weight += persistance;
				lacunarity *= 1.50;
				persistance *= 0.60;
			}
			noise *= mult / weight;
		}
		#ifndef SHADOW_COLOR
			float discardFactor = 0.025; //0.025
			if (noise > discardFactor || noise < -discardFactor) discard;
		#else
			albedo.rgb = sqrt(albedo.rgb);
			float noiseFactor = 1.1 + noise;
			noiseFactor = pow(noiseFactor, 10.0);
			albedo.rgb *= noiseFactor;
		#endif
	#else
		discard;
	#endif
}

//Program//
void main() {
    #if MC_VERSION >= 11300
		if (blockEntityId == 138) discard;
	#endif

	#if defined WRONG_MIPMAP_FIX
  		vec4 albedo = texture2DLod(tex, texCoord.xy, 0.0);
	#else
		vec4 albedo = texture2D(tex, texCoord.xy);
	#endif

	#ifndef SHADOW_COLOR
		if (albedo.a < 0.0001) discard;
	#endif

	albedo.rgb *= color.rgb;

    float premult = float(mat > 0.95 && mat < 1.05);
	float water = float(mat > 1.95 && mat < 2.05);
	float ice = float(mat > 2.95 && mat < 3.05);

	#ifdef NO_FOLIAGE_SHADOWS
		if (mat > 3.95 && mat < 4.05) discard;
	#endif

    #ifdef SHADOW_COLOR
		if (water > 0.5) {
			if (isEyeInWater < 0.5) { 
				albedo = vec4(0.0, 0.0, 0.0, 1.0);
			} else {
				albedo.rgb *= 1.5;
				doWaterShadowCaustics(albedo);
			}
		} else { //non-water
			albedo.rgb = mix(vec3(1.0), albedo.rgb, pow(albedo.a, (1.0 - albedo.a) * 0.5) * 1.05);
			albedo.rgb *= 1.0 - pow(albedo.a, 64.0);
		}
		if (ice > 0.5) {
			if (isEyeInWater < 0.5) {
				albedo.rgb *= albedo.rgb * albedo.rgb;
			} else {
				discard;
			}
		}
	#else
		if (water > 0.5) {
			if (isEyeInWater < 0.5) { 
				
			} else {
				doWaterShadowCaustics(albedo);
			}
		}
		if (premult > 0.5) {
			if (albedo.a < 0.51) discard;
		}
	#endif

	gl_FragData[0] = clamp(albedo, vec4(0.0), vec4(1.0));
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying float mat;

varying vec2 texCoord, lmCoord;

varying vec4 color;
varying vec4 position;

//Uniforms//
#if WORLD_TIME_ANIMATION >= 2
uniform int worldTime;
#else
uniform float frameTimeCounter;
#endif

uniform vec3 cameraPosition;

uniform mat4 gbufferModelView, gbufferModelViewInverse;
uniform mat4 shadowProjection, shadowProjectionInverse;
uniform mat4 shadowModelView, shadowModelViewInverse;

//Attributes//
attribute vec4 mc_Entity;
attribute vec4 mc_midTexCoord;

//Common Variables//
#if WORLD_TIME_ANIMATION >= 2
float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
#else
float frametime = frameTimeCounter * ANIMATION_SPEED;
#endif

//Includes//
#include "/lib/vertex/waving.glsl"

#ifdef WORLD_CURVATURE
#include "/lib/vertex/worldCurvature.glsl"
#endif

//Program//
void main() {
	texCoord = gl_MultiTexCoord0.xy;
	color = gl_Color;
	
	lmCoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
	lmCoord = clamp((lmCoord - 0.03125) * 1.06667, 0.0, 1.0);
	
	position = shadowModelViewInverse * shadowProjectionInverse * ftransform();

	mat = 0;
	if (mc_Entity.x == 79) mat = 1; //premult
	if (mc_Entity.x == 7979) mat = 3; //ice
	if (mc_Entity.x == 8) {  //water
		#ifdef WATER_DISPLACEMENT
			position.y += WavingWater(position.xyz);
		#endif
		mat = 2;
	}
	#ifdef NO_FOLIAGE_SHADOWS
		if (mc_Entity.x == 31 || mc_Entity.x == 6 || mc_Entity.x == 59 || mc_Entity.x == 175 || mc_Entity.x == 176 || mc_Entity.x == 104 || mc_Entity.x == 105 || mc_Entity.x == 83 || mc_Entity.x == 10600 || mc_Entity.x == 11100)
		mat = 4;
	#endif
	
	float istopv = gl_MultiTexCoord0.t < mc_midTexCoord.t ? 1.0 : 0.0;
	position.xyz += WavingBlocks(position.xyz, istopv);

	#ifdef WORLD_CURVATURE
		position.y -= WorldCurvature(position.xz);
	#endif
	
	gl_Position = shadowProjection * shadowModelView * position;

	float dist = sqrt(gl_Position.x * gl_Position.x + gl_Position.y * gl_Position.y);
	float distortFactor = dist * shadowMapBias + (1.0 - shadowMapBias);
	
	gl_Position.xy *= 1.0 / distortFactor;
	gl_Position.z = gl_Position.z * 0.2;
}

#endif