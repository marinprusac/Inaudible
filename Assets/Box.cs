using System;
using Unity.VisualScripting;
using UnityEngine;
using UnityEngine.Serialization;

public class Box : MonoBehaviour
{
    public float absorption = 0.4f;
    public float transmission = 0.2f;
    public float roughness = 0.5f;
    public float scatter = 0.3f;

    [DoNotSerialize] public Vector3 min;
    [DoNotSerialize] public Vector3 max;
    
    private void Start()
    {
        var rend = GetComponent<Renderer>();
        var bounds = rend.bounds;
        max = bounds.max;
        min = bounds.min;
    }
}
