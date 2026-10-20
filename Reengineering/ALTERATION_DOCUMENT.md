# Alteration (Δ) Document
## Pharmacy Management System — Software Re-engineering

| | |
|---|---|
| **System** | Pharmacy Management System (`D:\SERE\Pharmacy-Management-System`) |
| **Document** | Alteration (Δ) specification — **what we will change, how, and why** |
| **Deliverable type** | Design/planning document (no source code is modified by this document) |
| **Method baseline** | Tripathy & Naik, *Software Evolution and Maintenance* — Ch.1 (concepts, refactoring), Ch.4 (re-engineering, types of change, strategies, reverse/data engineering), Ch.5 (legacy systems, migration) |
| **Companion documents** | `PROJECT_OVERVIEW.md`, `SERE_Reengineering_Report.md`, `Design_Document.md`, `target_schema.sql`, `TARGET_DESIGN.md`, `SRS_Target_System.md` |

---

## 0. Purpose and Scope

Re-engineering is formally:

```
Re-engineering  =  Reverse Engineering  +  Δ (Alteration)  +  Forward Engineering
                        (↑ abstraction)      (→ change)             (↓ refinement)
```

`PROJECT_OVERVIEW.md` captured the **reverse-engineering (as-is) half**. This document specifies the
**Δ — the actual alteration** — that transforms the recovered model into the target model, before
forward engineering refines it back into code.

It answers four questions:

1. **What** are we altering? (Sections 4–6)
2. **Which re-engineering concepts, change types and strategies** do we use? (Sections 2–3)
3. **Which parts** of the system are touched, and which are left alone? (Sections 4, 7)
4. **Why** is each alteration necessary? (Section 8)

---

## 1. Where Alteration Sits in the Model

### 1.1 The three principles

| Principle | Direction | Meaning | Where used here |
|---|---|---|---|
| **Abstraction** | ↑ upward | Replace detail with abstract information to understand | Reverse engineering (examination only) |
| **Alteration (Δ)** | → horizontal | Change a representation **at the same abstraction level** | **This document** |
| **Refinement** | ↓ downward | Replace abstract aspects with more detail to rebuild | Forward engineering |

### 1.2 Definition used

> **Alteration** is *the making of some changes to a system representation; it does **not** change
> the degree of abstraction and does not involve modification/deletion/addition of information at
> that level* (Ch.4 §1.2). It is a **horizontal move** and is the **only non-essential** principle
> of the three — yet it is almost always present. In this project, alteration is **the Δ**.

### 1.3 The chain we execute (one pass)

```
legacy code ──ABSTRACTION ↑──▶ recovered design + requirements ──ALTERATION →──▶ new design + requirements ──REFINEMENT ↓──▶ new code
   (as-is)                              (recovered)                          (Δ — this document)                    (to-be)
```

---

## 2. Change Types Applied (Ch.4 §1.3.1)

The four change types operate at increasing depth. Our selection:

| Change type | Level | Applied? | What changes here |
|---|---|---|---|
| **Recode** | implementation | **Yes** | Java 8 → modern LTS JDK; Connector/J 5.1.40 → current driver; rename/format clean-up; **rephrasing** (refactoring) |
| **Redesign** | design | **Yes (core)** | Architectural restructuring (2-tier → layered); data-model modification (normalise the schema); algorithmic replacement (billing total, date handling) |
| **Respecify** | requirements | **Yes (partial)** | **Change of form**: informal README → formal SRS (see `SRS_Target_System.md`); **change of scope**: drop the dead `expiry` table and the stub `Retrieval_Drug` path |
| **Rethink** | concept/domain | **Deferred (optional)** | Future evolution: single-shop desktop → multi-branch/cloud platform. Out of scope for this cycle; recorded as a roadmap item only |

---

## 3. Strategy Selection (Ch.4 §1.3.2)

The three strategies map to the three principles:

| Strategy | Principles used | Meaning |
|---|---|---|
| **Rewrite** | Alteration only | Transform at the **same** abstraction level |
| **Rework** | Abstraction + Alteration + Refinement | Abstract, restructure, then refine back |
| **Replace** | Abstraction + Refinement (no explicit alteration) | Hide a characteristic, rebuild with the new characteristic |

### 3.1 Selected strategy — a hybrid

**Rework (core) + Replace (UI) + Rewrite (build/config).**

| Layer | Strategy | Why this strategy |
|---|---|---|
| **Domain logic + data access** (SQL, expiry rules, billing maths) | **Rework** | The business rules buried in Swing event handlers are valuable but unstructured. We **abstract** them out (control/data-flow understanding), **alter** them (parameterised SQL, transactions, layering), then **refine** them back into Java service/DAO classes. This preserves proven logic while removing the mess. |
| **Presentation** (Swing/Matisse frames) | **Replace** | The Swing structure is untestable and entangled with logic. We represent the screen *intent* at a higher level (use cases / UI model), hide the Swing detail, and **refine** into a new UI stack with testability built in. |
| **Build & configuration** | **Rewrite** | Pure same-level substitution: Ant → Maven/Gradle; hard-coded values → external configuration. No abstraction needed. |

**Why not a single pure strategy?** A pure **Rewrite** would carry the bad structure forward; a pure
**Replace** would discard working logic unnecessarily. The hybrid matches the reality that *some*
parts need rethinking while *others* only need retargeting.

### 3.2 Fallback mode

**Rehosting** (Ch.4 §1.3) — re-engineering with **no feature change**, improving only qualities
(efficiency, maintainability) — is the fallback if scope must shrink.

---

## 4. What Is Being Altered (by Layer)

### 4.1 Requirements level — *Respecify*

| From (as-is) | To (to-be) | Change of |
|---|---|---|
| Informal `README.md` description | Formal, testable requirements (`SRS_Target_System.md`, FR/NFR) | **Form** |
| Implicit "admin vs employee" | Explicit **RBAC** with roles and permissions | Form |
| Feature set includes dead `expiry` table + stub `Retrieval_Drug` | Dead scope **removed**; scope made explicit | **Scope** |

### 4.2 Design level — *Redesign*

| From (as-is) | To (to-be) | Why |
|---|---|---|
| 2-tier monolith, SQL inside event handlers | **Layered / N-tier** (Presentation → Service → Domain → DAO → DB), dependencies downward only | Separates concerns; removes the global `static` field bus |
| Flat, denormalised schema; wrong types | **Normalised (3NF) schema** — surrogate keys, real FKs, `DATE`/`DECIMAL` | Integrity, real date logic, no redundancy |
| Stock kept on `drugs` (single row) | Stock kept per **batch** (`stock_batch`) | Correctly models production/expiry/quantity per batch |
| Fragile algorithms (`get_Total()` loop, date `split("-")`) | Corrected algorithms (single aggregate; `LocalDate`) | Correctness |

### 4.3 Implementation-technique level — *Recode + Redesign*

| From (as-is) | To (to-be) | Driver |
|---|---|---|
| String-concatenated SQL (injection) | **`PreparedStatement` / DAO** (parameterised) | Security, integrity |
| One new connection per frame | **Connection pool** | Performance, reliability |
| Plain-text password compare | **Hash + salt** verification | Security |
| Global `static` field bus | **Session/context object** + explicit parameters | Maintainability, testability |
| Ant + machine-absolute JAR paths | **Maven/Gradle** reproducible build | Portability |
| Swing/Matisse frames | **Testable UI stack** with separated logic | Testability |
| Hard-coded DB URL / `root` / blank password | **Externalised configuration** | Security, portability |
| No tests, no CI | **Unit/integration tests + CI** | Quality gates |

### 4.4 Database level — *Data Reverse Engineering (DBRE)*

Two-phase DBRE (Ch.4 §4.8) is applied to the legacy `../pharmacy.sql`:

- **(A) Data-structure extraction** — DDL text analysis + program analysis (constraints implied but not declared, e.g. `drugs.COMPANY_NAME` behaves like an FK) + data analysis + schema integration.
- **(B) Data-structure conceptualisation** — *untranslate* packed values (`PLACE='N-Right'` → section + shelf), standardise names, normalise entities.

The concrete target DDL is `target_schema.sql` (database `pharmacy_ng`). Data conversion is performed by **ETL** (Extract → Transform + clean → Load).

---

## 5. Δ Catalogue — The Concrete Alterations

Each alteration is uniquely identified, classified, and tied to its justification and verification.

### 5.1 Requirements Δ

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-01** | Formalise recovered behaviour into FR-01…FR-14 + NFRs with acceptance criteria | Respecify | No specification existed; needed for testability and equivalence | SRS review |
| **A-02** | Drop the unused `expiry` table and the stub `Retrieval_Drug` from scope | Respecify (scope) | Dead structure adds cost and confusion (Reductive maintenance) | Scope review |
| **A-03** | Make roles explicit (Admin, Employee) instead of implicit/broken | Respecify | The legacy admin gate never opens; access must be real | RBAC test cases |

### 5.2 Architecture Δ

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-04** | Replace 2-tier monolith with **layered architecture** (UI → Service → Domain → DAO → DB) | Redesign | Removes entanglement; enables testing and safe change | Architecture review |
| **A-05** | Remove the global `static` field bus; introduce a **session/context object** | Redesign | Hidden coupling; breaks ripple effects | Regression tests |
| **A-06** | Centralise duplicated `main()/clear()/refresh()` boilerplate into shared utilities | Recode | 24 copies of `main()`, ~15 `clear()` — pure duplication | Clone/metric check |
| **A-07** | Split the 1,520-line `Pharmacy` **god class** into Dashboard / Navigation / Alert-scan concerns | Redesign | Single class carried the highest WMC/coupling | CK metrics (WMC, CBO) |

### 5.3 Data-access Δ

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-08** | Replace 102 concatenated SQL statements with **`PreparedStatement`** behind DAOs | Recode + Redesign | **SQL injection** exposure; centralises access | Injection test suite |
| **A-09** | Introduce a **connection pool** (replace per-call connections) | Recode | Performance + resource safety | Load/response test |
| **A-10** | Wrap sale/purchase writes in **transactions** (all-or-nothing) | Redesign | Legacy writes auto-commit → partial-update risk | Transaction rollback tests |
| **A-11** | Add the **only-writer rule**: no UI frame opens a DB connection | Redesign | Fixes NFR-04; enforces layering | Architecture test |

### 5.4 Security Δ

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-12** | Hash + salt passwords (replace plain text) | Recode | Plain-text credentials in `users` | Auth tests |
| **A-13** | Replace `root`/blank credentials with a **least-privilege** DB account | Recode | Hard-coded `root` with empty password in `Connect.java` | Config/security review |
| **A-14** | Enforce **RBAC** by role from `app_user.role_id` | Redesign | Broken/absent authorization | Role-based test cases |

### 5.5 Database Δ (schema / DBRE)

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-15** | Normalise to **3NF**: surrogate keys + real FKs | Redesign | Denormalisation; 1 FK total; 5 tables with no PK | Schema review |
| **A-16** | Replace natural PK `company.NAME` with `company_id` | Redesign | Stable keys; `drugs.COMPANY_NAME` had no FK | Schema review |
| **A-17** | Introduce lookup tables `role`, `drug_type`, `storage_place` | Redesign | Free-text `TYPE`; packed `PLACE='N-Right'` | ETL checks |
| **A-18** | Move production/expiry/quantity/place onto **`stock_batch`** (1 drug : N batches) | Redesign | Legacy wrongly kept batch data on `drugs` | ETL checks |
| **A-19** | Split `sales`/`history_sales` → `sale` + `sale_item`; `purchase` → `purchase_order` + `purchase_item` | Redesign | Header/detail normalisation | ETL checks |
| **A-20** | Merge `inbox` + `message_history` → single `message` (+ `sent_at`, `is_read`) | Redesign | Duplicate tables of identical shape | ETL checks |
| **A-21** | Convert `varchar` dates to `DATE`/`DATETIME`; money `double` → `DECIMAL` | Redesign | Fragile `split("-")` date logic; precision | Data-type validation |
| **A-22** | Replace the text `EXPIRY` flag with derived expiry from `stock_batch.expiration_date` | Redesign | Real, queryable expiry logic | Expiry test cases |
| **A-23** | Replace hard-coded `< 10` with `drug.reorder_level` column | Redesign | Per-drug, configurable threshold | Stock-alert tests |
| **A-24** | `utf8mb4` encoding (replace `latin1`) | Recode | Correct character storage | Schema review |

