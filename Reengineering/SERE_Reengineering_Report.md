# Software Re-engineering Report
## Target System: Pharmacy Management System (`D:\SERE\Pharmacy-Management-System`)
### Method baseline: SERE course material (Tripathy & Naik — *Software Evolution and Maintenance*, Ch. 1, 4, 5; Chikofsky & Cross II; Byrne & Gustafson; Lehman; Swanson; ISO/IEC 14764; Chapin et al.; Kazman et al.)

> **Scope note:** This is an **analysis-and-planning deliverable only**. No source code is written, changed, or generated in this document. Every concept below is taken from the supplied course material and **explicitly mapped onto this project**. Tools are **listed only** — free, open-source, none installed or executed.

---

## 1. Purpose of This Report

The project is to be **re-engineered**. The course material defines re-engineering as *"the examination, analysis and restructuring of an existing software system to reconstitute it in a new form, and the subsequent implementation of the new form"* (Chikofsky & Cross II). This report performs the **examination and analysis**, states the **restructuring plan**, and selects the **strategy, approach, migration method and tooling** — so that implementation can be executed later against a defined plan.

Formally, per Jacobson & Lindstorm:

```
Reengineering  =  Reverse Engineering   +   Δ (Alteration)   +   Forward Engineering
                        (↑ abstraction)      (→ change)            (↓ refinement)
```

This report covers the **Reverse Engineering** half in full detail, defines the **Δ**, and specifies the **Forward Engineering** target.

---

## 2. Systems Under Study

### 2.1 The subject system (what we are re-engineering)
| Property | Value |
|---|---|
| Type | 2-tier Java SE **desktop** application (Swing GUI) |
| Language | Java SE **1.8** (`nbproject/project.properties`) |
| Build | **Apache Ant** / NetBeans (+ Eclipse `.classpath`) — no Maven, no Gradle |
| Size | 28 `.java` files ≈ **9,710 LOC**, of which 27 files / ≈9,618 LOC are in a **single package `main`** |
| GUI | Swing/AWT, **NetBeans Matisse** generated; 24 `.form` XML files (≈9,680 lines) |
| Libraries | `mysql-connector-java-5.1.40`, `rs2xml` (DbUtils), `JTattoo-1.6.11`, `AbsoluteLayout` |
| Database | **MySQL / MariaDB 10.1.16**, database `pharmacy`, InnoDB, `latin1` |
| Entry point | `main.Main` → `new Login().setVisible(true)` |
| Documentation | `README.md` only; no design docs, no user manual, no tests, no CI |

### 2.2 The method baseline (the material we apply)
Chapter 1 (basic concepts, evolution & maintenance, legacy systems, impact analysis, refactoring, program comprehension, reuse), Chapter 4 (re-engineering: general model, types of change, strategies, process models, reverse engineering, data reverse engineering, RE tools), Chapter 5 (legacy information systems: solutions, wrapping, migration planning, 7 migration methods), plus the Exam Notes and Study Guide.

---

## 3. Concept Baseline — the vocabulary we will apply

| Concept (source) | One-line meaning used in this report |
|---|---|
| **Re-engineering** (Chikofsky & Cross II) | Examine + alter + re-implement to a new form |
| **Reverse engineering** | Identify components, identify relationships, represent at higher abstraction — **no change** |
| **Δ Alteration** | The actual change (functionality **or** implementation technique) |
| **Forward engineering** | Concept → requirements → design → implementation (↓ refinement) |
| **Abstraction / Refinement** | Hide detail to understand; add detail back to rebuild |
| **Types of change** | Recode · Redesign · Respecify · Rethink |
| **Strategies** | Rewrite (alteration only) · Rework (all three) · Replace (abstraction + refinement) |
| **Approaches** | Big Bang · Incremental · Partial · Iterative · Evolutionary |
| **Phase model** (Byrne & Gustafson) | Analysis & planning → Renovation → Target testing → Redocumentation → Acceptance & transition |
| **Maintenance types** (Swanson / ISO 14764 / Kitchenham / Chapin) | Corrective · Adaptive · Perfective · Preventive (+12-type Chapin taxonomy) |
| **Lehman's 8 laws** | Why quality decays and maintenance budgets are mandatory |
| **Legacy options** (Ch.5) | Freeze · Outsource · Carry-on · Discard & redevelop · **Wrap** · **Migrate** |
| **Migration methods** (Ch.5) | Cold turkey · DB-first · DB-last · Composite DB · Chicken Little · Butterfly · Iterative |
| **Cut-over strategies** | Cut-and-run · Phased interoperability · Parallel operation |
| **RE techniques** (Ch.4) | Lexical · Syntactic · Control-flow · Data-flow · Slicing · Visualization · Metrics |
| **Metrics** (Ch.4) | Henry-Kafura `Cp=fan-in×fan-out`; CK suite (WMC, RFC, LCOM, CBO, DIT, NOC) |
| **Data RE / DBRE** (Ch.4) | Data-structure extraction → conceptualization → normalization |
| **SCORE/RM** (Ch.4) | 8-layer source-code RE reference model (6 RE layers + 3 FE layers + metrication) |
| **Impact analysis** (Ch.1) | Traceability analysis + dependency analysis (call graph / dependency graph); ripple effect; change propagation |
| **Program comprehension** (Ch.1) | Bottom-up / top-down / opportunistic; chunking; cross-referencing |
| **Wrapping** (Ch.5) | DB / system-service / application / function wrappers; 5 encapsulation levels; screen scraping |

---

## 4. PHASE 0 — Portfolio Analysis & Go / No-Go Decision

> Course source: Ch.5 §5.4 Step 1 (portfolio analysis), Step 5 (go/no-go); Exam Notes §3 (portfolio chart).

