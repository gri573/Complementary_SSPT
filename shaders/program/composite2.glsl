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
uniform float viewWidth, viewHeight, aspectRatio;

uniform vec3 cameraPosition, previousCameraPosition;

uniform mat4 gbufferPreviousProjection, gbufferProjectionInverse;
uniform mat4 gbufferModelView, gbufferPreviousModelView, gbufferModelViewInverse;

uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex9;
uniform sampler2D depthtex0;
uniform sampler2D depthtex1;

//Common Functions//
vec3 MotionBlur(vec3 color, float z, float dither){
	
	float hand = float(z < 0.56);

	if (hand < 0.5){
		float mbwg = 0.0;
		vec2 doublePixel = 2.0 / vec2(viewWidth, viewHeight);
		vec3 mblur = vec3(0.0);
		
		vec4 currentPosition = vec4(texCoord, z, 1.0) * 2.0 - 1.0;
		
		vec4 viewPos = gbufferProjectionInverse * currentPosition;
		viewPos = gbufferModelViewInverse * viewPos;
		viewPos /= viewPos.w;
		
		vec3 cameraOffset = cameraPosition - previousCameraPosition;
		
		vec4 previousPosition = viewPos + vec4(cameraOffset, 0.0);
		previousPosition = gbufferPreviousModelView * previousPosition;
		previousPosition = gbufferPreviousProjection * previousPosition;
		previousPosition /= previousPosition.w;

		vec2 velocity = (currentPosition - previousPosition).xy;
		velocity = velocity / (1.0 + length(velocity)) * MOTION_BLUR_STRENGTH * 0.02;
		
		vec2 coord = texCoord.st - velocity * (3.5 + dither);
		for(int i = 0; i < 9; i++, coord += velocity){
			vec2 coordb = clamp(coord, doublePixel, 1.0 - doublePixel);
			mblur += texture2DLod(colortex0, coordb, 0.0).rgb;
			mbwg += 1.0;
		}
		mblur /= mbwg;

		return mblur;
	}
	else return color;
}


//Includes//
#include "/lib/util/dither.glsl"

//Program//
void main(){
    vec3 color = texture2D(colortex0,texCoord).rgb;
	
	#ifdef MOTION_BLUR
	float z = texture2D(depthtex1, texCoord.st).x;
	float dither = Bayer64(gl_FragCoord.xy);

	color = MotionBlur(color, z, dither);
	#endif
	
	//SSPT//
	
	float dist = 0;
	float dnormal = 0;
	float ddepth = 0;
	vec4 sspt = vec4(0);
	vec2 newTexCoord = vec2(0);
	for(int i = -3; i < 4; i++) {
		newTexCoord = texCoord + vec2(0, i / viewHeight);
		dist = i/2000;
		dnormal =length(texture2D(colortex6,texCoord).rgb - texture2D(colortex6, newTexCoord).rgb);
		ddepth = abs(texture2D(depthtex0, texCoord).r - texture2D(depthtex0, newTexCoord).r);
		sspt.rgb += texture2D(colortex9, newTexCoord).rgb * 0.0003 / (0.05 * ddepth + 20 * dist * dist + 3 * dnormal + 0.001);
	}
	sspt.r = pow(sspt.r,0.8);
	sspt.g = pow(sspt.g,0.8);
	sspt.b = pow(sspt.b,0.8);
	vec3 albedo = texture2D(colortex7, texCoord).rgb;
	//if (length(albedo) < 0.0001) {
	//	albedo = vec3(1);
	//}
	
	sspt.rgb *= vec3(0.1) * (1 - length(albedo)) + albedo;
	color += sspt.rgb;
	/*DRAWBUFFERS:0*/
	gl_FragData[0] = vec4(color,1.0);
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