### 5.6 Build / configuration Δ

| ID | Alteration | Change type | Why necessary | Verified by |
|---|---|---|---|---|
| **A-25** | Ant + absolute JAR paths → **Maven/Gradle** reproducible build | Recode | Machine-absolute paths; non-reproducible | Clean build on CI |
| **A-26** | Externalise configuration (URL/user/secret) to properties/env | Recode | Hard-coded credentials | Config review |
| **A-27** | Add **automated tests + CI** (replace none / only `stale.yml`) | Recode | No safety net for change | CI green |

---

## 6. Refactoring Catalogue (behaviour-preserving)

Refactoring = internal-structure change that **preserves observable behaviour** (validated by
regression). These are the refactorings executed as part of the Δ (Ch.1 §1.5):

| Smell | Location (as-is) | Refactoring |
|---|---|---|
| Duplicated `main()` boilerplate | ~24 frames | Remove / centralise to one entry point |
| Duplicated helpers `clear()/refresh()/fill_Username()/company()` | ~15 frames | Extract to a shared utility/base class |
| Near-identical visibility methods | 7 × `enterX()` in `Pharmacy` | Replace with data-driven showing (map role → widgets) |
| Near-identical SQL methods | `help_user/help_user1/help/date_help` in `Shift_Sales` | Parameterise into one query method |
| God class | `Pharmacy` (1,520 LOC) | Extract dashboard / alert-scan / navigation |
| Raw SQL concatenation | 102 statements / 21 files | Replace with `PreparedStatement` (also fixes injection) |
| Global `static` bus | `Pharmacy.username1/today/…`, `Login.id/NAME` | Replace with a session/context object + events |
| Dead code | `expiry` table, `Retrieval_Drug` empty `else`, `Login` dead branch, unreachable admin gate | Delete (Reductive maintenance) |

---

## 7. Invariants — What Is **Not** Altered

To make the new system provably **equivalent** to the old one, the first re-engineering pass
introduces **no new functionality** (Ch.5 §5.3):

- **All business rules are preserved**: a sale decrements stock and is recorded in history; a
  purchase is recorded against a company; expiry and low-stock alerts still exist; reports,
  messaging and audit retain their meaning.
- **The user's workflow is preserved** (login → dashboard → module), so retraining is minimal.
- **All retained data is migrated**, not discarded (via ETL).
- **Only genuine defects are corrected** (billing total, date handling, dead branches, the broken
  admin gate). Each deliberate correction is recorded as an **intentional Δ** and documented so it
  is not mistaken for a regression.

---

## 8. Why These Alterations Are Necessary (drivers → Δ)