### 4.1 Portfolio analysis (technical quality × business value)
Ch.5 defines a chi-square chart of **technical quality** vs **business value**. We place the Pharmacy system:

| Axis | Assessment | Evidence |
|---|---|---|
| **Business value** | **High** — it is the operational system for a pharmacy: inventory, purchasing, sales billing, expiry control, user management | `drugs`, `sales`, `purchase`, `history_sales` tables drive daily operations |
| **Technical quality** | **Low** | no layering, SQL injected into every GUI handler, plaintext passwords, hardcoded `root`/blank-password DB credentials, 1,520-line dashboard, zero tests/CI, dead code |

**Result → Quadrant 4 (low technical quality, high business value) = strongest candidate for redevelopment / migration to a new system.** (Quadrant 3 — high/high — would be "actively evolve"; Quadrant 1 — low/low — "replace with commercial product"; Quadrant 2 — high/low — "leave alone".)

### 4.2 Is it a legacy system? (Ch.5 §5.1 "acceptable features")
| Legacy feature (Ch.5) | This system? | Comment |
|---|---|---|
| Large, millions of LOC | ✗ | Small (~9.7k LOC) → **lower migration risk** |
| Geriatric (>10 yrs) / obsolete language | Partial | Java 8 + MySQL Connector/J 5.1.40 are both EOL; Swing tooling is dated |
| Lack of consistent documentation | ✓ | README only; no design/requirement docs |
| Poor data management | ✓ | Denormalized tables; drug name/type/price copied into `sales`/`purchase`/`history_sales`; one orphan table `expiry` |
| Degraded structure after years of modification | ✓ | Duplicated `main()`/`clear()`/`refresh()` in ~15–24 frames; near-identical query methods in `Shift_Sales` |
| Very difficult to expand | ✓ | No layering, global `static` field bus on `Pharmacy` (`username1`, `today`, `ex`, `expired_bar`) |
| Runs on old processor | ✗ | Runs on any JVM, but pinned to Java 8 |

Brodie & Stonebraker: *"any information system that significantly resists modification and evolution to meet new and constantly changing business requirements"* → **the system qualifies** (resists modification: security, architecture, and test barriers).

### 4.3 Decision among the six legacy options (Ch.5 §5.1)
| Option | Verdict | Reasoning |
|---|---|---|
| **Freeze** | ✗ | Business still depends on it; requirements keep changing |
| **Outsource** | ✗ | Not a core-business decision; codebase is small and knowable |
| **Carry on maintenance** | ✗ as end-state | Only a *holding action*; accrues technical debt (Lehman Law 2, 7) |
| **Discard & redevelop** | ✗ (rejected as full rewrite) | Throws away working, business-tested logic; highest risk/effort |
| **Wrap** | △ *optional short-term* | Valid as a stop-gap (see §12) but does not solve the problems |
| **Migrate** | ✅ **SELECTED** | Best when "wrapping is unsuitable and redevelopment is not acceptable due to substantial risk" (Ch.5 §5.3) — retains proven functionality while modernizing qualities |

> **PHASE 0 OUTPUT →** *Go decision*: the system is a **Quadrant-4 legacy system** to be **migrated / re-engineered** (not frozen, not outsourced, not discarded). **Wrap** is retained as a fallback and as an interim bridge.

### 4.4 Why re-engineer rather than just maintain? (four objectives, Ch.4 §1.1)
| Objective (Ch.4) | Concrete target for this project |
|---|---|
| **Improving maintainability** | Break the 2-tier monolith into layers; remove duplication; add tests |
| **Migrating to a new technology** | Java 8 → modern LTS JDK; Swing → modern UI stack; embedded SQL → DAO/JPA; MySQL 5.1 driver → current connector |
| **Improving quality** | Eliminate SQL injection, hardcoded credentials, plaintext passwords; add logging, transactions, pooling |
| **Preparing for functional enhancement** | Restructure first so new features (multi-branch, reporting, POS integration) can be added safely |

---

## 5. PHASE 1 — Analysis & Planning (Byrne & Gustafson, Phase 1)

> Course source: Ch.4 §4.4.3 "Analysis and planning". Three **technical** issues + one **economic** issue, then **planning**.

### Step 1.1 — Understand the present state: Reverse Engineering of the system

We apply the **IEEE 6-step reverse-engineering process** (Ch.4 §4.5):

**Local analysis (Steps 1–3):**
1. **Partition source into modular units** → 27 frames in package `main`, grouped into 8 logical modules:

| # | Module (functional unit) | Frames / classes | Data touched |
|---|---|---|---|
| M1 | Authentication & Session | `Login`, `Change_Password`, `changestyle` | `users`, `login` |
| M2 | Dashboard / Navigation | `Pharmacy` (hub, 1,520 LOC), `Main` | all (read) |
| M3 | Drug Inventory | `Drug`, `Drug_List`, `Search_Drug`, `Move_Drug`, `Edit_Price` | `drugs` |
| M4 | Expiry & Stock Alerts | `Expired_Drug`, `Almost_Finish`, `Warning`, `Warning_List`, `Renew_Validity` | `drugs` |
| M5 | Purchasing | `Buy_Drug` (a.k.a. deal), `All_Deal` | `purchase`, `company` |
| M6 | Sales / Billing | `Sales_Bill`, `Retrieval_Drug` (stub) | `sales`, `history_sales`, `drugs` |
| M7 | Reporting / Audit | `Shift_Sales`, `Login_Details` | `history_sales`, `login` |
| M8 | Messaging | `Inbox`, `Send`, `Show_Message` | `inbox`, `message_history` |
| — | Infrastructure | `Connect` (JDBC helper), `User`, `Company` | — |

2. **Describe meanings & identify functional units** → the table above (each frame = one functional unit, confirmed by its embedded SQL).
3. **Input/output schematics** → per frame: GUI widgets are inputs, JDBC `ResultSet` rows are outputs, DB tables are the external data interface. (`Connect.connect()` is the single DB entry point.)

