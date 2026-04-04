# Admin Tools

Internal IT administration toolkit — lightweight tools, assistants, and utilities that help the IT team move faster and stay consistent.

---

## Tools

<table>
  <tr>
    <td width="50%" valign="top">
      <h3>AssistAI</h3>
      <p><strong>AI-powered onboarding assistant</strong> that parses HR emails and Spiceworks tickets and generates a structured IT checklist. Stateless by design (no server-side storage).</p>
      <p><a href="./assist-ai/"><strong>Open tool →</strong></a></p>
      <ul>
        <li>Ollama + LLM parsing</li>
        <li>Rules-driven checklists (<code>onboarding_rules.yml</code>)</li>
        <li>Ephemeral session tracking (browser-only)</li>
      </ul>
      <p><em>Status:</em> 🚧 In development</p>
    </td>
    <td width="50%" valign="top">
      <h3>TenantOps</h3>
      <p><strong>Tenant administration utilities</strong> (PowerShell) for day-to-day M365 / hybrid operations.</p>
      <p><a href="./tools/TenantOps/"><strong>Open tool →</strong></a></p>
      <ul>
        <li>Operator-friendly scripts</li>
        <li>Repeatable admin workflows</li>
        <li>Designed for tech handoff</li>
      </ul>
      <p><em>Status:</em> ✅ Active</p>
    </td>
  </tr>
</table>

---

## Repository Layout

```
admin-tools/
├── assist-ai/              # AI onboarding assistant
└── tools/
    └── TenantOps/          # Tenant admin utilities (PowerShell)
```

---

## Standards (Important)

- **No secrets:** never commit passwords, tokens, key files, or credential exports.
- **No PII storage:** tools should avoid persisting employee data unless explicitly approved.
- **Documentation-first:** each tool includes its own `README.md` with install + usage.

---

## Quick Start

Each tool is self-contained. Go to the tool directory and follow its README:

- AssistAI: [`./assist-ai/README.md`](./assist-ai/README.md)
- TenantOps: browse scripts in [`./tools/TenantOps/`](./tools/TenantOps/)

---

## Roadmap

- **AssistAI**
  - [ ] Multi-company refinements (NVS / AURA Domestic / AURA International)
  - [ ] SOP Finder (guided “how-to” + document pointers)
  - [ ] Optional auth if/when we add access to sensitive internal resources

- **TenantOps**
  - [ ] Standardize output/logging format
  - [ ] Add parameter validation + usage examples

---

## Internal Use

This repository is intended for internal IT operations. External distribution is not planned.
