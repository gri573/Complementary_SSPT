vec4 RoughReflection(vec3 viewPos, vec3 normal, float dither, float smoothness, sampler2D colortex, float alternative) {
    vec4 color = vec4(0.0);

    vec4 pos = Raytrace(depthtex0, viewPos, normal, dither, alternative);
	float border = clamp(1.0 - pow(cdist(pos.st), 50.0), 0.0, 1.0);
	
	if (pos.z < 1.0 - 1e-5) {
		#ifdef REFLECTION_ROUGH
			float dist = 1.0 - exp(-0.125 * (1.0 - smoothness) * pos.a);
			float lod = log2(viewHeight / 8.0 * (1.0 - smoothness) * dist) * 0.35;
		#else
			float lod = 0.0;
		#endif

		float check = float(texture2DLod(depthtex0, pos.st, 0.0).r < 1.0 - 1e-5);
		if (lod < 1.0) {
			color.a = check;
			if (color.a > 0.1) color.rgb = texture2DLod(colortex, pos.st, 0.0).rgb;
		} else {
			float alpha = check;
			if (alpha > 0.1) {
				color.rgb += texture2DLod(colortex, pos.st, max(lod - 1.0, 0.0)).rgb;
				color.a += alpha;
			}
		}
		
		color *= color.a;
		color.a *= border;
	}
	color.rgb *= 2.25 * (1.0 - 0.065 * min(length(color.rgb), 10.0));
	
    return color;
}
vec4 DiffuseGI(vec3 viewPos, vec3 normal, float dither, sampler2D colortex, sampler2D albedo, sampler2D shadow, float sunStrength, vec3 noise) {
    vec4 color = vec4(0.0);

    vec4 pos = Pathtrace(depthtex0, viewPos, normal, dither, noise);
    float depth = texture2D(depthtex0, pos.xy).r;
	float border = clamp(1.0 - pow(cdist(1.1 *pos.st - vec2(0.05)), 50.0), 0.0, 1.0);
	if (depth < 0.9999) {
		color.a = 1;
		color.rgb = texture2D(colortex, pos.xy).rgb;
		//color.rgb *= clamp((length(color.rgb) - 0.005) / length(color.rgb), 0.0, 1.0);
		float shadowMask = clamp(10 * texture2D(shadow, pos.xy).r - 5, 0, 1);
		vec3 albedov = texture2D(albedo, pos.xy).rgb;
		float albedob = length(albedov);
		float dalbedo = pow(albedov.r - albedov.g, 2) + pow(albedov.g - albedov.b, 2) + pow(albedov.b - albedov.r, 2);
		float brightness = length(color.rgb);
		color.rgb *= normalize(color.rgb) * 1.72;
		color.rgb *= pow(brightness, 0.7) + clamp((brightness + dalbedo) * 30 * sunStrength * shadowMask, 0, 3);
		color.rgb /= 2 * pos.w + 0.2;
		color *= color.a;
		color *= border;
	}
	//color.rgb *= 1.5 * (1.0 - 0.065 * min(length(color.rgb), 10.0));
    return color;
}