**Global analysis (Steps 4–6):**
4. **Describe connected units (call/dependency graph)** → `Main → Login → Pharmacy → {all frames}`; `Pharmacy` is the hub, and **cross-frame coupling** exists via `public static` fields (`Pharmacy.username1`, `Login.id`, `Login.NAME`, `Pharmacy.expired_bar`, and `Drug_List` writing into `Pharmacy.drug.*`). Navigation is by **direct instantiation** (`new Sales_Bill().setVisible(true)`), so the dependency/call graph is effectively a star with a global-variable bus.
5. **Describe overall application behaviour** → login (ID+password) → role-based dashboard → CRUD on drugs/company/purchases → POS billing that decrements `drugs.QUANTITY` and appends to `history_sales` → expiry/stock warnings → audit reports → internal messaging.
6. **Create the internal structural model** → the recovered architecture (see §5.3) — a 2-tier client with **no** service/DAO/domain layers.

**Program comprehension strategy (Ch.1 §1.6):** we used an **opportunistic** combination — *bottom-up* from `Connect.java` and the SQL strings, *top-down* from the README's "modules", with **chunking** (grouping frames into M1–M8) and **cross-referencing** (linking GUI actions → SQL → tables).

### Step 1.2 — Identify the need for re-engineering (why now?)

**Maintenance history inference (Swanson + ISO/IEC 14764 + Chapin):** the code shows heavy past *corrective* and *adaptive* patching (near-duplicate methods, per-frame `main()` copies, dead branches), i.e. **"carry on maintenance"** has been the strategy — exactly the pattern Ch.5 warns against.

**Legacy symptoms as drivers of the need:**

| Driver | Concrete evidence |
|---|---|
| **Security exposure** | `Connect.java`: `DriverManager.getConnection("jdbc:mysql://localhost/pharmacy","root","")` |
| **SQL injection (pervasive)** | 102 string-concatenated SQL statements across 21 files, e.g. `"select ... where ID='"+id.getText()+"'"` in `Login.java` |
| **Credential weakness** | plaintext passwords in `users` (`admin/admin`, `mark/mark`, `clark/rootaccess`) |
| **Hidden backdoor / broken gate** | `Pharmacy.java` gates on literal `NAME='Ebrahem Samer'` / `NAME='Syed Ibrahim'`, neither of whom exists in seed data |
| **Maintainability** | 1,520-line `Pharmacy.java`; 7 near-identical `enterX()` visibility methods; duplicated `clear()/refresh()/fill_Username()` |
| **Correctness risks** | `Sales_Bill.get_Total()` accumulates inside the loop; `Login` `if(id.equals("1"))` and `else` are identical; dates stored as `varchar` and parsed with `split("-")` |
| **Dead / stub code** | unused `expiry` table; empty `else{}` in `Retrieval_Drug`; commented-out remnants |
| **No safety net** | `test.src.dir` declared but **no `test/` dir**, no JUnit, no CI (only `stale.yml`) |

**Lehman's laws — how this system behaves (Ch.1 §1.1.1, Notes Topic 2):**
- **Law 1 Continuing Change** — requirements keep arriving (bilingual UI, multi-branch, reporting) → adaptation is mandatory.
- **Law 2 Increasing Complexity** — complexity **has** grown without refactoring (duplication, global state).
- **Law 4 Org. Stability** — a small fixed team can't absorb more scope linearly → we restructure to remove duplication.
- **Law 6 Continuing Growth** — functionality only grows (features rarely shrink) → prepare for enhancement.
- **Law 7 Declining Quality** — perceived quality falls (fragile dates, brittle UI flow) unless design is maintained.
- **Law 8 Feedback System** — the plan below is iterative, with human review loops.
- *(Law 3, 5 are process-level; noted for completeness.)*

**Applicability caveat (material):** Lehman's laws were derived from **closed-source E-type** systems; FOSS studies (Godfrey & Tu; Robles) show Laws 3/4/5 don't fit large OSS. This project is a **closed internal business system**, so the laws apply.

### Step 1.3 — Specify the characteristics of the new (target) system

| Attribute | Current (as-is) | Target (to-be) |
|---|---|---|
| Architecture | 2-tier monolith, no layers | **Layered/N-tier**: presentation → service/domain → DAO → DB |
| UI technology | Swing/Matisse `.form` (untestable) | Modern UI stack (e.g. JavaFX or a web front-end) with MVVM/MVC separation |
| Data access | Inline SQL in event handlers | **DAO/Repository + parameterized SQL / JPA**, connection pool, transactions |
| Configuration | Hardcoded URL/user/password | Externalized config (env/properties), secrets out of code |
| Security | Injection-prone, plaintext pw | Parameterized queries, hashed+salted passwords, least-privilege DB user, RBAC |
| Language/build | Java 8, Ant `.form`, machine-absolute paths | Modern LTS JDK, **Maven/Gradle**, reproducible build |
| Schema | Denormalized, orphan `expiry`, no FKs | **Normalized** schema, proper keys/FKs/constraints, dates as `DATE` |
| Quality gates | none | Unit/integration tests, static analysis, CI |

The abstraction ladder used here is Ch.4 §1.2: **Conceptual → Requirements → Design → Implementation** (refinement: *why? → what? → what & how? → how?*).

### Step 1.4 — Economic analysis (cost & benefit)

| Benefit category | Expected gain |
|---|---|
| Reduced maintenance cost | Removing duplication (24 `main()` copies, ~15 `clear()`, 4 near-identical `Shift_Sales` queries) and adding tests cuts change-cost |
| Risk reduction | Eliminating injection + hardcoded root credentials removes a business-threatening exposure |
| Reduced rework | Layering + DAO makes new features additive, not invasive |
| Reuse (Ch.1 §1.7) | Recovered domain rules (expiry logic, billing math) become reusable components |

