vec4 SimpleReflection(vec3 viewPos, vec3 normal, float dither) {
	vec4 reflection = vec4(0.0);

    vec4 pos = Raytrace(depthtex1, viewPos, normal, dither);

	float border = clamp(1.0 - pow(cdist(pos.st), 50.0), 0.0, 1.0);
	
	if (pos.z < 1.0 - 1e-5){
		reflection.a = texture2D(gaux2, pos.st).a;
		if (reflection.a > 0.001) reflection.rgb = texture2D(gaux2, pos.st).rgb;
		
		reflection.a *= border;
	}

	reflection.rgb = pow(reflection.rgb * 2.0, vec3(8.0));

	return reflection;
}