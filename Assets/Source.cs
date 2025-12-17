using System;
using UnityEngine;

public class Source : MonoBehaviour
{
    const int fftSize = 1024; // Must be a power of 2, e.g., 64, 128, 256, 512, 1024, etc.
    const FFTWindow fftWindow = FFTWindow.BlackmanHarris;

    const float logMaxSoundFrequencyHz = 4.3424f; //log10(22000+1)

    [SerializeField] private float lerpFactor = 0.1f;

    private AudioSource audioSource;
    private MeshRenderer meshRenderer;
    private readonly float[] audioSpectrum = new float[fftSize];
    private readonly Color[] colorSpectrum = new Color[fftSize];

    private Color lerpedColor = Color.black;

    public Vector3 color;
    public float intensity = 100;

    public Color OverridenColor;
    private float lerpedIntensity = 0;

    private static float SoundToColorFrequency(float soundFrequencyHz)
    {
        var rescaledSoundFrequencyHz = Mathf.Log10(soundFrequencyHz + 1); // +1 to avoid log10(0)
        float t = rescaledSoundFrequencyHz / logMaxSoundFrequencyHz;
        t = Mathf.Clamp01(t);
        return t;
    }

    private static Color FromFrequency(float t)
    {
        t = Mathf.Clamp01(t);
        float hue = (1-t) * 230f / 400f;  // Unity HSV hue is 0–1
        float saturation = 1f;
        float value = 1f;
        return Color.HSVToRGB(hue, saturation, value);
    }

    private static Color LinearizeColor(Color color)
    {
        return new Color(Mathf.GammaToLinearSpace(color.r), Mathf.GammaToLinearSpace(color.g), Mathf.GammaToLinearSpace(color.b));
    }
    private static Color GammaizeColor(Color color)
    {
        return new Color(Mathf.LinearToGammaSpace(color.r), Mathf.LinearToGammaSpace(color.g), Mathf.LinearToGammaSpace(color.b));
    }


    void Start()
    {
        audioSource = GetComponent<AudioSource>();
        meshRenderer = GetComponent<MeshRenderer>();
        for(int i = 0; i < fftSize; i++)
        {
            float soundFrequencyHz = i * (AudioSettings.outputSampleRate / 2f) / fftSize;
            float visionFrequencyTHz = SoundToColorFrequency(soundFrequencyHz);
            colorSpectrum[i] = LinearizeColor(FromFrequency(visionFrequencyTHz));
        }
    }

    void Update()
    {
        FixedColor();
    }

    void ProceduralColor()
    {
        audioSource.GetSpectrumData(audioSpectrum, 0, fftWindow);
        Color weightedLinearColor = Color.black;
        float totalWeight = 0f;
        for(int i = 0; i < fftSize; i++)
        {
            var soundAmplitude = audioSpectrum[i];
            if (soundAmplitude <= 0f) continue;
            var color = colorSpectrum[i] * soundAmplitude;
            weightedLinearColor += color;
            totalWeight += soundAmplitude;
            
        }
        weightedLinearColor.a = 1f;
        if(totalWeight <= 0)
        {
            weightedLinearColor = Color.black;
        }
        lerpedColor = Color.Lerp(lerpedColor, GammaizeColor(weightedLinearColor), 1 - Mathf.Pow(lerpFactor, Time.deltaTime));

        var newColor = Color.Lerp(lerpedColor, weightedLinearColor, 0.5f);
        
        color = new Vector3(newColor.r, newColor.g, newColor.b);
    }

    void FixedColor()
    {
        audioSource.GetSpectrumData(audioSpectrum, 0, fftWindow);
        float totalWeight = 0f;
        for(int i = 0; i < fftSize; i++)
        {
            var soundAmplitude = audioSpectrum[i];
            if (soundAmplitude <= 0f) continue;
            totalWeight += soundAmplitude;
        }
        if(totalWeight <= 0)
        {
            color = Vector3.zero;
        }

        lerpedIntensity = Mathf.Lerp(lerpedIntensity, totalWeight, 1 - MathF.Pow(lerpFactor, Time.deltaTime));
        
        color = new Vector3(OverridenColor.r, OverridenColor.g, OverridenColor.b) * lerpedIntensity;
    }
}
