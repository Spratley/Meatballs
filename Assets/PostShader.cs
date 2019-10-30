using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using System;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class PostShader : MonoBehaviour
{
    public Material postMaterial;
    public Vector3 lightPos;

    [Range(0, 1)]
    public float blendAmount;
    
    [Range(0, 1)]
    public float reflectAmount;

    int activeObject;
    Transform target;

    private void Update()
    {
        if(Input.GetKeyDown(KeyCode.Space))
        {
            ++activeObject;
            GameObject[] objs = GameObject.FindGameObjectsWithTag("SDF");
            if (activeObject >= objs.Length)
                activeObject = 0;
            target = objs[activeObject].transform;
        }

        transform.LookAt(target);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        postMaterial.SetVector("_CameraPos", transform.position);
        postMaterial.SetVector("_CameraDir", transform.forward);
        postMaterial.SetVector("_CameraUp", transform.up);
        postMaterial.SetVector("_CameraRight", transform.right);
        postMaterial.SetFloat("_CameraAspect", GetComponent<Camera>().aspect);
        postMaterial.SetVector("_LightPos", lightPos);
        postMaterial.SetFloat("_BlendAmount", blendAmount);
        postMaterial.SetFloat("_ReflectionAmount", reflectAmount);


        //Send Object Data
        GameObject[] objs = GameObject.FindGameObjectsWithTag("SDF");

        List<Vector4> positions = new List<Vector4>();
        List<float> cubes = new List<float>();
        List<Vector4> scales = new List<Vector4>();
        List<float> reflectives = new List<float>();

        for (int i = 0; i < Mathf.Min(10, objs.Length); ++i)
        {
            SDFInfo info = objs[i].GetComponent<SDFInfo>();

            positions.Add(objs[i].transform.position);
            cubes.Add(Convert.ToInt32(info.isCube));
            scales.Add(objs[i].transform.localScale);
            reflectives.Add(info.reflectivity);
        }

        postMaterial.SetVectorArray("_SDFPos", positions);
        postMaterial.SetVectorArray("_SDFScale", scales);
        postMaterial.SetFloatArray("_SDFCubes", cubes);
        postMaterial.SetFloatArray("_SDFReflective", reflectives);

        Graphics.Blit(source, destination, postMaterial);
    }
}
