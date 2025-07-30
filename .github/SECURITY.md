# Security Policy

## 📋 Supported Versions

This is a personal dotfiles repository intended primarily for personal use and sharing configurations.  
There is **no official support**, but I welcome reports of genuine security issues.

---

## 🚨 Reporting a Vulnerability

If you discover a **security vulnerability** (e.g., credentials accidentally committed, dangerous default configuration, insecure scripts):

- **Please DO NOT open a public GitHub issue.**
- Instead, contact me **privately**:
  - Email: `victormuthiani@proton.me`
  - Or via GitHub direct message

I will review your report and respond as soon as possible.

---

## ✅ Best Practices & Scope

These dotfiles may include:
- Shell scripts, aliases, and functions
- Configuration for editors, terminals, and tools
- Personal themes and aesthetic customizations

They **should NOT** contain:
- Hardcoded API tokens, passwords, or sensitive data
- Secrets in config files

If you notice secrets or credentials committed by mistake, please report privately as above so they can be removed promptly.

---

## 🔐 Recommendations for Users

If you fork or clone this repository:
- Review all scripts before running them on your machine
- Store personal secrets (API keys, tokens, passwords) in secure secret managers (e.g., `pass`, `bw`, `1Password`) — never in plaintext configs
- Keep your local copy updated with `git pull`

---

## 📜 Disclaimer

This repository is provided **as-is**. Use at your own risk.  
I do my best to avoid insecure defaults, but you should always review and adapt configs for your own system and threat model.

