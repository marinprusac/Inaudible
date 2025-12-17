using System;
using System.Collections.Generic;
using UnityEngine;

public class RaytracingManager : MonoBehaviour
{

    [SerializeField] bool useShader = true;
    [SerializeField] Material raytracingMaterial;


    private Box[] _sceneBoxes;
    private Source[] _sceneSources;
    
    private ComputeBuffer _boxBuffer;
    private ComputeBuffer _sourceBuffer;
    

    void PrepareObjects()
    {
        _sceneBoxes = FindObjectsByType<Box>(FindObjectsInactive.Include, FindObjectsSortMode.None);
        _sceneSources = FindObjectsByType<Source>(FindObjectsInactive.Include, FindObjectsSortMode.None);
    }

    void CreateBuffers()
    {
        _boxBuffer = new ComputeBuffer(_sceneBoxes.Length, RTBox.Size, ComputeBufferType.Structured);
        _sourceBuffer = new ComputeBuffer(_sceneSources.Length, RTSource.Size, ComputeBufferType.Structured);

    }

    void PrepareBuffers()
    {
        
        var rtBoxes = new RTBox[_sceneBoxes.Length];
        for (var i = 0; i < _sceneBoxes.Length; i++)
        {
            var sceneBox = _sceneBoxes[i];
            var min = sceneBox.min;
            var max = sceneBox.max;
            rtBoxes[i] = new RTBox
            {
                min = min,
                max = max,
                material = new RTMaterial
                {
                    absorption = sceneBox.absorption,
                    transmission = sceneBox.transmission,
                    roughness = sceneBox.roughness,
                    scatter = sceneBox.scatter
                }
            };
        }

        _boxBuffer.SetData(rtBoxes);
        raytracingMaterial.SetBuffer("boxes", _boxBuffer);
        raytracingMaterial.SetInt("boxCount", _boxBuffer.count);

        var rtSources = new RTSource[_sceneSources.Length];
        for (var i = 0; i < _sceneSources.Length; i++)
        {
            var sceneSource = _sceneSources[i];
            rtSources[i] = new RTSource
            {
                position = sceneSource.transform.position,
                color = sceneSource.color,
                intensity = sceneSource.intensity
            };
        }
        _sourceBuffer.SetData(rtSources);
        raytracingMaterial.SetBuffer("sources", _sourceBuffer);
        raytracingMaterial.SetInt("sourceCount", _sourceBuffer.count);
    }

    void OnEnable()
    {
        PrepareObjects();
        CreateBuffers();
    }
    
    void OnDestroy()
    {
        if (_boxBuffer != null)
        {
            _boxBuffer.Release();
            _boxBuffer = null;
        }

        if (_sourceBuffer != null)
        {
            _sourceBuffer.Release();
            _sourceBuffer = null;
        }
    }

    
    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (useShader && raytracingMaterial != null)
        {
            PrepareBuffers();
            var cam = Camera.current;
            float planeHeight = cam.nearClipPlane * Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad) * 2;
            float planeWidth = planeHeight * cam.aspect;
            raytracingMaterial.SetVector("ViewParameters", new Vector3(planeWidth, planeHeight, cam.nearClipPlane));
            raytracingMaterial.SetMatrix("CameraLocalToWorldMatrix", cam.transform.localToWorldMatrix);
            Graphics.Blit(source, destination, raytracingMaterial);
        }
        else
        {
            Graphics.Blit(source, destination);
        }
    }

    private void Update()
    {
        print(1/Time.deltaTime);
    }
}
