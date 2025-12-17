using UnityEngine;

public struct RTSource
{
    public Vector3 position;
    public Vector3 color;
    public float intensity;
    public static int Size => sizeof(float) * 7;
}