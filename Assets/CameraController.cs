using NUnit.Framework;
using UnityEngine;

public class CameraController : MonoBehaviour
{
    // Start is called once before the first execution of Update after the MonoBehaviour is created
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {
        var mouseDelta = Input.mousePositionDelta * 0.001f;
        if (Input.GetMouseButton(1))
        {
            transform.RotateAround(Vector3.up, mouseDelta.x);
            transform.RotateAround(transform.right, -mouseDelta.y);
        }
        if(Input.GetKey(KeyCode.W)) transform.position += 2 * Time.deltaTime * transform.forward;
        if(Input.GetKey(KeyCode.S)) transform.position -= 2 * Time.deltaTime * transform.forward;
        if(Input.GetKey(KeyCode.D)) transform.position += 2 * Time.deltaTime * transform.right;
        if(Input.GetKey(KeyCode.A)) transform.position -= 2 * Time.deltaTime * transform.right;
        if(Input.GetKey(KeyCode.E)) transform.position += 2 * Time.deltaTime * Vector3.up;
        if(Input.GetKey(KeyCode.Q)) transform.position -= 2 * Time.deltaTime * Vector3.up;

    }
}
