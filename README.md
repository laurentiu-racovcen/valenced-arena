# 2VALenced Arena

A 2D top-down micro-battle game with AI-controlled agents, built for the MPS course (Direction A).  
Teams of agents fight across multiple game modes using different AI strategies and communication patterns.  
The system also collects detailed statistics and supports replaying matches.

---

## Table of Contents

- [Project Overview](#project-overview)
- [Features](#features)
- [Tech Stack](#tech-stack)
- [Repository Structure](#repository-structure)
- [Running the Project](#running-the-project)
- [Game Design](#game-design)
  - [Game Modes](#game-modes)
  - [Agent Roles & AI](#agent-roles--ai)
  - [Communication Modes](#communication-modes)
  - [Statistics](#statistics)


---

## Project Overview

This project implements a 2D top-down arena shooter where **AI agents** fight in short rounds on predefined maps.  
The focus is on:

- implementing several **game modes** (Survival, KOTH, CTF, Transport),
- designing **different AI behaviors per role**,
- experimenting with **communication constraints between agents**,
- and **collecting statistics** over multiple matches.

The project is built as part of the **MPS** course and targets both gameplay and software engineering aspects (architecture, documentation, testing, teamwork).

---

## Features

- **Top-down 2D arena**
  - Simple shapes (circles/rectangles) for agents, bullets, walls.
  - Line of Sight (LoS) based shooting.

- **Multiple game modes**
  - Survival
  - King of the Hill (KOTH)
  - Capture the Flag (CTF)
  - Transport

- **AI agents with roles**
  - Leader
  - Advance
  - Tank
  - Support  
  Each role uses a different AI paradigm

- **Agent communication**
  - No communication / limited / full communication.
  - Topological, distance-based, time-based communication modes.
  - Messages include MOVE, ASSIST, FOCUS, STATUS, ROLE, etc.

- **Statistics & replay**
  - KDA, DPS/DTPS, round time, distance travelled.
  - Per-mode metrics (Survival, KOTH, CTF, Transport).
  - Match logs and basic replay system.

---

## Tech Stack

- **Engine:** Godot 4 (standard, *non-.NET* version)
- **Language:** GDScript
- **Version control:** Git (GitLab)
- **Project layout:** Godot project inside `game/` folder