| # | Driver (evidence in the as-is system) | Necessary alteration |
|---|---|---|
| D1 | **SQL injection** in 102 concatenated statements | A-08 (PreparedStatement/DAO) |
| D2 | `Connect.java` hard-codes `root` with a **blank password** | A-13, A-26 |
| D3 | **Plain-text passwords** in `users` | A-12 |
| D4 | **Broken access control** — admin gate queries non-existent users | A-03, A-14 |
| D5 | **No separation of concerns** — SQL inside UI handlers | A-04, A-11 |
| D6 | **God class + duplication** (`Pharmacy` 1,520 LOC; 24 `main()` copies) | A-06, A-07 |
| D7 | **Correctness bugs** — `get_Total()` accumulates in-loop; `varchar` dates `split("-")` | A-21, algorithm fixes |
| D8 | **Data integrity** — denormalisation, 1 FK, 5 tables without PK, wrong types | A-15…A-24 |
| D9 | **Dead structure** — unused `expiry`, stub `Retrieval_Drug` | A-02 |
| D10 | **No safety net** — no tests, no CI, no design docs | A-27, A-01 |
| D11 | **Portability** — Ant + machine-absolute paths, Java 8 | A-25, A-26 |
| D12 | **Reliability** — non-transactional sale/purchase | A-10 |

These drivers are the same ones that place the system in **Portfolio Quadrant 4** (low technical
quality, high business value) and justify the **Migrate** decision over Freeze/Outsource/Discard.

---

## 9. Sequencing of the Δ (with the migration method)

Selected method: **Database-First + Iterative** (see the re-engineering report). The Δ is applied in
this order so the system stays operational throughout:

1. **Schema Δ first** (A-15…A-24) → stand up `pharmacy_ng`; ETL the data; add a **forward gateway**
   so legacy frames keep working against the new DB.
2. **Layer-by-layer Δ** (A-04…A-14) using **Rework** on the core, component M1…M8 one at a time.
3. **UI Δ (Replace)** per module.
4. **Build/config Δ (Rewrite)** (A-25…A-27) alongside.
5. **Equivalence-test after each component**; shrink the residual DB; retire the legacy system.

---

## 10. Verification of the Δ (Equivalence Testing)

Because the first pass preserves functionality, the *same* system-level tests are run against the
**old** and **new** systems and must match (Ch.5 §5.5.7).

| Priority area | What is compared old vs new |
|---|---|
| Authentication | Login success/failure, session/role |
| Purchase posting | Recorded purchase rows and totals |
| Sales billing | Sale rows, stock decrement, history append, running total |
| Expiry & stock | Expired list, low-stock list |
| Reporting | Shift sales, login audit |
| Messaging | Sent/received messages, read status |

Where results differ, either a defect was introduced (fix it) or an intentional Δ was made (record it).

---

## 11. Risk Register for the Δ

| # | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R1 | Introducing defects while refactoring | Med | High | Equivalence tests before/after each step |
| R2 | Data loss during ETL/migration | Low | High | ETL with cleaning + backups + parallel run |
| R3 | Business disruption at cut-over | Med | High | Iterative method + parallel operation |
| R4 | Scope creep (adding features mid-migration) | Med | Med | Enforce the "no new functionality" rule (§7) |
| R5 | Hidden dependencies via global `static` state | High | Med | Impact analysis; remove the static bus early (A-05) |
| R6 | Old library vulnerabilities | Med | Med | Dependency checking; upgrade driver/JDK |

---

## 12. Summary of the Δ

| Δ category | Count | Representative alterations |
|---|---|---|
| Requirements (Respecify) | 3 | A-01…A-03 |
| Architecture (Redesign/Recode) | 4 | A-04…A-07 |
| Data access | 4 | A-08…A-11 |
| Security | 3 | A-12…A-14 |
| Database / schema | 10 | A-15…A-24 |
| Build / configuration | 3 | A-25…A-27 |
| **Total** | **27** | 24 alterations + 3 requirement-level respecifications |

**In one sentence:** the Δ keeps every working business function and its user workflow, while
**restructuring** the architecture into layers, **normalising** the database, **hardening** security
and data access, **correcting** genuine defects, and **modernising** the build — using **Rework** for
the core, **Replace** for the UI, and **Rewrite** for build/config, sequenced as
**Database-First + Iterative** and validated by **equivalence testing**.

*No source code was modified. This document specifies the intended alterations only.*