**Effort estimation (Ch.5 Step 12): use COCOMO II** — it explicitly addresses *re-engineering work and reuse-driven* projects. Inputs: ≈9.7 kLOC recovered source, small team, reuse of existing domain logic → the scale factors and effort multipliers are computed to yield effort, phase-by-phase schedule and staffing. (The model is the recommended estimator; exact numbers depend on team constants and are out of scope for this planning document.)

### Step 1.5 — Planning (Ch.4 §4.4.3 / Ch.5 §5.4)
- **Scope of work** — modernize architecture + security + schema + build, preserving all business functionality (M1–M8).
- **Resources** — reverse-engineering analyst, Java/DB engineer, tester; the free tooling in §14.
- **Tasks & milestones** — see §17.
- **Effort & schedule** — COCOMO II (§1.4).
- **Risk** — see §15.

> **PHASE 1 OUTPUT →** a validated as-is model (component/connection/behaviour diagrams), a documented list of drivers, a target-system specification, an economic case, and a plan.

---

## 6. PHASE 2 — Renovation (Reverse Engineering → Δ → Forward Engineering)

> Course source: Ch.4 §4.4.3 "Renovation" (representation of the system + representation of external data = **data re-engineering**).

### Step 2.1 — Choose the type(s) of change (Ch.4 §1.3.1)
The four change types operate at increasing depth: **Recode → Redesign → Respecify → Rethink**.

| Type | Applied here? | Concrete change |
|---|---|---|
| **Recode** (implementation level) | ✅ Yes | Java 8 → modern LTS JDK; MySQL Connector 5.1.40 → current driver; rename/format cleanup; **program rephrasing** (refactoring) and possibly **translation** of select frames |
| **Redesign** (design level) | ✅ Yes (core) | **Architectural restructuring** (2-tier → layered); **data-model modification** (normalize schema, add FKs/constraints, real `DATE` types); **algorithmic replacement** (fix `get_Total`, replace fragile date `split()` logic) |
| **Respecify** (requirements level) | ✅ Partially | **Change of form**: informal README → formal UML/requirements + acceptance criteria; **change of scope**: define what is *out* (e.g., drop the dead `expiry` table, drop unused `org.eclipse.wb.swing` helper) |
| **Rethink** (concepts/domain) | ⭕ Deferred optional | Possible future evolution: single-shop desktop → **multi-branch, cloud/web pharmacy platform** (new problem domain). Out of scope for the first re-engineering cycle; noted as a roadmap item. |

### Step 2.2 — Choose the re-engineering strategy (Ch.4 §1.3.2)
Recall: **Rewrite = alteration only**; **Rework = abstraction + alteration + refinement**; **Replace = abstraction + refinement (no explicit alteration)** — the classic GOTO-elimination example.

**Selected: a hybrid — "Rework" for the core, "Replace" for the UI.**

| Layer | Strategy | Why |
|---|---|---|
| Domain logic / data access (SQL, expiry rules, billing) | **Rework** | *Abstract* the logic out of GUI handlers into a service/DAO model (control/data-flow graph), *alter* it there (parameterized queries, transactions), *refine* it back into Java classes |
| Presentation (Swing `.form` frames) | **Replace** | Represent the screen intention at a higher level (use-case/UI model), hide the Swing detail, then *refine* into a new UI stack with the new characteristic (testable MVVM/MVC) built in |
| Build/config | **Rewrite** | Direct same-level replacement: Ant → Maven/Gradle; hardcoded values → properties/env; no abstraction needed |

`Rehosting` (Ch.4 §1.3 — re-engineering with **no feature change**, only quality gains) is the *fallback mode*: if scope must shrink, we rehost (keep features identical, improve efficiency/maintainability only) — this aligns with Ch.5's rule that a migration project should not introduce new functionality, to make equivalence testing possible.

### Step 2.3 — Delta (Δ): the actual alterations
- **Functionality Δ:** none in the first pass (Ch.5: *"new functionality is not to be introduced into the target system in a migration project"*), except fixing genuine defects (billing total, date parsing, dead branches, the broken admin gate).
- **Implementation-technique Δ:** extract DAO/service layer; parameterized SQL; connection pooling; externalized config; RBAC; hashed passwords.

### Step 2.4 — Refactoring catalogue (Ch.1 §1.5)
Refactoring = internal-structure change **preserving observable behaviour** (validated by regression). Targets found in the code:

| Smell | Location evidence | Refactoring |
|---|---|---|
| Duplicated `main()` boilerplate | 24 frames (`Login`, `Drug`, `User`, …) | Remove/centralize into one entry point |
| Duplicated helpers `clear()/refresh()/fill_Username()/company()` | ~15 frames | Extract to shared utility/base class |
| Near-identical visibility methods | 7 × ~42-line `enterX()` in `Pharmacy.java` | Replace with data-driven showing (map role → widgets) |
| Near-identical SQL methods | `help_user/help_user1/help/date_help` in `Shift_Sales.java` | Parameterize into one query method |
| God class | `Pharmacy.java` (1,520 LOC) | Extract dashboard, alert-scan, navigation concerns |
| Raw SQL concatenation | 102 statements / 21 files | Replace with `PreparedStatement` (also fixes injection) |
| Global `static` bus | `Pharmacy.username1/today/ex/expired_bar`, `Login.id/NAME` | Replace with a session/context object + events |
| Dead code | `expiry` table, `Retrieval_Drug` empty `else`, `Login` dead branch | Delete (Reductive maintenance, Chapin) |

### Step 2.5 — Data Reverse Engineering / DBRE (Ch.4 §4.8)
Two-phase DBRE is applied to `pharmacy.sql`:

