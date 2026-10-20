# Re-engineering Package — Index

Everything produced for the **Software Re-engineering** of the Pharmacy Management System lives
in this folder. The legacy application itself (`src/`, `pharmacy.sql`, the original `diagrams/`)
is left **untouched**; all re-engineering artifacts are collected here for tracking.

## Folder layout

```
Pharmacy-Management-System/
├── src/ , build/ , lib/ , nbproject/        ← LEGACY application (unchanged)
├── pharmacy.sql                             ← LEGACY database dump (unchanged)
├── diagram/                                 ← LEGACY reference images (unchanged)
└── Reengineering/                           ← ALL re-engineering work
    ├── README.md                            ← this index
    ├── PROJECT_OVERVIEW.md / .docx          ← what it does now + legacy requirements
    ├── SERE_Reengineering_Report.md / .docx ← full re-engineering report (concepts, plan)
    ├── ALTERATION_DOCUMENT.md / .docx       ← the Δ (alterations, strategies, why)
    ├── SRS_Target_System.md / .docx         ← SRS of the new system (incl. new features)
    ├── TARGET_DESIGN.md (+ .docx)           ← design of the new (to-be) system
    ├── Design_Document.md / .docx           ← original design/requirements document
    ├── target_schema.sql                    ← target (to-be) schema v1 (design DDL)
    └── diagrams/
        ├── 01..07_*.drawio                  ← original design diagram set (kept)
        ├── current_system/                  ← AS-IS diagrams (reverse-engineered)
        │   ├── 01_database_schema_diagram.drawio
        │   ├── 02_current_system_diagram.drawio
        │   ├── 03_use_case_diagram.drawio
        │   ├── 04_sequence_diagram.drawio
        │   ├── 05_flowcharts.drawio
        │   ├── 06_module_diagram.drawio
        │   └── README.md (Mermaid renderings)
        └── target_system/                   ← TO-BE diagrams (new design)
            ├── 01_target_database_schema.drawio
            ├── 02_target_system_architecture.drawio
            ├── 03_target_dfd.drawio
            ├── 04_target_flowcharts.drawio
            ├── 05_target_use_case.drawio
            ├── 06_target_designs.drawio
            └── README.md (Mermaid renderings)
```

## Documents

| Document | What it contains | Read it for |
|---|---|---|
| `PROJECT_OVERVIEW.md` | What the system performs **now** + its recovered **legacy requirements** (FR-01…FR-14) | The starting point / as-is |
| `SERE_Reengineering_Report.md` | Full re-engineering report: portfolio analysis, reverse engineering, concepts, strategy, migration plan, tooling | The theory + method mapping |
| `ALTERATION_DOCUMENT.md` | The **Δ** — 27 alterations, change types, strategies (Rework/Replace/Rewrite), refactorings, **why** each change is needed | What we will change and why |
| `SRS_Target_System.md` | Formal **SRS** of the new system: FR-01…FR-29 (incl. the new features), NFRs, data, traceability, verification | The target requirements |
| `TARGET_DESIGN.md` | Design of the new system: architecture, components, data design, processes, behaviour, decisions | How the new system is designed |
| `Design_Document.md` | Original design/requirements document (baseline) | Earlier design context |
| `target_schema.sql` | Target schema v1 (normalised core) — reference DDL | The normalised data model |

**Suggested reading order:** PROJECT_OVERVIEW → SERE_Reengineering_Report → ALTERATION_DOCUMENT
→ SRS_Target_System → TARGET_DESIGN → the diagrams.

## Diagrams

- **`diagrams/current_system/`** — the **as-is** system (database schema, current architecture,
  use case, sequence, flowcharts, module diagram). See its `README.md` for Mermaid versions.
- **`diagrams/target_system/`** — the **to-be** system (new database schema, architecture, DFD,
  flowcharts, use case, class/sequence/state designs). See its `README.md` for Mermaid versions.
- **`diagrams/01..07_*.drawio`** — the original design diagram set, retained unchanged.

Open any `.drawio` file at <https://app.diagrams.net> (Open Existing Diagram), in the draw.io
desktop app, or with the VS Code *Draw.io Integration* extension; export to PNG/SVG/PDF for the
report.

## Notes on overlapping diagram files

The original set (`diagrams/02_target_ER_diagram.drawio`, `03_target_architecture.drawio`,
`05_use_case_requirements.drawio`) covers *target* views that the new **`target_system/`** set
now supersedes in more detail. They are **retained** (not deleted) so the original submission
stays intact — treat `target_system/` as the authoritative to-be design.

## Delivery status

| Aspect | As-is | To-be |
|---|---|---|
| Architecture | 2-tier Swing monolith | Layered/N-tier + REST API (desktop/web/mobile) |
| Database | 10 flat tables, 1 FK, `latin1` | 22 normalised tables, full FKs, `utf8mb4` |
| Scope | single shop | **multi-branch** |
| Features | inventory, purchase, POS, warnings, reports, messaging | + returns, prescriptions, loyalty, analytics, notifications, PO approval, barcode, tax invoicing, backup, strong auth |
| Requirements | implicit (recovered) | formal SRS (FR-01…FR-29) |
