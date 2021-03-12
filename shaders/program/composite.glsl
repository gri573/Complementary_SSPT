/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 
//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform int frameCounter;
uniform int isEyeInWater;
uniform int worldTime;

uniform float blindFactor;
uniform float far, near;
uniform float frameTimeCounter;
uniform float rainStrengthS;
uniform float screenBrightness; 
uniform float timeAngle, timeBrightness, moonBrightness;
uniform float viewWidth, viewHeight, aspectRatio;
uniform float eyeAltitude;

uniform ivec2 eyeBrightnessSmooth;

uniform vec3 cameraPosition;
uniform vec3 fogColor;

uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform mat4 shadowModelView;
uniform mat4 shadowProjection;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex8;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

#if defined WATERMARK && WATERMARK_DURATION < 900
	uniform float starter;
#endif

#ifdef WATERMARK
	uniform sampler2D depthtex2;
#endif

#if defined LIGHT_SHAFTS && defined SHADOWS
	uniform sampler2DShadow shadowtex0;
	uniform sampler2DShadow shadowtex1;
	uniform sampler2D shadowcolor0;
#endif

#if ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING && defined END && END_SKY == 2) || (defined SMOKEY_WATER_LIGHTSHAFTS && defined LIGHT_SHAFTS)
	uniform float shadowFade;
	uniform sampler2D noisetex;
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	uniform float sunAngle;

	uniform vec3 skyColor;
#endif

#if NIGHT_VISION > 1 || ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING)
	uniform float nightVision;
#endif

#ifdef WEATHER_PERBIOME
	uniform float isDry, isRainy, isSnowy;
#endif

//Attributes//

//Optifine Constants//
const bool colortex2Clear = false;

//Common Variables//
float eBS = eyeBrightnessSmooth.y / 240.0;
float sunVisibility  = clamp(dot( sunVec,upVec) + 0.0625, 0.0, 0.125) * 8.0;
float vsBrightness = clamp(screenBrightness, 0.0, 1.0);

#if (defined LIGHT_SHAFTS && defined SHADOWS && defined SMOKEY_WATER_LIGHTSHAFTS) || ((defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING && defined END && END_SKY == 2)
		#if WORLD_TIME_ANIMATION >= 2
			float frametime = float(worldTime) * 0.05 * ANIMATION_SPEED;
		#else
			float frametime = frameTimeCounter * ANIMATION_SPEED;
		#endif
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	vec3 lightVec = sunVec * (1.0 - 2.0 * float(timeAngle > 0.5325 && timeAngle < 0.9675));
#endif

//Common Functions//
float GetLuminance(vec3 color){
	return dot(color,vec3(0.299, 0.587, 0.114));
}

float GetLinearDepth(float depth) {
   return (2.0 * near) / (far + near - depth * (far - near));
}

//Includes//
#include "/lib/color/waterColor.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/atmospherics/waterFog.glsl"
#include "/lib/color/dimensionColor.glsl"

#include "/lib/util/spaceConversion.glsl"

#if defined LIGHT_SHAFTS && defined SHADOWS
	#ifdef SMOKEY_WATER_LIGHTSHAFTS
		#include "/lib/lighting/caustics.glsl"
	#endif
	#include "/lib/atmospherics/volumetricLight.glsl"
#endif

#if (defined BLACK_OUTLINE || defined PROMO_OUTLINE) && defined OUTLINE_ON_EVERYTHING
	#ifdef OVERWORLD
		#include "/lib/color/skyColor.glsl"
		#include "/lib/atmospherics/sky.glsl"
	#endif
	#if defined END && END_SKY == 2
		#include "/lib/atmospherics/clouds.glsl"
	#endif

	#include "/lib/atmospherics/fog.glsl"
#endif

#if defined PROMO_OUTLINE && defined OUTLINE_ON_EVERYTHING
	#include "/lib/outline/promoOutline.glsl"
#endif

#if defined BLACK_OUTLINE && defined OUTLINE_ON_EVERYTHING
	#include "/lib/color/blocklightColor.glsl"
	#include "/lib/outline/blackOutline.glsl"
#endif