**(A) Data-structure extraction** — recover the logical schema from the physical one:
- **DMS-DDL text analysis** of `pharmacy.sql` (10 tables: `company`, `drugs`, `purchase`, `sales`, `history_sales`, `users`, `login`, `inbox`, `message_history`, `expiry`).
- **Program analysis** — scan SQL strings in the Java sources to recover integrity constraints implied but not declared (e.g. `drugs.COMPANY_NAME` behaves like an FK to `company.NAME` but has none; `purchase.COMPANY_NAME` does have FK `fkr3`).
- **Data analysis** — inspect values to confirm candidate keys/FKs and functional dependencies.
- **Schema integration** — merge DDL view + program view into one logical schema.

**(B) Data-structure conceptualization:**
- **Basic conceptualization:** *untranslate* optimization constructs; rename cryptic names (`PLACE` really encodes two facts, `"section-place"`); *de-optimize*.
- **Conceptual normalization:** split/merge entities, make `is-a` explicit, standardize names → target conceptual schema.

**Recovered problems and their redesign fixes:**

| Issue found | Redesign fix |
|---|---|
| `sales`, `purchase`, `history_sales` copy drug name/type/dose/price (denormalized) | Reference `drugs` by key; keep only genuinely historical price snapshots where required |
| `drugs` PK = `BARCODE`; `purchase` PK = `BARCODE` | Introduce surrogate keys + real FKs |
| `drugs.COMPANY_NAME` has no FK | Add FK to `company` |
| Dates as `varchar` parsed with `split("-")` | Convert to `DATE`/`DATETIME` |
| `expiry` table unused; `inbox` = `message_history` shape | Drop `expiry`; unify messaging (single table + status) |
| No constraints/triggers | Add `CHECK`/`NOT NULL`/unique + controlled integrity |

> **PHASE 2 OUTPUT →** abstracted models (design + conceptual data model), performed alterations (new architecture/DAO/schema/config), and refined re-implemented code. **This is where implementation happens — not in this document.**

---

## 7. PHASE 3 — Target System Testing (Ch.4 §4.4.3)

- **Foundation:** a *target system test plan* is written **before** renovation (Phase 1), so it can be applied the moment the target exists.
- **Equivalence testing (Ch.5 §5.5.7):** because the first pass must **preserve functionality**, the *same* system-level test cases are run against **old and new** systems; results **must match**. Where they differ, either a defect was introduced (fix it) or a deliberate defect-fix was made (record it as an intentional Δ).
- **Techniques:** reuse the same strategies/tools as normal development — unit, integration, and system testing. Priority test targets: login/auth, purchase posting, sales billing + stock decrement + `history_sales` append, expiry/stock warnings, report generation, messaging.
- **Regression safety:** every refactoring in §2.4 is gated by these tests (refactoring requires preserved observable behaviour).
- **Note (Ch.4):** no new functionality in a migration pass ⇒ testing reduces to equivalence, which is far easier to verify.

---

## 8. PHASE 4 — Redocumentation (Ch.4 §4.4.3)

Two tasks: (i) analyse new source, (ii) create documentation. Documents to write/refresh:

| Document | Action |
|---|---|
| Requirements specification | **Create** (formalized from README + recovered behaviour) |
| Design documentation | **Create** — layering, sequence/class diagrams (`diagram/` already has `ER_diagram.png`, `RelationalSchema.png` → update) |
| Design-decision report (assumptions) | **Create** |
| Configuration docs | **Create** — externalized config, build (Maven/Gradle), run instructions |
| User & reference manuals | **Create** |
| On-line help | **Create** |
| Existing-vs-target differences report | **Create** (required by Ch.4) |

Also produced during Phase 1 but formally finalized here: the **call/dependency graphs**, **ER/conceptual schema**, and **metric baselines**.

---

## 9. PHASE 5 — Acceptance & System Transition (Ch.4 §4.4.3)

- **Acceptance criteria** were fixed at project start (Phase 1); the system is accepted only if it passes them.
- **Transition** follows the pre-written **transition plan**; on acceptance the new system goes live and the old one is retired.
- **Cut-over strategy (Ch.5 §5.3):** three options —

| Strategy | Meaning | Fit here |
|---|---|---|
| Cut-and-Run | switch off old, turn on new | ✗ too risky for a live pharmacy |
| **Phased Interoperability** | cut over in incremental steps | ✅ **Recommended** |
| **Parallel Operation** | both run together until new is trusted | ✅ **Recommended as the safety phase** |

> **Recommended transition:** *Parallel operation* first (old and new run side-by-side, outputs compared) → then *phased* cut-over module-by-module (M6 Sales → M5 Purchasing → M3 Inventory → …) → retire legacy.

---

## 10. Deployment Approach Selection (Ch.4 §1.4.1 / Ch.5 §5.4 Step 10)

| Approach | Mechanism | Verdict for this project |
|---|---|---|
| Big Bang | replace whole system at once | ✗ high risk; system is live and business-critical |
| Incremental | reengineer step-by-step, release interim versions | ✅ good — one module at a time |
| Partial | reengineer only selected parts, integrate back | ✅ good for a **first** cycle (modernize core: auth + data layer) |
| **Iterative** | a few procedures at a time; four component states coexist | ✅✅ **RECOMMENDED PRIMARY** — matches Ch.5 Iterative method (§11) |
| Evolutionary | group components **by function** across the whole system, reengineer as cohesive units | ✅ recommended for a **later** wave (e.g. "all reporting functions", "all expiry functions") |

> **Selection:** **Iterative** as the primary approach (keeps the pharmacy operational throughout, preserves user/maintainer familiarity, allows slow migration with equivalence tests), with a **Partial** first increment (the high-risk data-access + authentication core) and **Evolutionary** grouping for subsequent waves.

---

## 11. Migration Method Selection (Ch.5 §5.5)

