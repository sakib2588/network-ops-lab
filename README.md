# Wazuh SOC Home Lab — Nazmus Sakib

**Owner:** Nazmus Sakib (23-52638-2) | AIUB BSc CSE Final Year  
**Started:** June 2026 | **Target completion:** Aug 31, 2026  
**Purpose:** Internship portfolio (SOC Analyst / Security Analyst) + Thesis foundation

---

## Project Goal

Build a functional Security Operations Center (SOC) home lab using Wazuh SIEM, demonstrating real-world threat detection, incident response, and detection engineering skills — entirely on personal hardware.

---

## Hardware Inventory

| Device | Role | Specs | Status |
|---|---|---|---|
| Laptop | Wazuh Server (SIEM) | 12GB RAM, Ubuntu 24.04 | Active |
| PC 1 (Ubuntu) | Linux Agent | 16GB RAM, dual-boot | Active |
| PC 2 | Windows Agent | 4GB RAM, Windows 10 | Active |
| PC 1 (Windows) | Windows Agent 2 | 16GB RAM | Boot when needed |
| Raspberry Pi 4 | Network Sensor (Suricata) | 4GB RAM | Setup this week |

---

## Phase Overview

| Phase | Focus | Status | Target |
|---|---|---|---|
| Phase 0 | Environment Setup | Done | Done |
| Phase 1 | Wazuh Deployment | Done | Done |
| Phase 2 | Log Ingestion (4 nodes) | Done | Done |
| Phase 3 | Threat Simulation | In Progress | June 28 |
| Phase 4 | Detection Engineering | Not started | July 18 |
| Phase 5 | Investigation Playbooks | Not started | Aug 1 |
| Phase 6 | Portfolio Documentation | Not started | Aug 20 |
| Phase 7 | Raspberry Pi — Network Sensor | In Progress | June 21 |

> RPi moved from Phase 7 to run in parallel with Phase 3 — device available now.

---

## Folder Structure

```
Cyber Security Project/
├── README.md                      ← this file
├── PROJECT_STATUS.md              ← current progress tracker
├── docs/
│   ├── SOC_Lab_Project_Plan.md   ← master plan (full timeline)
│   ├── guides/
│   │   ├── Full_Implementation_Guide.md
│   │   ├── Blue_Team_Home_Lab_Guide.md
│   │   ├── Blue_Team_Lab_Phases_2-7_Complete_Guide.md
│   │   └── Quick_Command_Reference.md
│   └── references/
│       ├── Architecting_Blue_Team_Home_Lab.pdf
│       └── Beyond_Alert_Chasing.pdf
├── phases/
│   ├── phase0_environment_setup/
│   ├── phase1_wazuh_deployment/
│   ├── phase2_log_ingestion/
│   ├── phase3_threat_simulation/
│   ├── phase4_detection_engineering/
│   ├── phase5_investigation_playbooks/
│   ├── phase6_portfolio/
│   └── phase7_raspberry_pi/       ← RPi setup guide here
├── incidents/                     ← incident reports (portfolio evidence)
├── rules/                         ← custom Wazuh detection rules
└── portfolio/
    └── screenshots/               ← dashboard screenshots for CV/LinkedIn
```

---

## Portfolio Value

This lab demonstrates:
- Wazuh SIEM deployment and management
- Multi-platform agent configuration (Linux + Windows)
- Network-based intrusion detection (Suricata on RPi)
- Custom detection rule writing (YAML/XML)
- Incident investigation and playbook writing
- Real threat simulation (nmap, hydra, Metasploit)

Directly targeted at: **SOC Analyst**, **Security Analyst**, **Junior Cybersecurity roles** in Bangladesh.

---

## Links

- Master Plan: `docs/SOC_Lab_Project_Plan.md`
- Current Status: `PROJECT_STATUS.md`
- RPi Setup: `phases/phase7_raspberry_pi/RPi_Suricata_Setup.md`
- Quick Commands: `docs/guides/Quick_Command_Reference.md`
