// Upgrade NOTE: commented out 'float3 _WorldSpaceCameraPos', a built-in variable

Shader "Custom/RaytracingShader"
{
    
    Properties
    {
        _MainTex ("Camera Color Texture", 2D) = "white" {}
    }
    
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            Name "RaytracingShader"
            CGPROGRAM
            #include "UnityCG.cginc"
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 3.0

            float4x4 CameraLocalToWorldMatrix;
            float3 ViewParameters;


            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 position : SV_POSITION;
            };

            struct Ray {
                float3 origin;
                float3 direction;
                float energy;
            };


            struct Material
            {
                float absorption;
                float transmission;
                float roughness;
                float scatter;
            };

            struct Box {
                float3 min;
                float3 max;
                Material material;
            };

            struct Intersect {
                bool hit;
                float airHit;
                Ray incomingRay;
                float3 position;
                float3 normal;
                Material material;
                float distance;
                float energyAtPoint;
            };

            struct Source {
                float3 position;
                float3 color;
                float intensity;
            };


            StructuredBuffer<Box> boxes;
            int boxCount;

            StructuredBuffer<Source> sources;
            int sourceCount;

            sampler2D _MainTex;

            float RandomFloat(float seed)
            {
                uint bits = asuint(seed); // convert float to uint bits
                bits ^= bits >> 12;
                bits ^= bits << 25;
                bits ^= bits >> 27;
                bits *= 2685821657736338717u; // large prime multiplier

                // convert to [0,1)
                return frac(bits * 0.00000000023283064365386963); 
                // 1/2^32 ≈ 2.3283064365386963e-10
            }

            float GetDistanceIntensityFalloff(float distance)
            {
                return 1 / (1 + 0.2 * distance * distance);
            }

            float SampleAirScatterDistance(float density, inout float seed)
            {
                seed = RandomFloat(seed);
                return seed * 10;
                
            }
            
            Intersect RayBoxIntersect(Ray r, Box box)
            {
                Intersect intersect;
                intersect.hit = false;
                intersect.normal = 0;
                intersect.energyAtPoint = 0;
                intersect.incomingRay = r;
                intersect.airHit = false;
                intersect.material = box.material;
                intersect.distance = 1e20;
                intersect.position = 0;

                float3 invDir = 1.0 / r.direction;

                float3 t1 = (box.min - r.origin) * invDir;
                float3 t2 = (box.max - r.origin) * invDir;

                float3 tMin = min(t1, t2);
                float3 tMax = max(t1, t2);

                float tNear = max(max(tMin.x, tMin.y), tMin.z);
                float tFar  = min(min(tMax.x, tMax.y), tMax.z);

                if (tNear > tFar || tFar < 0.0)
                    return intersect;

                float tHit = tNear >= 0.0 ? tNear : tFar;

                intersect.hit = true;
                intersect.position = r.origin + tHit * r.direction;
                intersect.distance = tHit;
                intersect.energyAtPoint = r.energy * GetDistanceIntensityFalloff(tHit);

                float3 n = 0;

                bool originatedInside =
                    box.min.x < r.origin.x && r.origin.x < box.max.x &&
                    box.min.y < r.origin.y && r.origin.y < box.max.y &&
                    box.min.z < r.origin.z && r.origin.z < box.max.z;

                if (tHit == t1.x) n = float3(-1, 0, 0);
                else if (tHit == t2.x) n = float3(1, 0, 0);
                else if (tHit == t1.y) n = float3(0, -1, 0);
                else if (tHit == t2.y) n = float3(0, 1, 0);
                else if (tHit == t1.z) n = float3(0, 0, -1);
                else if (tHit == t2.z) n = float3(0, 0, 1);

                if (originatedInside) n = -n;

                intersect.normal = n;

                return intersect;
            }
            
            Intersect GetIntersect(Ray ray, inout float seed, bool airIneraction = false)
            {
                bool found = false;
                Intersect closestIntersect;
                closestIntersect.distance = 1e20;
                closestIntersect.hit = false;
                closestIntersect.incomingRay = ray;
                
                for (int i = 0; i < boxCount; i++)
                {
                    Intersect intersect = RayBoxIntersect(ray, boxes[i]);
                    if (!intersect.hit) continue;
                    if (!found || intersect.distance < closestIntersect.distance)
                    {
                        found = true;
                        closestIntersect = intersect;
                    }
                }
                Material airMaterial;
                airMaterial.absorption = 0.1;
                airMaterial.transmission = 0.9;
                airMaterial.roughness = 1;
                airMaterial.scatter = 1;

                closestIntersect.airHit = -1;
                
                return closestIntersect;
                
                float surfaceDistance = closestIntersect.distance;


                float airDistance = SampleAirScatterDistance(1 - airMaterial.transmission, seed);

                if (airDistance < surfaceDistance)
                {
                    Intersect airIntersect;
                    seed = RandomFloat(seed);
                    airIntersect.normal = float3(0,0,0);
                    airIntersect.hit = false;
                    airIntersect.airHit = 1;
                    airIntersect.material = airMaterial;
                    airIntersect.distance = airDistance;
                    airIntersect.energyAtPoint = ray.energy * GetDistanceIntensityFalloff(airDistance);
                    airIntersect.position = ray.origin + ray.direction * airDistance;
                    airIntersect.incomingRay = ray;
                    return airIntersect;
                }


                    return closestIntersect;
                
            }
            
            Ray SampleSoundReflectionRay(Intersect intersect, inout float seed)
            {
                float roughness = intersect.material.roughness;

                float3 incomingDirection =
                    normalize(intersect.incomingRay.direction);

                float3 surfaceNormal =
                    intersect.normal;

                // Perfect reflection direction
                float3 reflectionDirection =
                    reflect(incomingDirection, surfaceNormal);

                // Mirror case
                if (roughness < 0.001f)
                {
                    Ray mirrorRay;
                    mirrorRay.origin =
                        intersect.position + surfaceNormal * 0.01f;
                    mirrorRay.direction =
                        reflectionDirection;
                    mirrorRay.energy =
                        intersect.energyAtPoint;
                    return mirrorRay;
                }

                // Glossy / diffuse sampling
                float randomValue1 = RandomFloat(seed);
                float randomValue2 = RandomFloat(randomValue1);
                seed = randomValue2;

                // Convert roughness to lobe exponent
                float exponent = max(1.0f, (1.0f - roughness) * 100.0f);

                float phi = 2.0f * 3.14159 * randomValue1;
                float cosTheta = pow(randomValue2, 1.0f / (exponent + 1.0f));
                float sinTheta = sqrt(1.0f - cosTheta * cosTheta);

                float x = cos(phi) * sinTheta;
                float y = sin(phi) * sinTheta;
                float z = cosTheta;

                // Build basis around reflection direction
                float3 tangent;
                if (abs(reflectionDirection.x) > 0.1f)
                    tangent = normalize(cross(float3(0,1,0), reflectionDirection));
                else
                    tangent = normalize(cross(float3(1,0,0), reflectionDirection));

                float3 bitangent =
                    cross(reflectionDirection, tangent);

                float3 sampledDirection =
                    normalize(
                        tangent   * x +
                        bitangent * y +
                        reflectionDirection * z
                    );

                Ray bouncedRay;
                bouncedRay.origin =
                    intersect.position + surfaceNormal * 0.01f;
                bouncedRay.direction =
                    sampledDirection;
                bouncedRay.energy =
                    intersect.energyAtPoint;
                return bouncedRay;
            }

            Ray SampleSoundTransmissionRay(Intersect intersect, inout float seed)
            {
                Ray transmittedRay;

                float3 incomingDirection =
                    normalize(intersect.incomingRay.direction);

                float3 surfaceNormal =
                    intersect.normal;
                
                float normalDot =
                    dot(incomingDirection, surfaceNormal);

                float3 inwardNormal =
                    (normalDot < 0.0f) ? -surfaceNormal : surfaceNormal;

                // Optional scattering
                float scattering = intersect.material.scatter;

                float3 scatteredDirection = incomingDirection;

                if (scattering > 0.0f)
                {
                    // Small random deviation
                    float r1 = RandomFloat(seed);
                    float r2 = RandomFloat(r1);
                    seed = r2;

                    float theta = 2.0f * 3.14159 * r1;
                    float radius = scattering * sqrt(r2);

                    float3 tangent;
                    if (abs(incomingDirection.x) > 0.1f)
                        tangent = normalize(cross(float3(0,1,0), incomingDirection));
                    else
                        tangent = normalize(cross(float3(1,0,0), incomingDirection));

                    float3 bitangent =
                        cross(incomingDirection, tangent);

                    scatteredDirection =
                        normalize(
                            incomingDirection +
                            tangent * cos(theta) * radius +
                            bitangent * sin(theta) * radius
                        );
                }

                // Offset origin INSIDE
                transmittedRay.origin =
                    intersect.position + inwardNormal * 0.01f;

                transmittedRay.direction =
                    scatteredDirection;

                transmittedRay.energy =
                    intersect.energyAtPoint;

                return transmittedRay;
            }

            Ray SampleSoundAirScatterRay(Intersect intersect, inout float seed)
            {
                Ray scatteredRay;

                float3 incomingDirection =
                    normalize(intersect.incomingRay.direction);

                // How chaotic the air is
                float scatterStrength = intersect.material.scatter; // 0..1
                float roughness = intersect.material.roughness;     // usually ~1 for air

                // Random numbers
                float r1 = RandomFloat(seed);
                float r2 = RandomFloat(r1);
                seed = r2;

                // Isotropic direction (pure diffusion)
                float z = 1.0 - 2.0 * r1;
                float r = sqrt(max(0.0, 1.0 - z * z));
                float phi = 2.0 * 3.14159 * r2;

                float3 randomDirection = float3(
                    r * cos(phi),
                    r * sin(phi),
                    z
                );

                // Bias toward forward direction (waves don’t teleport)
                float3 scatteredDirection =
                    normalize(lerp(incomingDirection, randomDirection, scatterStrength * roughness));

                // Offset slightly forward to avoid self-intersection
                scatteredRay.origin =
                    intersect.position + scatteredDirection * 0.01f;

                scatteredRay.direction =
                    scatteredDirection;

                // Energy decays in air, no free lunches
                scatteredRay.energy =
                    intersect.energyAtPoint;

                return scatteredRay;
            }
            
            float3 GetLightContribution(Intersect intersect, inout float seed)
            {
                float3 normal = intersect.normal;
                float3 color = float3(0, 0, 0);
                for (int i = 0; i<sourceCount; i++)
                {
                    Source source = sources[i];
                    float3 lightDirection = normalize(source.position - intersect.position);

                    Ray lightRay;
                    lightRay.origin = intersect.position + intersect.normal * 0.01;
                    lightRay.direction = lightDirection;
                    lightRay.energy = 0;
                    
                    Intersect lightOcclusion = GetIntersect(lightRay, seed);

                    
                    if (lightOcclusion.hit && distance(lightOcclusion.position, intersect.position) < distance(source.position, intersect.position))
                    {
                        continue;
                    }
                    
                    float similarity = max(dot(normal, lightDirection), 0);
                    float intensity = source.intensity * GetDistanceIntensityFalloff(distance(source.position, intersect.position));
                    float factor = intensity * similarity * intersect.energyAtPoint * source.color;
                    seed = RandomFloat(seed);
                    if (seed > factor) continue;
                    color += source.color;
                }
                return color;
            }
            
            v2f vert(appdata v)
            {
                v2f o;
                o.position = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag(v2f index) : SV_Target
            {

                float seed = RandomFloat(0.1 + RandomFloat(index.uv.x) + 0.2 + index.uv.y);
                float4 cameraTexture = tex2D(_MainTex, index.uv);
                if (seed < 0.3) return cameraTexture;
                
                float3 viewPointLocal = float3(index.uv - 0.5, 1) * ViewParameters;
                float3 viewPoint = mul(CameraLocalToWorldMatrix, float4(viewPointLocal, 1));
                float3 cameraPosition = _WorldSpaceCameraPos;
                
                Ray ray;
                float3 color = float3(0,0,0);
                ray.origin = cameraPosition;
                ray.direction = normalize(viewPoint - cameraPosition);
                ray.energy = 1.0;
                
                
                for (int i = 0; i < sourceCount; i++)
                {
                    Source source = sources[i];
                    Ray direct;
                    direct.origin = cameraPosition;
                    direct.direction = normalize(source.position - cameraPosition);
                    Intersect intersect = GetIntersect(direct, seed);
                    if (intersect.hit && intersect.distance < distance(source.position, cameraPosition))
                    {
                        continue;
                    }
                    float lightDistance = length(source.position - cameraPosition);
                    float3 dest = ray.direction * lightDistance;
                    float destLightDist = distance(direct.direction * lightDistance, dest);
                    float intensity = source.intensity * GetDistanceIntensityFalloff(destLightDist*10) * GetDistanceIntensityFalloff(lightDistance*2);
                    color += intensity * source.color;
                }

                for (int i = 0; i < 10; i++)
                {
                    Intersect inter = GetIntersect(ray, seed, true);
                    
                    if (!inter.hit) break;
                    
                    seed = RandomFloat(seed);
                    if (seed < inter.material.absorption) break;
                    
                    bool transmitted = seed < inter.material.transmission;
                    
                    color += GetLightContribution(inter, seed);
                    

                    if (transmitted)
                    {
                        ray = SampleSoundTransmissionRay(inter, seed);
                    }
                    else
                    {
                        ray = SampleSoundReflectionRay(inter, seed);
                    }
                    
                }
                return float4(color, 1) + cameraTexture;
            }

            ENDCG
        }
    }
}