| Method | Suits | Verdict |
|---|---|---|
| Cold Turkey (Big Bang) | small, stable, well-defined | △ system is small but business-live |
| **Database First (forward migration)** | **fully decomposable** systems with a clean DB interface | ✅✅ **RECOMMENDED FIRST** — the app's DB access funnels through `Connect.java` + JDBC, so the DB interface is clean |
| Database Last | fully decomposable | △ alternative |
| Composite Database | all decomposability levels; dual DB + coordinator | △ heavier |
| Chicken Little | all levels; gateway-based, 11-step | △ variant of composite |
| Butterfly | no concurrent dual-DB access | △ complex; strong for huge data |
| **Iterative** | component-at-a-time; 4 component states | ✅✅ **RECOMMENDED** alongside DB-First |

Decomposability assessment (Ch.5 §5.5.2): interfaces (Swing frames) and applications (SQL logic) are intertwined, but the **database service** is cleanly separated via JDBC → the system is **largely decomposable at the DB boundary**, which is exactly what *Database-First* requires.

**Recommended migration path (Iterative, Ch.5 §5.5.7), stage by stage:**
1. **Analyze legacy system** → partition into components minimising client–supplier coupling (M1–M8).
2. **Classify data** → **primary** (drugs, sales, purchases, users, company) vs **residual** (unused `expiry`, redundant columns).
3. **Redesign database** → normalized New DB + **Metadata**.
4. **Restore legacy components** → route all data access through a **Data Banker** (replacing direct JDBC in frames) instead of touching data directly.
5. **Migrate data** → primary data → New DB; residual → Residual DB.
6. **Reengineer procedures** → evolve components from *restored* → *reengineered* state.
7. **Equivalence tests** after each restoration/data migration.
8. **Iterate** over remaining components.
9. **Empty Residual DB → Clean Metadata → Reconstruct documentation.**

(Data conversion itself = **ETL**: *Extract → Transform (+clean/scrub) → Load*, Ch.5 §5.3.)

---

## 12. Wrapping — Option & Stop-gap (Ch.5 §5.2)

Wrapping encapsulates the legacy component behind a new interface without fixing internals. **Not the chosen end-state**, but useful (a) as an interim bridge during iterative migration, and (b) if scope must be cut.

| Wrapper type (Orfali et al.) | Applicability here |
|---|---|
| **Database wrappers** (forward `f` / backward `b`) | ✅ **Both relevant** — the *forward wrapper* adds new components while translating legacy data/queries; the *backward wrapper* migrates data first, legacy reads new data via wrapper (this is exactly *Database-First*) |
| **System-service wrappers** | △ minor |
| **Application wrappers** | ✅ wrap a whole frame/transaction (e.g. expose `Sales_Bill` as a service) |
| **Function wrappers** | ✅ expose individual recovered functions (e.g. expiry check, price calc) |

**Levels of encapsulation (Sneed): procedure < module < program < transaction < process.** For this project the practical target is **program/transaction level** (wrap whole screens/use-cases behind a service facade). **Screen scraping** (Ch.5 §5.2.5) is explicitly a **short-term** GUI-on-legacy tactic and is noted as a *not-recommended* substitute for real re-engineering.

---

## 13. Metrics, Impact Analysis & Reverse-Engineering Techniques

### 13.1 Metrics to establish before/after baselines (Ch.4 §4.6.7)
| Metric | Use here |
|---|---|
| **Henry-Kafura `Cp = fan-in × fan-out`** | Quantify `Pharmacy`'s coupling (hub frame ⇒ very high `Cp`) |
| **Cyclomatic complexity** | Flag the biggest event handlers |
| **CK suite: WMC** | `Pharmacy` will have the largest WMC |
| **CK suite: RFC** | Response sets of frames |
| **CK suite: LCOM** | Demonstrate low cohesion in multi-purpose frames |
| **CK suite: CBO** | Count non-inheritance couplings (global `static` bus inflates this) |
| **CK suite: DIT / NOC** | Expect ~0 (no inheritance anywhere) |
| **LOC** | ≈9,710 baseline; track reduction after refactoring |
| **Clone detection metrics** | Find the duplicated `main()/clear()/refresh()` sets |

*(SCORE/RM metrication element: metrics are captured **before and after each layer** — this is how improvement is quantified.)*

### 13.2 Impact analysis (Ch.1 §1.4)
- **Traceability analysis** — link recovered requirements ↔ design ↔ code ↔ tests so a change request maps to the exact frames/SQL to touch.
- **Dependency (source-code) analysis** —
  - **Call-graph-based:** `Main → Login → Pharmacy → frames` (static call graph of the star topology).
  - **Dependency-graph-based:** frame → table dependencies from the embedded SQL (e.g. `Sales_Bill → sales, drugs, history_sales`).
- **Ripple effect** — measure how far a change to `Connect` or `drugs` propagates; the high fan-in of `Connect.java` (every frame depends on it) means changes there ripple everywhere → a reason to abstract it early.
- **Change propagation** — ensure the changed data model is propagated consistently to every frame that reads `drugs`/`sales`.

### 13.3 Reverse-engineering techniques applied (Ch.4 §4.6)
| Technique | Application |
|---|---|
| **Lexical analysis** | Tokenise sources to inventory identifiers/SQL literals |
| **Syntactic analysis** | Build ASTs of Java frames to find duplicated blocks |
| **Control-flow analysis** | Intra-procedural CFGs of big handlers; inter-procedural **call graph** of frames |
| **Data-flow analysis** | Find unused variables, unclosed `Connection`s, def/use anomalies |
| **Program slicing** | Backward slice on a table column (e.g. `drugs.QUANTITY`) to find every statement that affects stock |
| **Visualization** | Render call graph, CBO graph, ER diagram |
| **Program metrics** | §13.1 |

