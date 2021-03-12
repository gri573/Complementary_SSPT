/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

//Settings//
#include "/lib/settings.glsl"

//Fragment Shader///////////////////////////////////////////////////////////////////////////////////
#ifdef FSH

//Varyings//
varying vec2 texCoord;

//Uniforms//
uniform sampler2D colortex1;

uniform float viewWidth, viewHeight;

#ifdef THE_FORBIDDEN_OPTION
	uniform float frameTimeCounter;
#endif

#ifdef GRAY_START
	uniform float starter;
#endif

uniform int worldTime; 
uniform float sunAngle;

//Optifine Constants//
/*
const int colortex0Format = R11F_G11F_B10F; //main
const int colortex1Format = RGB8; 			//raw translucent & bloom
const int colortex2Format = RGBA16;		    //temporal stuff
const int colortex3Format = RGB8; 			//*specular & skymapMod
const int gaux1Format = R8; 				//half-res ao
const int gaux2Format = RGBA8;			    //reflection
const int gaux3Format = RGB16; 				//*normals & material format
const int gaux4Format = RGB8; 				//*specular highlight
const int colortex8Format = RGBA16;			//sspt
const int colortex9Format = RGBA16;			//sspt filter
*/

const bool shadowHardwareFiltering = true;

const int noiseTextureResolution = 512;

const float drynessHalflife = 300.0;
const float wetnessHalflife = 300.0;

//Common Functions//
#if SHARPEN > 0
	vec2 sharpenOffsets[4] = vec2[4](
		vec2( 1.0,  0.0),
		vec2( 0.0,  1.0),
		vec2(-1.0,  0.0),
		vec2( 0.0, -1.0)
	);

	void SharpenFilter(inout vec3 color, vec2 texCoord2){
		float mult = SHARPEN * 0.025;
		vec2 view = 1.0 / vec2(viewWidth, viewHeight);

		color *= SHARPEN * 0.1 + 1.0;

		for(int i = 0; i < 4; i++){
			vec2 offset = sharpenOffsets[i] * view;
			color -= texture2D(colortex1, texCoord2 + offset).rgb * mult;
		}
	}
#endif

#ifdef GRAY_START
	float GetLuminance(vec3 color){
		return dot(color, vec3(0.299, 0.587, 0.114));
	}
#endif

//Program//
void main() {
	#ifndef OVERDRAW
		vec2 texCoord2 = texCoord;
	#else
		vec2 texCoord2 = (texCoord - vec2(0.5)) * (2.0 / 3.0) + vec2(0.5);
	#endif
	
	/*
	vec2 wh = vec2(viewWidth, viewHeight);
	wh /= 32.0;
	texCoord2 = floor(texCoord2 * wh) / wh;
	*/
	
	vec3 color = texture2D(colortex1, texCoord2).rgb;

	#if SHARPEN > 0
		SharpenFilter(color, texCoord2);
	#endif
	
	#ifdef THE_FORBIDDEN_OPTION
		float fractTime = fract(frameTimeCounter*0.01);
		color = pow(vec3(1.0) - color, vec3(5.0));
		color = vec3(color.r + color.g + color.b)*0.5;
		color.g = 0.0;
		if (fractTime < 0.5)  color.b *= fractTime, color.r *= 0.5 - fractTime;
		if (fractTime >= 0.5) color.b *= 1 - fractTime, color.r *= fractTime - 0.5;
		color = pow(color, vec3(1.8))*8;
	#endif

	#ifdef GRAY_START
		float animation = min(starter, 0.1) * 10.0;
		vec3 grayStart = vec3(GetLuminance(color.rgb));
		color.rgb = mix(grayStart, color.rgb, animation);
	#endif

	/*
	if (texCoord.x < 0.5) {
		float worldTimeM = worldTime;
		if (worldTime > 23214) worldTimeM = (worldTime - 23214) / 23214.0;
		if (worldTime < 23214) worldTimeM = (worldTime + 786) / 24000.0;
		color.rgb = vec3(worldTimeM);
	} else {
		color.rgb = vec3(sunAngle);
	}
	//color.rgb = vec3(float(color.r < 1.0 - 0.9999));
	*/

	gl_FragColor = vec4(color, 1.0);
}

#endif

//Vertex Shader/////////////////////////////////////////////////////////////////////////////////////
#ifdef VSH

//Varyings//
varying vec2 texCoord;

//Program//
void main(){
	texCoord = gl_MultiTexCoord0.xy;
	
	gl_Position = ftransform();
}

#endif
