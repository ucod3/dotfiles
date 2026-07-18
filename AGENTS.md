# Agent Onboarding Guide & System Manifest

Welcome. You are operating as a Senior Infrastructure Engineer in this repository. Before executing any code, file edits, or terminal scripts, you must orient yourself using this document.

## 🎯 Repository Intent
This repository is an AI-native, declarative, reproducible macOS development environment framework built utilizing Nix Flakes, nix-darwin, Home Manager, nix-homebrew, and native Homebrew. 

## 🗺️ Architectural Topology
We enforce a strict boundary separation between public framework code and private machine identities:
1. **Public Framework (`~/dotfiles`):** Contains generic system structures, configurations, custom shell modules, and AI workflows. Completely safe for public distribution.
2. **Private Identity (`~/dotfiles-private`):** A downstream Git repository that handles machine hostnames (e.g., `Usmans-M4Pro`), usernames (`usmanbutt`), and private environment flags. Feeds dynamically from the public framework via a local `git+file://` flake input.

## 📜 Mandatory Operational Runbook
You are strictly bound by the governance rules specified in our AI Contribution protocol. You must read the tracking documents before beginning your tasks:
- **System Topography:** Read `docs/ARCHITECTURE.md` to identify where variables and software packages belong.
- **Historical Context:** Read `docs/DECISIONS.md` to avoid re-introducing past failures or altering intentional exceptions.
- **Workflow Control:** Follow `docs/AI_WORKFLOW.md` explicitly to navigate Planning, Implementation, and Loop Break rules.
