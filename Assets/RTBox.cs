using UnityEngine;

public struct RTBox
{
        public Vector3 min;
        public Vector3 max;
        public RTMaterial material;
        public static int Size => sizeof(float) * 6 + RTMaterial.Size;
}