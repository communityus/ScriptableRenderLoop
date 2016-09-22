#ifndef UNITY_MATERIAL_DISNEYGGX_INCLUDED
#define UNITY_MATERIAL_DISNEYGGX_INCLUDED

//-----------------------------------------------------------------------------
// SurfaceData and BSDFData
//-----------------------------------------------------------------------------

// Main structure that store the user data (i.e user input of master node in material graph)
struct SurfaceData
{
	float3	diffuseColor;
	float	occlusion;

	float3	specularColor;
	float	smoothness;

	float3	normal;		// normal in world space
};

struct BSDFData
{
	float3	diffuseColor;
	float	occlusion;

	float3	fresnel0;
	float	roughness;

	float3	normalWS;
	float	perceptualRoughness;
};

//-----------------------------------------------------------------------------
// conversion function for forward and deferred
//-----------------------------------------------------------------------------

BSDFData ConvertSurfaceDataToBSDFData(SurfaceData data)
{
	BSDFData output;

	output.diffuseColor = data.diffuseColor;
	output.occlusion = data.occlusion;

	output.fresnel0 = data.specularColor;
	output.roughness = SmoothnessToRoughness(data.smoothness);

	output.normalWS = data.normal;
	output.perceptualRoughness = SmoothnessToPerceptualRoughness(data.smoothness);

	return output;
}

// This will encode UnityStandardData into GBuffer
void EncodeIntoGBuffer(SurfaceData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)
{
	// RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
	outGBuffer0 = half4(data.diffuseColor, data.occlusion);

	// RT1: spec color (rgb), roughness (a) - sRGB rendertarget
	outGBuffer1 = half4(data.specularColor, SmoothnessToRoughness(data.smoothness));

	// RT2: normal (rgb), --unused, very low precision-- (a) 
	outGBuffer2 = half4(PackNormalCartesian(data.normal), 1.0f);
}

// This decode the Gbuffer in a BSDFData struct
BSDFData DecodeFromGBuffer(half4 inGBuffer0, half4 inGBuffer1, half4 inGBuffer2)
{
	BSDFData data;

	data.diffuseColor = inGBuffer0.rgb;
	data.occlusion = inGBuffer0.a;

	data.fresnel0 = inGBuffer1.rgb;
	data.roughness = inGBuffer1.a;

	data.normalWS = UnpackNormalCartesian(inGBuffer2.rgb);

	return data;
}

//-----------------------------------------------------------------------------
// EvaluateBSDF functions for each light type
//-----------------------------------------------------------------------------

void EvaluateBSDF_Punctual(	float3 V, float3 positionWS, PunctualLightData light, BSDFData material,
							out float4 diffuseLighting,
							out float4 specularLighting)
{
	float3 unL = light.positionWS - positionWS;
	float3 L = normalize(unL);

	// Always done, directional have it neutral
	float attenuation = GetDistanceAttenuation(unL, light.invSqrAttenuationRadius);
	// Always done, point and dir have it neutral
	attenuation *= GetAngleAttenuation(L, light.forward, light.angleScale, light.angleOffset);
	float illuminance = saturate(dot(material.normalWS, L)) * attenuation;

	diffuseLighting = float4(0.0f, 0.0f, 0.0f, 1.0f);
	specularLighting = float4(0.0f, 0.0f, 0.0f, 1.0f);

	if (illuminance > 0.0f)
	{
		float NdotV = abs(dot(material.normalWS, V)) + 1e-5f; // TODO: check Eric idea about doing that when writting into the GBuffer (with our forward decal)
		float3 H = normalize(V + L);
		float LdotH = saturate(dot(L, H));
		float NdotH = saturate(dot(material.normalWS, H));
		float NdotL = saturate(dot(material.normalWS, L));
		float3 F = F_Schlick(material.fresnel0, LdotH);
		float Vis = V_SmithJointGGX(NdotL, NdotV, material.roughness);
		float D = D_GGX(NdotH, material.roughness);
		specularLighting.rgb = F * Vis * D;
		float disneyDiffuse = DisneyDiffuse(NdotV, NdotL, LdotH, material.perceptualRoughness);
		diffuseLighting.rgb = material.diffuseColor * disneyDiffuse;

		diffuseLighting.rgb *= light.color * illuminance;
		specularLighting.rgb *= light.color * illuminance;
	}
}

#endif // UNITY_MATERIAL_DISNEYGGX_INCLUDED