### 13.4 The Goals/Models/Tools paradigm (Ch.4 §4.5, Benedusi et al.)
- **Goals** — *why* are we reverse-engineering? (understand legacy → redesign safely). Information needs & abstraction levels fixed.
- **Models** — the representation models (call graph, ER/conceptual model, extracted business rules), chosen for expressive power, language independence, compactness, granularity.
- **Tools** — identified in §14.

---

## 14. Tooling — Free Tools, Listed Only (not installed, not run)

> Per instruction: **listed only**, all **free**, **no installation/setup performed**. Tools are grouped by the phase that consumes them.

### 14.1 Reverse engineering / program comprehension
| Tool | License | Purpose |
|---|---|---|
| **JD-GUI** | Free | Java decompiler for inspecting `dist/Pharmacy.jar` |
| **CFR** | Free (MIT) | Modern Java decompiler (readable source from bytecode) |
| **Sourcetrail** | Free (open, archived) | Interactive source explorer / call & reference graph |
| **JQAssistant** | Free | Scans Java + DB, builds a queryable graph (Neo4j) |
| **Graphviz** | Free (EPL) | Renders call graphs / dependency graphs |
| **PlantUML** | Free | Text-to-diagram (class, sequence, component, ER) |
| **Structurizr** (Lite) | Free | C4 architecture diagrams as code |

### 14.2 Metrics & static analysis
| Tool | License | Purpose |
|---|---|---|
| **PMD** | Free (BSD) | Duplicate-code + rule-based smells |
| **Checkstyle** | Free (LGPL) | Coding-standard / structure checks |
| **SpotBugs** | Free (LGPL) | Bytecode bug patterns |
| **CKJM-extended** | Free | Computes the **CK suite** (WMC, RFC, LCOM, CBO, DIT, NOC) |
| **SourceMonitor** | Free | LOC, complexity, function metrics |
| **CodeCharta** | Free | Visualization of metrics/coupling |
| **JaCoCo** | Free (EPL) | Code-coverage (for the new test suite) |
| **SonarQube (Community)** | Free | Aggregate quality dashboard |

### 14.3 Refactoring & modernization
| Tool | License | Purpose |
|---|---|---|
| **IntelliJ IDEA Community** | Free | Automates the §2.4 refactorings |
| **Eclipse JDT** | Free (EPL) | Refactoring/analysis IDE (project already has `.classpath`) |
| **OpenRewrite** | Free (Apache-2.0) | Recipe-driven Java 8→LTS, dependency & API migration |
| **RefactoringMiner** | Free (MIT) | Detects and documents refactorings between versions |
| **Error Prone** | Free (Apache-2.0) | Compile-time bug prevention |
| **japicmp** | Free | API binary/source compatibility checking |
| **Spring Boot Migrator / Eclipse Transformer** | Free | Framework/namespace modernization recipes |

### 14.4 Data reverse engineering & DB migration
| Tool | License | Purpose |
|---|---|---|
| **SchemaSpy** | Free (LGPL) | Generates DB schema docs + ER from `pharmacy.sql` |
| **SchemaCrawler** | Free (LGPL) | Schema/metadata extraction & diff |
| **MySQL Workbench** | Free (Community) | Reverse-engineer ER from the live DB; forward-engineer target schema |
| **DBeaver CE** | Free (Apache-2.0) | Universal DB client; data profiling & ETL assistance |
| **Liquibase / Flyway (Community)** | Free | Versioned schema migration scripts (schema conversion) |
| **Pentaho Data Integration (CE)** / **Apache Hop** | Free | ETL for data conversion (extract-transform-load) |
| **Jailer** | Free | Data subsetting/export for test data |

### 14.5 Testing & equivalence
| Tool | License | Purpose |
|---|---|---|
| **JUnit 5** | Free (EPL) | Unit/equivalence tests |
| **AssertJ** | Free (Apache-2.0) | Readable assertions |
| **Testcontainers** | Free (MIT) | Throwaway MySQL container for integration tests |
| **ApprovalTests** | Free | Golden-master / output-equivalence checks (ideal for old-vs-new comparison) |
| **H2 / MariaDB4j** | Free | In-memory/embedded DB for fast tests |
| **jqwik** | Free | Property-based testing |

### 14.6 Build, dependencies & security
| Tool | License | Purpose |
|---|---|---|
| **Apache Maven / Gradle** | Free | Reproducible build (replace Ant + machine-absolute paths) |
| **OWASP Dependency-Check** | Free | Flags vulnerable old JARs (e.g. Connector/J 5.1.40) |
| **Snyk (free tier)** | Free tier | Dependency vulnerability scanning |
| **GitHub Actions** | Free (public) | CI to run the new tests (project has only `stale.yml` today) |

### 14.7 Legacy reference tools named in the course material (Ch.4 §4.9)
These are the classical RE tools from the slides — listed for academic mapping, **not installed**: **Rigi**, **Imagix 4D**, **ManSART**, **PBS (Portable Bookshelf)**, **CodeCrawler**, **DMS**, **McCabe IQ**, **RE-Analyzer**, **FermaT**, **JAD**, **IDA Pro/Hex-Rays** (commercial), **IRAP/DMS/GXL**.

> **Tooling principle from Ch.4 §4.9:** *tools only support, never fully automate, reverse engineering* — human judgement (expert knowledge + existing docs) is always required.

---

## 15. Risk Register & Effort

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Introducing defects while refactoring | Med | High | Equivalence tests (§7) before/after each step |
| R2 | Data loss during migration | Low | High | ETL with cleaning + parallel-run comparison; backups |
| R3 | Business disruption during cut-over | Med | High | Iterative approach + parallel operation (§9, §10) |
| R4 | Scope creep (adding features during migration) | Med | Med | Enforce "no new functionality" rule (Ch.5 §5.3) |
| R5 | Team unfamiliarity with legacy logic | Med | Med | Program comprehension + redocumentation (§5.1, §8) |
| R6 | Hidden dependencies via global `static` state | High | Med | Impact analysis / call graph (§13.2); remove the static bus early |
| R7 | Old library vulnerabilities | Med | Med | Dependency-Check; upgrade driver/JDK |
| R8 | Cost/schedule overrun | Med | Med | COCOMO II estimate + iterative checkpoints |

