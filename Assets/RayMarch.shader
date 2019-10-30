Shader "Hidden/RayMarch"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Skybox("Skybox", Cube) = "default" {}
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                return o;
            }

			samplerCUBE _Skybox;
            sampler2D _MainTex;
			float4 _CameraPos;
			float4 _CameraDir;
			float4 _CameraUp;
			float4 _CameraRight;
			float _CameraAspect;
			float4 _LightPos;

			float _BlendAmount;
			float _ReflectionAmount;

			float4 _SDFPos[10];
			float _SDFCubes[10];
			float4 _SDFScale[10];

			float Sphere(float4 sphere_pos, float4 check_pos, float radius)
			{
				return length(check_pos - sphere_pos) - radius;
			}

			float VMax(float4 v)
			{
				return max(v.x, max(v.y, v.z));
			}

			float Cube(float4 cube_pos, float4 check_pos, float4 cube_size)
			{
				return VMax(abs(cube_pos - check_pos)- cube_size);
			}

			float Union(float d1, float d2)
			{
				return min(d1, d2);
			}

			float SmoothUnion(float d1, float d2, float k)
			{
				float h = clamp(0.5 + 0.5*(d2 - d1) / k, 0.0, 1.0);
				return lerp(d2, d1, h) - k * h*(1.0 - h);
			}

			float Subtract(float d1, float d2)
			{
				return max(-d1, d2);
			}

			float Intersection(float d1, float d2)
			{
				return max(d1, d2);
			}

			float Blend(float d1, float d2, float amount)
			{
				return d1 * amount + (1 - amount) * d2;
			}

			float SceneSDF(float4 checkPos)
			{
				float d1, d2 = 1000;
				for (int j = 0; j < 3; ++j)
				{
					d1 = Sphere(_SDFPos[j], checkPos, _SDFScale[j].x) * (1 - _SDFCubes[j]);
					d1 += Cube(_SDFPos[j], checkPos, _SDFScale[j]) * (_SDFCubes[j]);

					d2 = SmoothUnion(d1, d2, _BlendAmount);
				}
				return d2;
			}

			float DistanceToObject(float4 pos, float4 dir, float tol)
			{
				int maxSteps = 100;
				float depth = 0;

				for (int i = 0; i < maxSteps; ++i)
				{
					float4 checkPos = pos + dir * depth;

					float dist = SceneSDF(checkPos);

					if (dist < tol)
						return depth;

					depth += dist;
				}
				return -1.0f;
			}

			float4 EstimateNormal(float4 p, float e) 
			{
				return normalize(float4(
					SceneSDF(float4(p.x + e, p.y, p.z, 0)) - SceneSDF(float4(p.x - e, p.y, p.z, 0)),
					SceneSDF(float4(p.x, p.y + e, p.z, 0)) - SceneSDF(float4(p.x, p.y - e, p.z, 0)),
					SceneSDF(float4(p.x, p.y, p.z + e, 0)) - SceneSDF(float4(p.x, p.y, p.z - e, 0)), 0
				));
			}

			float4x4 viewMatrix(float3 eye, float3 center, float3 up) {
				float3 f = normalize(center - eye);
				float3 s = normalize(cross(f, up));
				float3 u = cross(s, f);
				return float4x4(
					float4(s, 0.0),
					float4(u, 0.0),
					float4(-f, 0.0),
					float4(0.0, 0.0, 0.0, 1)
				);
			}

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

				float4 fragPos = _CameraPos;

				float4 dir = normalize(_CameraDir + (_CameraRight * (i.uv.x * 2 - 1) * _CameraAspect) + (_CameraUp * (i.uv.y * 2 - 1)));

				float dist = DistanceToObject(fragPos, dir, 0.001f);
				float4 position = dist * dir + fragPos;

				float4 normal = EstimateNormal(position, 0.001f);

				float4 lightDir = normalize(_LightPos - position);
				float diff = max(dot(normal, lightDir), 0.0);
				float4 diffuse = diff;
 
				//Reflection data!
				float4 savePos = position;
				float4 saveNorm = normal;
				float4 saveDir = dir;

				float4 saveColor = float4(0,0,0,0);

				for (int i = 0; i < 3; ++i)
				{
					float4 reflection = reflect(saveDir, saveNorm);
					float rDist = DistanceToObject(savePos + reflection * 0.01f, reflection, 0.001f);
					float4 rPos = rDist * reflection + savePos;

					float4 rNormal = EstimateNormal(rPos, 0.01f);

					float4 rLightDir = normalize(_LightPos - rPos);
					float rDiff = max(dot(rNormal, rLightDir), 0.0);

					int modifier = (sign(rDist) + 1) / 2.0f;

					float4 rDiffuse = rDiff * modifier + texCUBE(_Skybox, reflection) * (1 - modifier);

					savePos = rPos;
					saveNorm = rNormal;
					saveDir = reflection;

					saveColor = saveColor * (1 - _ReflectionAmount)  + rDiffuse * _ReflectionAmount;

					if (modifier == 0)
						break;
				}
				//End of reflection stuffs :3

				int modifier = (sign(dist) + 1)/ 2.0f;

				diffuse = (diffuse * (1 - _ReflectionAmount)) + (saveColor * _ReflectionAmount);

				col.rgb = (col * (1 - modifier)) + (diffuse) * modifier;

                return col;
            }
            ENDCG
        }
    }
}
