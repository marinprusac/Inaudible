using UnityEngine;

public struct RTMaterial
{

    public float absorption;
    public float transmission;
    public float roughness;
    public float scatter;
    
    public static int Size => sizeof(float) * 4;
}