//Program//
void main(){
    vec4 color = texture2D(colortex0, texCoord.xy);
    vec3 translucent = texture2D(colortex1,texCoord.xy).rgb;
	float z0 = texture2D(depthtex0, texCoord.xy).r;
	float z1 = texture2D(depthtex1, texCoord.xy).r;
	float water = texture2D(colortex4,texCoord.xy).g;

	//if (water > 0.5 && isEyeInWater == 0) translucent.rgb = vec3(0.0);
    
	#if defined LIGHT_SHAFTS && defined SHADOWS
		float dither = Bayer64(gl_FragCoord.xy);
	#endif

	#if defined BLACK_OUTLINE && defined OUTLINE_ON_EVERYTHING
		float outlineMask = BlackOutlineMask(depthtex0, depthtex1);
		float wFogMult = 1.0 + eBS;
		if (outlineMask > 0.5 || isEyeInWater > 0.5)
			BlackOutline(color.rgb, depthtex0, wFogMult);
	#endif
	
	#if defined PROMO_OUTLINE && defined OUTLINE_ON_EVERYTHING
		if (z1 - z0 > 0.0) PromoOutline(color.rgb, depthtex0);
	#endif

	if (water > 0.5 && z1 == 1.0) {
		color.rgb *= 1.0;
	}

	if (isEyeInWater == 1.0 && z0 == 1.0) {
		color.rgb *= pow(rawWaterColor.rgb, vec3(0.5)) * 3;
		color.rgb = 0.8 * pow(rawWaterColor.rgb * (1.0 - blindFactor), vec3(2.0));
	}

	if (isEyeInWater == 2) color.rgb *= vec3(1.0, 0.25, 0.01);
	
	#if defined LIGHT_SHAFTS && defined SHADOWS
		vec3 vl = getVolumetricRays(z0, z1, translucent, dither);
	#else
		vec3 vl = vec3(0.0);
    #endif

	#if NIGHT_VISION > 1
		if (nightVision > 0.0) {
			float nightVisionGreen = length(color.rgb);
			nightVisionGreen = smoothstep(0.0, 1.0, nightVisionGreen) * 3.0 + 0.25 * sqrt(nightVisionGreen);
			float whiteFactor = 0.01;
			vec3 nightVisionFinal = vec3(nightVisionGreen * whiteFactor, nightVisionGreen, nightVisionGreen * whiteFactor);
			color.rgb = mix(color.rgb, nightVisionFinal, nightVision);
		}
	#endif

	#ifdef WATERMARK
		#if WATERMARK_DURATION < 900
			if (starter < 0.99) {
		#endif
				vec2 textCoord = vec2(texCoord.x, 1.0 - texCoord.y);
				vec4 compText = texture2D(depthtex2, textCoord);
				#if WATERMARK_DURATION < 900
					float starterFactor = 1.0 - 2.0 * abs(starter - 0.5);
					starterFactor = max(starterFactor - 0.333333, 0.0) * 3.0;
					starterFactor = smoothstep(0.0, 1.0, starterFactor);
				#else
					float starterFactor = 1.0;
				#endif
				color.rgb = mix(color.rgb, compText.rgb, compText.a * starterFactor);
		#if WATERMARK_DURATION < 900
			}
		#endif
	#endif
	
	//SSPT//
	
	float ddepth = 0;
	float dist = 0;
	float dnormal = 0;
	vec4 sspt = texture2D(colortex8,texCoord);
	vec2 newTexCoord = vec2(0.0);
	float varNormal = 0;
	if (texCoord.x < 0.5 && texCoord.y > 0.5) {
		vec2 texCoord2 = texCoord - vec2(0,0.5);
		vec2 texCoord3 = texCoord * 2 - vec2(0,1);
		vec3 avgNormal = vec3(0);
		float sumlNormal = 0.001;
		vec3 locNormal = vec3(0);
		float brightMul0 = 0;
		float brightMul = 0;
		for(int i = -3; i < 4; i++) {
			for(int j = -3; j < 4; j++) {
				locNormal = texture2D(colortex6, texCoord3 + vec2((20 * i + 5 * sin(frameTimeCounter * 150)) / viewWidth, (20 * j + 5 * sin(frameTimeCounter * 100))/ viewHeight)).rgb;
				avgNormal += locNormal;
				sumlNormal += length(locNormal);
			}
		}
		varNormal = 0.7 / (1.2 - pow(length(avgNormal) / sumlNormal, 2));
		for(int i = -3; i < 4; i++) {
			for(int j = -3; j < 4; j++) {
				newTexCoord = texCoord2 + vec2(varNormal * i / viewWidth, varNormal * j / viewHeight);
				newTexCoord = vec2(clamp(newTexCoord.x, 0, 0.5), clamp(newTexCoord.y, 0, 0.5));
				dist = length(texCoord2 - newTexCoord);
				dnormal =length(texture2D(colortex6,texCoord3).rgb - texture2D(colortex6,newTexCoord * 2).rgb);
				ddepth = abs(texture2D(depthtex0, texCoord3).r - texture2D(depthtex0, newTexCoord * 2).r);
				brightMul0 = 1 / pow(0.3 * ddepth + 10 * dist * dist + 3 * dnormal + 0.001, 2);
				brightMul += brightMul0;
				sspt.rgb += texture2D(colortex8, newTexCoord).rgb * brightMul0;
			}	
		}
		sspt.rgb /= 0.5 * brightMul;
	}
	//color.rgb = sspt.rgb;
    /*DRAWBUFFERS:018*/
	gl_FragData[0] = color;
	gl_FragData[1] = vec4(vl, 1.0);
	gl_FragData[2] = sspt;
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

varying vec3 sunVec, upVec;

//Uniforms//
uniform float timeAngle;

uniform mat4 gbufferModelView;

//Common Variables//
#ifdef OVERWORLD
	float timeAngleM = timeAngle;
#else
	#if !defined SEVEN && !defined SEVEN_2
		float timeAngleM = 0.25;
	#else
		float timeAngleM = 0.5;
	#endif
#endif

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();

	const vec2 sunRotationData = vec2(cos(sunPathRotation * 0.01745329251994), -sin(sunPathRotation * 0.01745329251994));
	float ang = fract(timeAngleM - 0.25);
	ang = (ang + (cos(ang * 3.14159265358979) * -0.5 + 0.5 - ang) / 3.0) * 6.28318530717959;
	sunVec = normalize((gbufferModelView * vec4(vec3(-sin(ang), cos(ang) * sunRotationData) * 2000.0, 1.0)).xyz);

	upVec = normalize(gbufferModelView[1].xyz);
}

#endif
