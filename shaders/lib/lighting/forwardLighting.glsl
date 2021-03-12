#if (defined OVERWORLD || defined END || defined SEVEN) && defined SHADOWS
	#include "/lib/lighting/shadows.glsl"

	vec3 DistortShadow(inout vec3 worldPos, float distortFactor){
		worldPos.xy /= distortFactor;
		worldPos.z *= 0.2;
		return worldPos * 0.5 + 0.5;
	}
#else
vec3 GetFakeShadow(float skyLight) {
	vec3 fakeShadow = vec3(0.0);

	#ifndef END
		if (isEyeInWater == 0) skyLight = pow(skyLight, 30.0);
		fakeShadow = vec3(skyLight);
	#else
		fakeShadow = vec3(0.0);
	#endif

	return fakeShadow;
}
#endif

void GetLighting(inout vec3 albedo, inout vec3 shadow, vec3 viewPos, float lViewPos, vec3 worldPos,
                 vec2 lightmap, float smoothLighting, float NdotL, float quarterNdotU,
                 float parallaxShadow, float emissive, float subsurface, float mat, float leaves, float scattering, float materialAO) {

	vec3 fullShadow = vec3(0.0);
	if (shadow == vec3(1.0)) fullShadow = vec3(1.0);
	float shadowMult = 1.0;
	float shadowTime = 1.0;
    #if defined OVERWORLD || defined END || defined SEVEN
		#ifdef SHADOWS
			vec3 shadowPos = ToShadow(worldPos);

			float distb = sqrt(shadowPos.x * shadowPos.x + shadowPos.y * shadowPos.y);
			float distortFactor = distb * shadowMapBias + (1.0 - shadowMapBias);
			shadowPos = DistortShadow(shadowPos, distortFactor);

			float doShadow = float(shadowPos.x > 0.0 && shadowPos.x < 1.0 &&
								shadowPos.y > 0.0 && shadowPos.y < 1.0);

			#if defined OVERWORLD || defined SEVEN
				#ifdef LIGHT_LEAK_FIX
					if (isEyeInWater == 0) doShadow *= float(lightmap.y > 0.001);
				#endif
			#endif
			
			if ((NdotL > 0.0 || subsurface + scattering > 0.001)) {
				if (doShadow > 0.5) {
					float NdotLm = NdotL * 0.99 + 0.01;

					float lWorldPos = length(worldPos.xyz);
					
					float biasFactor = sqrt(1.0 - NdotLm * NdotLm) / NdotLm;
					float distortBias = distortFactor * shadowDistance / 256.0;
					distortBias *= 8.0 * distortBias;
					
					float bias = (distortBias * biasFactor + lWorldPos * 0.005) / shadowMapResolution;
					float offset = 1.0 / shadowMapResolution;

					if (subsurface > 0.001) {
						bias = 0.0002;
						offset = 0.002;
					} else if (scattering > 0.001) {
						bias = 0.0002;
						offset = 0.004;
					}
					if (isEyeInWater == 1) offset *= 5.0;
					
					shadow = GetShadow(shadowPos, bias, offset);

				} else {
					#ifndef END
						shadow = vec3(lightmap.y);
					#else
						shadow = vec3(1.0);
					#endif
				}
			}
		#else
			shadow = GetFakeShadow(lightmap.y);
		#endif
		
		#if defined CLOUD_SHADOW && defined OVERWORLD
			float cloudSize = 0.000025; //0.00005
			vec2 wind = vec2(frametime, 0.0) * CLOUD_SPEED * 6.0;
			float cloudShadow = texture2D(noisetex, cloudSize * (wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow += texture2D(noisetex, cloudSize * (vec2(1000.0) + wind + (worldPos.xz + cameraPosition.xz))).r;
			cloudShadow = clamp(cloudShadow, 0.0, 1.0);
			cloudShadow *= cloudShadow;
			cloudShadow *= cloudShadow;
			//cloudShadow = cloudShadow * 0.5 + 0.5;
			shadow *= cloudShadow;
		#endif

		#ifdef ADVANCED_MATERIALS
			#ifdef SELF_SHADOW
				shadow *= parallaxShadow;
			#endif
		#endif

		if (leaves > 0.5) {
			subsurface *= SCATTERING_LEAVES;
		} else {
			subsurface *= SCATTERING_FOLIAGE;
			#ifndef SHADOWS
				subsurface *= subsurface;
			#endif
		}
		if (subsurface == 0.0) subsurface += scattering;
		#ifndef SHADOWS
			subsurface *= subsurface;
		#endif
		
		fullShadow = shadow * max(NdotL, subsurface * (1.0 - max(rainStrengthS, (1.0 - sunVisibility) * 0.5) * 0.80)) * (1.0 - fullShadow.r);
		
		#if defined OVERWORLD && !defined TWO
			shadowMult = 1.0 * (1.0 - 0.9 * rainStrengthS);
			
			#ifdef LIGHT_JUMPING_FIX
				shadowTime = abs(sunVisibility - 0.5) * 2.0;
				shadowTime *= shadowTime;
				shadowMult *= shadowTime * shadowTime;
			#endif
			
			#ifndef LIGHT_LEAK_FIX
				ambientCol *= pow(lightmap.y, 2.5);
			#else
				if (isEyeInWater == 1) ambientCol *= pow(lightmap.y, 2.5);
			#endif
			
			vec3 lightingCol = pow(lightCol, vec3(1.0 + sunVisibility));
			vec3 shadowDecider = fullShadow * shadowMult;
			if (isEyeInWater == 1) shadowDecider *= pow(min(lightmap.y * 1.03, 1.0), 200.0);
			vec3 sceneLighting = mix(ambientCol * AMBIENT_GROUND, lightingCol * LIGHT_GROUND, shadowDecider);

			//sceneLighting *= (0.7 + 0.2 * max(vsBrightness, sunVisibility));
			
			#ifdef LIGHT_LEAK_FIX
				if (isEyeInWater == 0) sceneLighting *= pow(lightmap.y, 2.5);
			#endif
		#endif

		#ifdef END
			vec3 ambientEnd = endCol * 0.07;
			vec3 lightEnd   = endCol * 0.17;
			//vec3 sceneLighting = endCol * (0.1 * fullShadow + 0.07);
			vec3 shadowDecider = fullShadow;
			vec3 sceneLighting = mix(ambientEnd, lightEnd, shadowDecider);
			sceneLighting *= END_I * (0.7 + 0.4 * vsBrightness);
		#endif

		#ifdef TWO
			vec3 sceneLighting = vec3(0.0003, 0.0004, 0.002) * 10.0;
		#endif
		
		#if defined SEVEN && !defined SEVEN_2
			sceneLighting = vec3(0.005, 0.006, 0.018) * 133 * (0.3 * fullShadow + 0.025);
		#endif
		#ifdef SEVEN_2
			vec3 sceneLighting = vec3(0.005, 0.006, 0.018) * 33 * (1.0 * fullShadow + 0.025);
		#endif
		#if defined SEVEN || defined SEVEN_2
			sceneLighting *= lightmap.y * lightmap.y;
		#endif
		
		#ifdef SHADOWS
			if (subsurface > 0.001){
				float VdotL = clamp(dot(normalize(viewPos.xyz), lightVec), 0.0, 1.0);
				sceneLighting *= 5.0 * shadowTime * fullShadow * pow(VdotL, 10.0) + 1.0;
			}
		#endif
    #else
		#ifdef NETHER
			#if MC_VERSION <= 11600
			#else
				if (quarterNdotU < 0.5625) quarterNdotU = 0.5625 + (0.4 - quarterNdotU * 0.7111111111111111);
			#endif
		
			vec3 sceneLighting = netherCol * (1 - pow(length(fogColor / 3), 0.25)) * NETHER_I * (vsBrightness*0.25 + 0.5);
		#else
			vec3 sceneLighting = vec3(0.0);
		#endif
    #endif
	
	#if !defined COMPATIBILITY_MODE && defined GBUFFERS_WATER
		if (mat > 2.98 && mat < 3.02) sceneLighting *= 0.0; // Nether Portal
	#endif


	#ifdef DYNAMIC_SHADER_LIGHT
		float handLight = min(float(heldBlockLightValue2 + heldBlockLightValue), 15.0) / 15.0;
		float handLightFactor = 1.0 - min(DYNAMIC_LIGHT_DISTANCE, lViewPos) / DYNAMIC_LIGHT_DISTANCE;
		#ifdef GBUFFERS_WATER
			handLight *= 0.9;
		#endif
		float finalHandLight = handLight * handLightFactor * 0.95;
		lightmap.x = max(finalHandLight, lightmap.x);
	#endif

	#if !defined COMPATIBILITY_MODE && defined ADVANCED_MATERIALS
		float newLightmap  = pow(lightmap.x, 10.0) * 5 + max((lightmap.x - 0.05) * 0.925, 0.0) * (vsBrightness*0.25 + 0.9);
	#else
		if (lightmap.x > 0.5) lightmap.x = smoothstep(0.0, 1.0, lightmap.x);
		float newLightmap  = pow(lightmap.x, 10.0) * 1.75 + max((lightmap.x - 0.05) * 0.925, 0.0) * (vsBrightness*0.25 + 0.9);
	#endif
	
	#ifdef BLOCKLIGHT_FLICKER
		newLightmap *= min(((1 - clamp(sin(fract(frametime*2.7) + frametime*3.7) - 0.75, 0.0, 0.25) * BLOCKLIGHT_FLICKER_STRENGTH)
					* max(fract(frametime*0.7), (1 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25))) / (1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.2)
					, 0.8) * 1.25
					* 0.8 + 0.2 * clamp((cos(fract(frametime*0.47) * fract(frametime*1.17) + fract(frametime*2.17))) * 1.5, 1.0 - BLOCKLIGHT_FLICKER_STRENGTH * 0.25, 1.0);
	#endif

	#ifdef COLORED_LIGHTING
		float CLr = texture2D(noisetex, 0.00006 * (worldPos.xz + cameraPosition.xz)).r;
		float CLg = texture2D(noisetex, 0.00009 * (worldPos.xz + cameraPosition.xz)).r;
		float CLb = texture2D(noisetex, 0.00014 * (worldPos.xz + cameraPosition.xz)).r;
		blocklightCol = vec3(CLr, CLg, CLb);
		blocklightCol *= blocklightCol * BLOCKLIGHT_I * 2.22;
	#endif

    vec3 blockLighting = blocklightCol * newLightmap * newLightmap;

	#ifndef MIN_LIGHT_EVERYWHERE
		float minLighting = 0.000000000001 + (MIN_LIGHT * 0.0035 * (vsBrightness*0.08 + 0.01)) * (1.0 - eBS);
	#else
		float minLighting = 0.000000000001 + (MIN_LIGHT * 0.0035 * (vsBrightness*0.08 + 0.01));
	#endif
	
    vec3 emissiveLighting = albedo.rgb * (emissive * 4.0 / pow(quarterNdotU, SHADING_STRENGTH)) * EMISSIVE_BRIGHTNESS;

    float nightVisionLighting = nightVision * 0.25;

	smoothLighting = clamp(smoothLighting, 0.0, 1.0);
	if (!(mat < 1.75 && mat > 0.75)) {
		smoothLighting = pow(smoothLighting, 
							(2.0 - min(length(fullShadow * shadowMult) + lightmap.x * 2.0, 1.5)) * VAO_STRENGTH
							);
	} else {
		smoothLighting = smoothLighting * smoothLighting;
	}
	//#ifdef COMPATIBILITY_MODE
	//if (!(0.0 < smoothLighting || smoothLighting < 0.0 || smoothLighting == 0.0 )) smoothLighting = 1.0;
	//#endif

	if (materialAO < 1.0) {
		smoothLighting *= pow(materialAO, max(1.0 - shadowTime * length(shadow) * NdotL - lmCoord.x, 0.0));
	}

    albedo *= sceneLighting + blockLighting + emissiveLighting + nightVisionLighting + minLighting;
    albedo *= pow(quarterNdotU, SHADING_STRENGTH) * smoothLighting;

	#if defined GBUFFERS_HAND && defined HAND_BLOOM_REDUCTION
		float albedoStrength = (albedo.r + albedo.g + albedo.b) / 10.0;
		if (albedoStrength > 1.0) albedo.rgb = albedo.rgb * max(2.0 - pow(albedoStrength, 1.0), 0.34);
	#endif
}