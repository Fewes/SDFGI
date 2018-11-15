// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Effects/SDFGI"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
	}
	SubShader
	{
		// No culling or depth
		Cull Off ZWrite Off ZTest Always
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_instancing

			#include "UnityCG.cginc"
			#include "DistanceFunc.cginc"

			#define M_PI 3.14159265359
			#define M_2PI 6.28318530718

			#define RAY_DIRECTIONAL_OFFSET 0.01
			#define IMPORTANCE_SAMPLING

			// #define VISUALIZE_PERFORMANCE

			#define SUN_COLOR _SunColor * 1000

			// Material types
			#define MAT_DIFFUSE 0
			#define MAT_LIGHT 1
			#define SUN_SIZE 1E-5 * _SunSize

			struct Ray
			{
				float3 origin;
				float3 direction;
			};

			struct Surface
			{
				float3 position;
				float3 normal;
				float  id;
				float3 albedo;
				float  specular;
				float  roughness;
			};

			struct v2f
			{
				float4 vertex 		: SV_POSITION;
				float2 texcoord		: TEXCOORD0;
				float3 lensPosition : TEXCOORD1;

				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
			};

			sampler2D 	_MainTex;
			fixed4		_Color;

			samplerCUBE	_IBLTex;

			float3		_SunColor;
			float3		_SunDir;
			float		_SunSize;
			float		_SunSoftness;
			float3		_CameraRight;
			float3		_CameraUp;
			float3		_CameraForward;
			float4		_CameraParams;
			float		_IntegrationCount;
			float4		_Random;

			v2f vert (appdata_full v)
			{
				UNITY_SETUP_INSTANCE_ID(v);
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float lensWidth 	= _CameraParams.x;
				float lensHeight 	= _CameraParams.y;
				float focalLength	= _CameraParams.z;

				o.lensPosition = _WorldSpaceCameraPos + _CameraForward * focalLength;
				o.lensPosition += _CameraRight * lensWidth * (v.texcoord.x - 0.5);
				o.lensPosition += _CameraUp    * lensHeight * (v.texcoord.y - 0.5);

				o.vertex 	= UnityObjectToClipPos(v.vertex);
				o.texcoord 	= v.texcoord;

				return o;
			}

			// Function representing the scene geometry
			SDFO map (float3 p)
			{
				SDFO scene = SDFObject(99999999, 0, 0, 0, 0);
				// Walls
				scene = opU(scene, SDFObject(sdBox(p - float3( 1.6, 1.5, 0 ), float3(0.2, 3, 3)), MAT_DIFFUSE, float3(0, 1, 0), 0.05, 0.5));
				scene = opU(scene, SDFObject(sdBox(p - float3(-1.6, 1.5, 0 ), float3(0.2, 3, 3)), MAT_DIFFUSE, float3(1, 0, 0), 0.05, 0.5));
				scene = opU(scene, SDFObject(sdBox(p - float3( 0, 1.5, 1.6 ), float3(3, 3, 0.2)), MAT_DIFFUSE, float3(1, 1, 1), 0.05, 0.5));
				scene = opU(scene, SDFObject(sdBox(p - float3( 0, 1.5,-1.6 ), float3(3, 3, 0.2)), MAT_DIFFUSE, float3(1, 1, 1), 0.05, 0.5));

				// Floor
				scene = opU(scene, SDFObject(sdBox(p - float3( 0, -0.1, 0 ), float3(3, 0.2, 3)), MAT_DIFFUSE, float3(1, 1, 1), 0.05, 0.5));
				// Ceiling
				scene = opU(scene, SDFObject(sdBox(p - float3( 0,  3.1, 0 ), float3(3, 0.2, 3)), MAT_DIFFUSE, float3(1, 1, 1), 0.05, 0));
				// Ceiling hole
				scene = opS(scene, SDFObject(sdBox(p - float3( 0,  3.1, 0 ), float3(2, 0.3, 2)), MAT_DIFFUSE, float3(1, 1, 1), 0.05, 0));

				// Spheres
				// scene = opU(scene, SDFObject(sdSphere(p - float3(-0.5, 0.5, 0.5), 0.5), MAT_DIFFUSE, float3(0, 0, 0), 1, 0.0));
				// scene = opU(scene, SDFObject(sdSphere(p - float3(-0.5, 0.5, 0.5), 0.5), MAT_DIFFUSE, float3(0, 0, 0), 1, 0.0));
				scene = opU(scene, SDFObject(sdSphere(p - float3(-0.5, 0.5, 0.5), 0.5), MAT_DIFFUSE, float3(0, 0, 1), 0.15, 0.0));
				scene = opU(scene, SDFObject(sdSphere(p - float3(0.5, 0.5, 0.5), 0.5), MAT_DIFFUSE, float3(1, 0, 0), 1, 0.0));
				// scene = opU(scene, SDFObject(sdSphere(p - float3(1.5, 3.5, 1.5), 0.5), MAT_DIFFUSE, float3(0, 0, 1), 0.05, 0.1));

				// Light
				// scene = opU(scene, SDFObject(sdSphere(p - float3(0, 0.15, -0.1), 0.15), MAT_LIGHT, float3(1, 0.9, 0.6) * 4, 0.05, 0.1));
				// scene = opU(scene, SDFObject(sdBox(p - float3( 0, 3.0, 0 ), float3(1, 1, 1)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0));
				// scene = opU(scene, SDFObject(sdBox(p - float3( 1.5, 1.5, 1.5 ), float3(0.1, 3, 0.1)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0));
				// scene = opU(scene, SDFObject(sdBox(p - float3(-1.5, 1.5, 1.5 ), float3(0.1, 3, 0.1)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0));
				// scene = opU(scene, SDFObject(sdBox(p - float3(-1.5, 1.5,-1.5 ), float3(0.1, 3, 0.1)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0));
				// scene = opU(scene, SDFObject(sdBox(p - float3( 1.5, 1.5,-1.5 ), float3(0.1, 3, 0.1)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0));

				// Bounce light test
				// scene = opU(scene, SDFObject(sdBox(p - float3(-1.2, 1.5, 0 ), float3(0.1, 2, 2)), MAT_DIFFUSE, float3(1, 0, 0), 0.05, 0.1));
				// scene = opU(scene, SDFObject(sdBox(p - float3(-1.25, 1.5, 0 ), float3(0.01, 1.9, 1.9)), MAT_LIGHT, float3(1, 1, 1) * 10, 0.05, 0.1));

				return scene;
			}

			float3 calcNormal(in float3 pos)
			{
				// epsilon - used to approximate dx when taking the derivative
				const float2 eps = float2(0.001, 0.0);

				// The idea here is to find the "gradient" of the distance field at pos
				// Remember, the distance field is not boolean - even if you are inside an object
				// the number is negative, so this calculation still works.
				// Essentially you are approximating the derivative of the distance field at this point.
				float3 nor = float3(
					map(pos + eps.xyy).p - map(pos - eps.xyy).p,
					map(pos + eps.yxy).p - map(pos - eps.yxy).p,
					map(pos + eps.yyx).p - map(pos - eps.yyx).p);
				return normalize(nor);
			}

			// Return a pseudo-random float in the range [-1, 1]
			float rand (float2 uv)
			{
				return frac(sin(dot(uv.xy, float2(12.9898,78.233))) * 43758.5453)*2-1;
			}

			// Return a pseudo-random float2 in the range [0, 1]
			float2 rand2(float2 uv)
			{
				// implementation based on: lumina.sourceforge.net/Tutorials/Noise.html
				return float2(frac(sin(dot(uv.xy, float2(12.9898,78.233))) * 43758.5453),
				frac(cos(dot(uv.xy, float2(4.898,7.23))) * 23421.631));
			};

			float3 SphereDir (float2 uv)
			{
				float x, y, z, d;

				do
				{
					x = rand(uv + _Random.x);
					y = rand(uv + _Random.y);
					z = rand(uv + _Random.z);
					d = sqrt(x*x + y * y + z * z);
				} while (d > 1);

				x /= d;
				y /= d;
				z /= d;

				return float3(x, y, z);
			}

			// Performs uniform sampling of the unit disk.
			// Ref: PBRT v3, p. 777.
			float2 SampleDiskUniform(float u1, float u2)
			{
				float r   = sqrt(u1);
				float phi = M_2PI * u2;

				float sinPhi, cosPhi;
				sincos(phi, sinPhi, cosPhi);

				return r * float2(cosPhi, sinPhi);
			}

			// Performs cosine-weighted sampling of the hemisphere.
			// Ref: PBRT v3, p. 780.
			float3 SampleHemisphereCosine(float u1, float u2)
			{
				float3 localL;

				// Since we don't really care about the area distortion,
				// we substitute uniform disk sampling for the concentric one.
				localL.xy = SampleDiskUniform(u1, u2);

				// Project the point from the disk onto the hemisphere.
				localL.z = sqrt(1.0 - u1);

				return localL;
			}

			float3 ortho(float3 v)
			{
				//  See : http://lolengine.net/blog/2013/09/21/picking-orthogonal-vector-combing-coconuts
				return abs(v.x) > abs(v.z) ? float3(-v.y, v.x, 0.0) : float3(0.0, -v.z, v.y);
			}

			float3 HemisphereDir (float3 normal, float2 uv)
			{
				// return WeightedHemisphereDir(normal, uv);

				// Sphere -> hemisphere
				float3 dir = SphereDir(uv);
				if (dot(dir, normal) < 0)
					dir *= -1;

				// dir = lerp(dir, normal, length(rand(uv)) > 0.9);

				return dir;
			}

			// Cosine-weighted hemisphere
			float3 WeightedHemisphereDir(float3 normal, float2 uv)
			{
				const float bias = 1.0;

				// Generate orthogonal base
				float3 tangent  = normalize(ortho(normal));
				float3 binormal = normalize(cross(normal, tangent));
				// Get pseudo-random numbers
				float2 r = rand2(uv + _Random.xy);
				// Sample point on disc
				/*
				float radius = sqrt(r.x);
				float theta  = M_2PI * r.y;
				float x = radius * cos(theta);
				float y = radius * sin(theta);
				// Direction in tangent space
				float3 dir = float3(x, y, sqrt(max(0, 1 - r.x)));
				*/
				float3 dir = SampleHemisphereCosine(r.x, r.y);
				// Transform to world space and return
				return dir.x * tangent + dir.y * binormal + dir.z * normal;
			}

			float3 StratifiedHemisphere (float3 normal, float2 uv)
			{
				const int stratSpan = 8;
				const float stratWidth = 1.0 / (float)stratSpan;
				const int stratCount = stratSpan * stratSpan;
				// Wrap strat index
				int n = (int)(frac((float)_IntegrationCount / (float)stratCount) * stratCount);
			}

			// Raymarch along given ray
			bool raymarch(Ray ray, out Surface surface)
			{
				const int maxstep = 1024;
				const float drawdist = 10;

				float t = 0; // current distance traveled along ray
				UNITY_LOOP
				for (int i = 0; i < maxstep; ++i)
				{
					float3 p = ray.origin + ray.direction * t; // World space position of sample
					SDFO d = map(p);       // Sample of distance field (see map())

					// If the sample <= 0, we have hit something (see map()).
					if (d.p < 0.0001)
					{
						surface.position 	= p;
						surface.normal 		= calcNormal(p);
						surface.id 			= d.id;
						surface.albedo 		= d.albedo;
						surface.specular 	= d.specular;
						surface.roughness 	= d.roughness;

						return true;
					}

					// If the sample > 0, we haven't hit anything yet so we should march forward
					// We step forward by distance d, because d is the minimum distance possible to intersect
					// an object (see map()).
					t += d.p;

					if (t > drawdist)
						return false;
				}

				return false;
			}

			bool raymarch(Ray ray)
			{
				const int maxstep = 1024;
				const float drawdist = 10;

				float t = 0; // current distance traveled along ray
				UNITY_LOOP
				for (int i = 0; i < maxstep; ++i)
				{
					float3 p = ray.origin + ray.direction * t; // World space position of sample
					SDFO d = map(p);       // Sample of distance field (see map())

					// If the sample <= 0, we have hit something (see map()).
					if (d.p < 0.0001)
					{
						return true;
					}

					// If the sample > 0, we haven't hit anything yet so we should march forward
					// We step forward by distance d, because d is the minimum distance possible to intersect
					// an object (see map()).
					t += d.p;

					if (t > drawdist)
						return false;
				}

				return false;
			}

			float3 Ambient (float3 direction)
			{
				return texCUBE(_IBLTex, direction);
				// return lerp(unity_AmbientGround, unity_AmbientSky, direction.y*0.5+0.5);
			}

			float3 SunDirection (float2 uv)
			{
				return lerp(_SunDir, HemisphereDir(_SunDir, uv), _SunSoftness);
			}

			float3 getConeSample(float3 dir, float extent, float2 uv)
			{
				// Formula 34 in GI Compendium
				dir = normalize(dir);
				float3 o1 = normalize(ortho(dir));
				float3 o2 = normalize(cross(dir, o1));
				float2 r = rand2(uv + _Random.xy);
				r.x = r.x * M_2PI;
				r.y = 1.0 - r.y * extent;
				float oneminus = sqrt(1.0-r.y*r.y);
				return cos(r.x)*oneminus*o1+sin(r.x)*oneminus*o2+r.y*dir;
			}

			Ray NewRay (float3 origin, float3 direction)
			{
				Ray ray;
				ray.origin = origin;
				ray.direction = direction;
				return ray;
			}

			float3 Luminance (Ray ray, float2 uv)
			{
				// const float PDF = 1 / M_2PI;

				Surface surface;
				float3 luminance = 1.0;
				float3 direct = 0;

				for (int i = 0; i < 3; i++)
				{
					if (raymarch(ray, surface))
					{
						// Specular reflection
						float fresnel = max(-dot(ray.direction, surface.normal), 0);
						fresnel = 1 - fresnel;
						fresnel = pow(fresnel, 5);
						// Reflectance at 0 degrees
						float f0 = surface.specular;
						// Final specular term
						float specular = lerp(fresnel, 1, f0);
						bool reflection = rand2(uv + i + _Random.xy).x <= specular;

						if (surface.id == MAT_LIGHT)
						{
							// Ray hit a light source
							direct += luminance * surface.albedo;
						}
						else
						{
							if (reflection)
							{
								// Specular reflection
								ray.direction = lerp(reflect(ray.direction, surface.normal), WeightedHemisphereDir(surface.normal, uv+i), surface.roughness);
							}
							else
							{
								// Diffuse reflection
								#if defined(IMPORTANCE_SAMPLING)
									// Biased sampling (cosine weighted):
									// PDF = CosAngle / PI, BRDF = Albedo/PI

									ray.direction = WeightedHemisphereDir(surface.normal, uv+i); // Offset 

									float costh = max(dot(ray.direction, surface.normal), 0);

									float  PDF  = costh / M_PI;
									float3 BRDF = surface.albedo / M_PI;
									luminance *= 2.0 * BRDF * costh / PDF;
								#else
									// Unbiased sampling:
									// PDF = 1/(2*PI), BRDF = Albedo/PI

									ray.direction = HemisphereDir(surface.normal, uv+i);

									float costh = max(dot(ray.direction, surface.normal), 0);
									
									const float PDF = 1 / M_2PI;
									float3 BRDF = surface.albedo / M_PI;
									luminance *= 2.0 * BRDF * costh / PDF;
								#endif
							}
						}

						ray.origin = surface.position + surface.normal * RAY_DIRECTIONAL_OFFSET; // new start point

						// Direct lighting (sun)
						float3 sunSampleDir = -getConeSample(_SunDir, SUN_SIZE, uv);
						if (reflection)
						{
							
						}
						else
						{
							// float3 sunSampleDir = -_SunDir;
							float sunLight = dot(surface.normal, sunSampleDir);
							if (sunLight > 0 && !raymarch(NewRay(ray.origin, sunSampleDir)))
							{
								// direct += luminance * sunLight * 1E-5 * SUN_COLOR * 100;
								direct += luminance * sunLight * 1E-5 * SUN_COLOR * 100;
								// direct += 1E-5 * SUN_COLOR;
							}
						}
					}
					else
					{
						// Ray exited the scene and hit the sky
						return direct + luminance * Ambient(ray.direction);
					}
				}
				return direct; // Ray never reached a light source
			}

			float3 Sun (float3 direction)
			{
				return SUN_COLOR * (max(dot(direction, -_SunDir), 0) > 1 - SUN_SIZE * _SunSize);
			}

			fixed4 frag (v2f i) : SV_Target
			{
				UNITY_SETUP_INSTANCE_ID(i);

				float2 uv = i.texcoord.xy;

				Ray ray;
				ray.origin = _WorldSpaceCameraPos;
				float2 pixelSize = _CameraParams.xy / _ScreenParams.xy;
				float3 aa = HemisphereDir(_CameraForward, _Time.xy) * float3(pixelSize, 0);
				float3 lensPosition = i.lensPosition + aa;
				ray.direction = normalize(lensPosition - ray.origin);

				float focalLength = _CameraParams.z;
				float3 focalPoint = lensPosition + ray.direction * focalLength;
				float aperture = _CameraParams.w;
				float3 randomPoint = HemisphereDir(_CameraForward, uv) * float3(aperture, aperture, 0);
				ray.origin += randomPoint;
				ray.direction = normalize(focalPoint - ray.origin);

				float3 color = Luminance(ray, uv);

				float delta = saturate(1.0 / (_IntegrationCount+1));

				// if (delta < 0.001)
					// delta = 0;
				
				return float4(color, delta);
			}
			ENDCG
		}
	}
}