**Effort:** estimated with **COCOMO II** (Ch.5 Step 12), which is the model the material recommends for re-engineering/reuse-driven work. Schedule and staffing are then derived per phase/activity.

---

## 16. Master Concept → Project Mapping Matrix

| Course concept (source) | Where it applies in this project |
|---|---|
| Evolution vs maintenance (Ch.1 §1.1) | The system has only ever been *maintained*; this project is its first true *evolution* |
| Lehman Laws 1,2,6,7 (Ch.1 §1.1.1) | Rising complexity, growing scope, declining quality → justify this project |
| Swanson / ISO 14764 / Kitchenham / Chapin (Ch.1 §1.2) | Classifies the past maintenance (corrective/adaptive) and the planned work (preventive, reductive, enhancive) |
| Re-engineering definitions (Ch.1 §1.3) | Chikofsky/Byrne/Arnold all apply — *improve comprehension + quality* |
| Legacy options (Ch.1 §1.3, Ch.5 §5.1) | **Migrate** selected; **Wrap** as bridge |
| Impact analysis (Ch.1 §1.4) | Call-graph + dependency-graph on the frame→table topology; ripple via `Connect` |
| Refactoring (Ch.1 §1.5) | §2.4 catalogue (duplication, god class, dead code) |
| Program comprehension (Ch.1 §1.6) | Opportunistic bottom-up/top-down, chunking M1–M8 |
| Software reuse (Ch.1 §1.7) | Reuse recovered billing/expiry rules as components |
| General model & Horseshoe (Ch.4 §1.2–1.3) | RE (up) → Δ (horizontal) → FE (down); Kazman's horseshoe for the architecture |
| Types of change (Ch.4 §1.3.1) | Recode + Redesign + Respecify (Rethink deferred) |
| Strategies (Ch.4 §1.3.2) | Rework (core) + Replace (UI) + Rewrite (build/config) |
| Approaches (Ch.4 §1.4.1, Ch.5) | Iterative primary, Partial first slice, Evolutionary later |
| SCORE/RM (Ch.4 §1.4.2) | 8-layer RE/FE framework with metrication before/after |
| Phase model (Ch.4 §4.4.3) | The 5-phase spine of this report (§5–§9) |
| Code RE (Ch.4 §4.5) | IEEE 6 steps performed in §5.1 |
| RE techniques (Ch.4 §4.6) | §13.3 (lexical→metrics) |
| Metrics (Ch.4 §4.6.7) | §13.1 (CK suite, Henry-Kafura) |
| Data RE / DBRE (Ch.4 §4.8) | §2.5 (extraction + conceptualization) |
| RE tools (Ch.4 §4.9) | §14.1 & §14.7 |
| Wrapping & encapsulation (Ch.5 §5.2) | §12 (DB wrappers, program/transaction level) |
| Solutions to LIS (Ch.5 §5.1) | §4.3 (Migrate chosen) |
| Migration planning 13 steps (Ch.5 §5.4) | §5.2–§5.5 & §17 (steps mapped 1-to-1) |
| Migration methods (Ch.5 §5.5) | §11 (Database-First + Iterative) |
| Cut-over strategies (Ch.5 §5.3) | §9 (parallel → phased) |
| COCOMO II (Ch.5 Step 12) | §1.4 / §15 effort estimation |

---

## 17. Deliverables & Milestone Plan

| Phase | Key deliverables | Exit criteria |
|---|---|---|
| **0. Portfolio & decision** | Portfolio chart; go/no-go memo | Migration approved |
| **1. Analysis & planning** | As-is component/connection/behaviour model; driver list; target-system spec; business case; COCOMO II estimate; test plan; transition plan | Baseline metrics & acceptance criteria fixed |
| **2. Renovation** | Layered architecture; DAO/service layer; normalized schema + migration scripts; externalized config; refactoring catalogue executed | Target system buildable & runnable |
| **3. Target testing** | Equivalence test results (old vs new); defect log | Old ≡ new (or intentional Δs documented) |
| **4. Redocumentation** | Requirements, design, config, user/reference manuals, differences report, updated ER/UML diagrams | Documentation complete |
| **5. Acceptance & transition** | Acceptance test report; parallel-run evidence; phased cut-over; legacy retired | New system accepted & live |

---

### Appendix A — Evidence index (file:line highlights)
- Hardcoded credentials: `Connect.java` (`jdbc:mysql://localhost/pharmacy`, `root`, blank password).
- SQL injection examples: `Login.java` (login query), `User.java` (insert/update/delete), `Drug.java`, `Sales_Bill.java`, `Search_Drug.java` (`REGEXP`).
- God class: `Pharmacy.java` (~1,520 LOC; `initComponents` + 7 duplicated `enterX()` methods).
- Backdoor/broken gate: `Pharmacy.java` literal-name checks (`Ebrahem Samer`, `Syed Ibrahim`).
- Dead/stub: `Retrieval_Drug.java` empty `else`; unused `expiry` table; `Login.java` identical if/else.
- Correctness bugs: `Sales_Bill.get_Total()` accumulation in loop; `varchar` dates parsed with `split("-")`.
- Missing tests/CI: `nbproject` declares `test.src.dir` but no `test/`; `.github/workflows/` = `stale.yml` only.
- Machine-absolute paths: `nbproject/project.properties`, `nbproject/private/private.properties`.

*End of report.*
