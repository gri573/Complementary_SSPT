/* 
BSL Shaders v7.1.05 by Capt Tatsu, Complementary Shaders by EminGT
*/ 

#include "/lib/util/reprojection.glsl"

vec2 neighbourhoodOffsets[8] = vec2[8](
							   	   vec2(-1.0, -1.0),
							  	   vec2( 0.0, -1.0),
							  	   vec2( 1.0, -1.0),
							  	   vec2(-1.0,  0.0),
							   	   vec2( 1.0,  0.0),
							  	   vec2(-1.0,  1.0),
							  	   vec2( 0.0,  1.0),
							  	   vec2( 1.0,  1.0)
						  );

vec3 NeighbourhoodClamping(vec3 color, vec3 tempColor, vec2 view){
	vec3 minclr = color, maxclr = color;

	for(int i = 0; i < 8; i++){
		vec2 offset = neighbourhoodOffsets[i] * view;
		vec3 clr = texture2DLod(colortex1, texCoord + offset, 0.0).rgb;
		minclr = min(minclr, clr); maxclr = max(maxclr, clr);
	}

	return clamp(tempColor, minclr, maxclr);
}

void TAA(inout vec3 color, inout vec4 temp){
	vec3 coord = vec3(texCoord, texture2DLod(depthtex1, texCoord, 0.0).r);
	vec2 prvCoord = Reprojection(coord);
	
	vec2 view = vec2(viewWidth, viewHeight);
	vec3 tempColor = texture2DLod(colortex2, prvCoord, 0).gba;
	tempColor = NeighbourhoodClamping(color, tempColor, 1.0 / view);
	
	vec2 velocity = (texCoord - prvCoord.xy) * view;
	float blendFactor = float(prvCoord.x > 0.0 && prvCoord.x < 1.0 &&
	                          prvCoord.y > 0.0 && prvCoord.y < 1.0);
	blendFactor *= exp(-length(velocity)) * 0.3 + 0.6;
	
	color = mix(color, tempColor, blendFactor);
	temp = vec4(temp.r, color);
}