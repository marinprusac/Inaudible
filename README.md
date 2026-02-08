# Inaudible

**Visualisation of raytraced sound in 3D games for deaf people.**

Inaudible is a Unity-based prototype that explores how sound propagation in 3D environments can be represented visually. Instead of relying on audio cues, the system raytraces sound through a scene and renders visual feedback to convey direction, distance, and intensity of sound events.

The goal is to improve accessibility and spatial awareness for deaf and hard-of-hearing players, while also serving as a research and experimentation platform for sound visualization in games.

## What this project is

This is not an audio engine or a drop-in Unity package. It is a **research-oriented proof of concept** that demonstrates:

- Raytraced simulation of sound propagation
- Visualization of sound paths and interactions with the environment
- Integration of sound visuals into a real-time 3D scene

## Repository structure

- `Assets/` – Unity assets including scripts, shaders, and scenes  
- `ProjectSettings/` – Unity project configuration  
- `Inaudible.slnx` – Visual Studio solution file  
- `.gitignore` – Standard Unity ignore rules  

## Features

- **Sound raytracing**  
  Emits rays from sound sources to simulate how sound travels through space.

- **Visual feedback**  
  Uses shaders and debug visuals to represent sound direction, reach, and intensity.

- **Unity integration**  
  Designed to be embedded directly into Unity scenes for experimentation and prototyping.

## Requirements

- Unity 2019 LTS or newer (matching the project’s original Unity version is recommended)
- Visual Studio or another C#-compatible editor

## Setup and usage

1. Clone the repository:
   ```sh
   git clone https://github.com/marinprusac/Inaudible.git
