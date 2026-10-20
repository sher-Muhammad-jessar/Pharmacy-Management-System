# Software Requirements Specification (SRS)
## Pharmacy Management System — Target (To-Be) System

| | |
|---|---|
| **Document title** | Software Requirements Specification — Target System |
| **System** | Pharmacy Management System (re-engineered) |
| **Version** | 2.0 — re-engineered core **+ modernised features** |
| **Status** | Approved for design (baseline for forward engineering) |
| **Target DB** | `pharmacy_ng` (normalised, 22 tables) — design in `diagrams/target_system/01_target_database_schema.drawio` |
| **Companion documents** | `PROJECT_OVERVIEW.md` (as-is), `ALTERATION_DOCUMENT.md` (Δ), `TARGET_DESIGN.md` (target design), `diagrams/target_system/` |
| **Structure** | Organised per IEEE 830 / ISO-IEC-IEEE 29148 conventions |

> **Scope note.** This SRS specifies the **target** system produced by re-engineering the legacy
> Pharmacy Management System. The **first pass preserves all legacy functionality** (per the Ch.5
> §5.3 migration rule) and fixes genuine defects; on top of that, **version 2.0 adds modern
> "current-world" features** (§3.2.1). Requirements fall into four origins:
> **(P)** *preserved* from legacy, **(F)** *defect-fix* of legacy behaviour, **(Q)** *quality*
> requirement newly made explicit, **(N)** *new* modern feature.

---

## 1. Introduction

### 1.1 Purpose

This document specifies the functional and non-functional requirements for the re-engineered
Pharmacy Management System. It is the authoritative baseline against which the target system will
be designed, implemented, verified and accepted. It replaces the legacy system's implicit
requirements (previously recoverable only from source code) with formal, testable statements.

### 1.2 Scope

The system is a **layered, multi-branch pharmacy management application** delivered as a desktop
app, a web client and an offline-capable mobile client over a REST API. It supports user
authentication and role-based access, drug/inventory management (batch-based), supplier and
purchasing workflow, point-of-sale billing with tax and stock decrement, pharmacy returns,
prescription management, customer & loyalty management, expiry and low-stock notifications,
analytics/reporting, messaging, audit, backup/export and integration — over a **normalised
relational database**.

**In scope:** all functions in §3.2 (including §3.2.1), on the normalised 22-table schema in §3.4.
**Out of scope (this cycle):** biometric verification, full accounting/general-ledger integration,
and third-party e-pharmacy marketplaces (recorded as future roadmap items).

### 1.3 Definitions, Acronyms and Abbreviations

| Term | Meaning |
|---|---|
| **Admin** | Actor with full control including user and audit management |
| **Branch Manager** | **(N)** Actor managing a branch: approvals, branch analytics, reports |
| **Employee / Pharmacist** | Actor performing day-to-day inventory, purchasing, sales, warnings, messaging |
| **Customer** | **(N)** External actor who buys goods, holds prescriptions and earns loyalty points |
| **Supplier** | **(N)** External actor (company) that fulfils purchase orders |
| **Scheduler** | **(N)** System actor that runs time-based jobs (notifications, backups, sync) |
| **Drug** | A medicine in the catalogue (name, type, dose, code, barcode, prices, company, tax) |
| **Batch** | A production/expiry lot of a drug with its own quantity, cost and storage place |
| **Branch** | **(N)** A physical store; users, stock, sales, purchases and prescriptions are scoped to it |
| **FEFO** | **(N)** First-Expiry-First-Out — dispensing the batch that expires soonest |
| **Loyalty points** | **(N)** Reward points earned/ redeemed by a customer against purchases |
| **POS** | Point of Sale — the billing/sales function |
| **RBAC** | Role-Based Access Control |
| **DAO** | Data Access Object — the only layer permitted to talk to the database |
| **ETL** | Extract–Transform–Load — the one-time data migration from legacy to target |
| **2FA** | **(N)** Two-Factor Authentication |
| **FR / NFR** | Functional / Non-Functional Requirement |
| **Δ** | Alteration, in the re-engineering model RE + Δ + FE |

### 1.4 References

- Tripathy & Naik, *Software Evolution and Maintenance* — Ch.1, Ch.4, Ch.5.
- `PROJECT_OVERVIEW.md` — as-is behaviour and recovered legacy requirements.
- `ALTERATION_DOCUMENT.md` — the alterations (Δ) this SRS formalises.
- `Design_Document.md`, `target_schema.sql`, `TARGET_DESIGN.md`.
- Legacy `../pharmacy.sql`; legacy sources under `../src/main/`.

### 1.5 Overview

Section 2 gives the product context and constraints. Section 3 states the specific requirements
(external interfaces, functional, non-functional, data, constraints). Section 4 gives traceability.
Section 5 defines verification and acceptance. Appendices hold the glossary and use-case summaries.

---

## 2. Overall Description

### 2.1 Product Perspective

The system replaces the legacy 2-tier Swing monolith. It is a self-contained product that **reuses
the recovered business rules** while modernising structure and quality. Its high-level architecture
is layered:

```
Presentation (UI)  →  Application/Service  →  Domain/Model  →  Data Access (DAO)  →  Database
        ↑ input            ↑ use-case logic      ↑ rules          ↑ parameterised SQL     ↑ pharmacy_ng
   (no SQL, no rules)  (validation, txn)    (pure entities)   (only DB talker)     (normalised, 3NF)
```

Dependencies point **downwards only**. Cross-cutting concerns (configuration, logging, security,
validation, error handling) apply across all layers.

### 2.2 Product Functions (summary)

**Core (preserved):** authentication & session · user (employee) management · drug/inventory
management · company management · purchasing · POS billing · drug search · reporting & audit ·
password change · move drug / edit price · renew validity / restock · expiry & stock warnings ·
messaging · role-based access control.

**Modernised (v2.0):** multi-branch support · barcode/QR scanning · automated expiry & low-stock
notifications (in-app/email/SMS) · analytics & BI dashboard · customer management · loyalty
programme · prescription management & dispensing · sales returns & refunds · purchase-order
workflow with approval · tax/GST-compliant invoicing (PDF/print) · data export & backup/restore ·
REST API & offline-capable client sync · strong authentication (reset, lockout, optional 2FA).

### 2.3 User Classes and Characteristics

| User class | Description | Privileges | Frequency |
|---|---|---|---|
| **Admin** | Owner/administrator | All functions + user/branch management + audit + analytics | Daily, intermittent |
| **Branch Manager** | Manages one branch | Approvals, branch analytics/reports, branch config, warnings | Daily |
| **Employee / Pharmacist** | Shop staff | Inventory, purchasing, sales, returns, prescriptions, search/scan, warnings, messaging, own password | Continuous during shifts |
| **Customer** | Buyer | Self-service: own profile, prescriptions, loyalty balance | Per visit |
| **Supplier** | Company fulfilling orders | Receives POs, confirms fulfilment | As ordered |
| **Scheduler (system)** | Time-based jobs | Generates notifications, runs backups, drives sync | Continuous (background) |
| **Maintainer / Developer** | IT | Non-user; uses configuration, logs and audit | As needed |

### 2.4 Operating Environment

| Item | Requirement |
|---|---|
| Client OS | Desktop (Windows/macOS/Linux with a modern LTS JDK), any modern browser, iOS/Android |
| Clients | Desktop app, Web SPA, **offline-capable mobile app**, barcode/QR scanner |
| Server/API | Application server exposing a **REST API** (JWT auth, pooled DB access) |
| Server/DB | MySQL or MariaDB (current supported release) hosting `pharmacy_ng` |
| Hardware (min) | Dual-core processor, **2 GB+** RAM, **2 GB** free disk (target) |
| External services | Email/SMS gateway, printer/PDF service, optional payment gateway |
| Build | Maven or Gradle, producing a reproducible artifact |
| Configuration | Externalised (properties/env); no secrets in code |

### 2.5 Design and Implementation Constraints

- **CT-01** The **re-engineered core preserves legacy functionality** (equivalence-tested); the
  **v2.0 modern features (§3.2.1)** are additive and must not break the preserved workflow.
- **CT-02** The **DAO layer is the only** component that accesses the database (§3.2 FR-15/§3.3).
- **CT-03** All SQL is parameterised; passwords are hashed+salted; DB account is least-privilege.
- **CT-04** Configuration externalised; no machine-absolute paths.
- **CT-05** Data is migrated from `pharmacy` to `pharmacy_ng` by a one-time **ETL**.
- **CT-06** Dates stored as `DATE`/`DATETIME`; money as `DECIMAL`; encoding `utf8mb4`.
- **CT-07** All client access (desktop/web/mobile) goes through the **REST API**; clients are
  stateless and may cache for offline operation.

### 2.6 Assumptions and Dependencies

- The organisation may operate **one or more branches** (multi-branch), served by a shared server/DB.
- Legacy data is available and cleanable during ETL; new columns are defaulted during migration.
- Users are trained on the day-to-day flow; customers/suppliers use simple external channels.
- External gateways (email/SMS, printing, payment) are reachable when used.
- Acceptance depends on passing **equivalence tests** against the legacy system (§5) **and** the
  new-feature acceptance criteria.

---

## 3. Specific Requirements

### 3.1 External Interface Requirements

#### 3.1.1 User interfaces
- A **Login** screen (user id + password, optional 2FA) is the single entry point; failures show a
  single generic message.
- A **Dashboard** shows the signed-in user, branch, current date/time, pending alerts and
  role-appropriate navigation to every module.
- Clients: **desktop app**, **web SPA** and **offline-capable mobile app**; consistent, role-aware
  forms and lists. No screen embeds SQL or business rules.
- New-feature screens: barcode scanning, POS with tax & loyalty, returns, prescriptions, customers,
  purchasing approval, notifications and the analytics dashboard.

#### 3.1.2 Hardware interfaces
- Standard keyboard/display/pointing device; **barcode/QR scanner** for POS and lookup.

#### 3.1.3 Software interfaces
- **Database** via JDBC through DAOs (parameterised SQL, pooled connections).
- **REST API** consumed by desktop/web/mobile clients (JSON over HTTPS, JWT auth).
- **Configuration** from an external properties file/environment.
- **Logging** to a file/console; **email/SMS gateway**, **printer/PDF service**, optional
  **payment gateway** for the modern features.

#### 3.1.4 Communications interfaces
- Client ↔ **REST API** over HTTPS/JSON; API ↔ DB via pooled JDBC; outbound HTTPS to external
  gateways. Mobile clients synchronise when connectivity is available.

### 3.2 Functional Requirements

Each requirement states: identifier · name · priority (MoSCoW) · actors · description · main flow ·
alternate/exception flows · pre/post-conditions · acceptance criteria. **Origin** tags: (P)
preserved, (F) defect-fix, (Q) quality, (N) new modern feature.

---

**FR-01 — Log in / Authenticate**  ·  Priority: **Must**  ·  Origin: P, F
- **Actors:** Admin, Employee.
- **Description:** The system shall authenticate a user from credentials and establish a session.
- **Main flow:** (1) User enters id + password. (2) System validates non-empty. (3) System verifies
  the password against the stored **hash+salt**. (4) On success a session is created with the user's
  role; a `login_audit` row is written. (5) Dashboard opens.
- **Alternate/exception:** empty input → "missing information" message; unknown user → generic
  failure; wrong password → generic failure. No branch reveals whether id or password was wrong.
- **Pre:** user exists. **Post:** authenticated session with role; audit recorded.
- **Acceptance:** correct credentials open the dashboard with the correct role; all failure cases
  are rejected with a **single generic** message; no plaint-text password comparison occurs.

**FR-02 — Manage Users**  ·  Priority: **Must**  ·  Origin: P  ·  **Admin only**
- **Description:** Admin shall create, read, update and delete employee accounts (name, DOB,
  address, phone, salary, role, password).
- **Main flow:** Admin selects an action → form → system validates (password ≥ 6 chars, unique id)
  → persists via DAO → success message → list refreshes.
- **Alternate/exception:** duplicate id → rejected; missing fields → rejected; delete of unknown
  user → rejected.
- **Post:** user records reflect the change; passwords stored **hashed**.
- **Acceptance:** CRUD on `app_user` works; deleted users cannot log in; passwords never stored or
  displayed in clear text.

**FR-03 — Manage Drugs**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** Create/read/update/delete drugs in the catalogue (name, type, dose, code,
  barcode, cost & selling price, company, reorder level).
- **Main flow:** form → validate (dates coherent, prices ≥ 0, barcode unique) → persist → list
  refresh. Stock/expiry data is handled as **batches** (FR-11).
- **Alternate/exception:** duplicate barcode → rejected; invalid production/expiration dates →
  rejected with message.
- **Acceptance:** catalogue CRUD works; `company_id` is a real FK; reorder level is per drug.

**FR-04 — Manage Companies**  ·  Priority: **Must**  ·  Origin: P
- **Description:** Create/read/update/delete supplier companies (name unique, address, phone).
- **Acceptance:** CRUD on `company` works; `name` is unique; drugs/purchases reference the company
  by `company_id`.

**FR-05 — Record Purchase**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** Record a purchase from a supplier as a **header + lines** in one transaction.
- **Main flow:** select company → add drug lines (qty × unit price) → system computes amounts and
  total → commit `purchase_order` + `purchase_item` atomically.
- **Alternate/exception:** invalid line → whole purchase rejected (rollback).
- **Post:** purchase persisted consistently; optional stock creation as a new batch.
- **Acceptance:** partial purchases never persist; totals equal the sum of lines.

**FR-06 — Create Sale / Bill (POS)**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** Produce a sale: insert `sale` + `sale_item`, **decrement stock**, and record
  history — **all in one transaction**; compute the total correctly.
- **Main flow:** enter barcode + quantity → validate drug exists, not expired, sufficient stock →
  system inserts sale/items, decrements the relevant `stock_batch.quantity`, writes history →
  shows the correct total.
- **Alternate/exception:** expired drug → offer renew/restock; insufficient stock → reject; any
  failure → full rollback (no partial sale).
- **Acceptance:** sale and stock move together (atomic); running total is correct (single aggregate,
  no double counting); invoice/receipt is produced.

**FR-07 — Search Drug**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** Find drugs by **barcode or name** using parameterised queries.
- **Acceptance:** search returns matching drugs; special characters cannot alter the query
  (injection-safe).

**FR-08 — View Reports / Audit**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** Produce sales-by-shift / by-date reports and login history.
- **Acceptance:** report totals reconcile with `sale`/`sale_item`; date-range filtering works with
  real `DATETIME` values (no string parsing).

**FR-09 — Change Password**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** A user changes their own password after verifying the current one.
- **Acceptance:** new password stored hashed; old password no longer works; wrong current password
  rejected.

**FR-10 — Move Drug / Edit Price**  ·  Priority: **Should**  ·  Origin: P
- **Description:** Change a batch's storage place; update a drug's selling price.
- **Acceptance:** storage place is stored as structured `section`/`shelf`; price update persists.

**FR-11 — Renew Validity / Restock**  ·  Priority: **Should**  ·  Origin: P, F
- **Description:** Extend a batch's dates / add stock as a **new batch**.
- **Acceptance:** expiry is computed from `stock_batch.expiration_date`; renewing updates dates and
  quantity consistently.

**FR-12 — View Expiry / Stock Warnings**  ·  Priority: **Must**  ·  Origin: P, F
- **Description:** List expired drugs (expiration date before today) and low-stock drugs
  (`SUM(batch.quantity) ≤ drug.reorder_level`).
- **Acceptance:** warning lists are accurate; thresholds are per-drug (no hard-coded 10).

**FR-13 — Send / Read Messages**  ·  Priority: **Should**  ·  Origin: P, F
- **Description:** Internal user-to-user messaging with timestamps and read status.
- **Acceptance:** messages stored in `message`; recipient sees unread messages; read status updates.

**FR-14 — View Login History**  ·  Priority: **Should**  ·  Origin: P
- **Description:** Audit of logins (user, type/role, date, time) from `login_audit`.
- **Acceptance:** login events are recorded and viewable with correct timestamps.

**FR-15 — Enforce Role-Based Access Control**  ·  Priority: **Must**  ·  Origin: F, Q
- **Description:** The system shall restrict each function to permitted roles (Admin, Branch Manager,
  Employee, Customer, Supplier). Admin-only functions (FR-02, branch management, audit) are
  hidden/denied for other roles.
- **Main flow:** after login, the role determines visible navigation and allowed operations; the
  service layer re-checks authorization on every privileged action.
- **Acceptance:** a non-privileged user cannot perform a restricted function by any path (UI is not
  the only guard); the role comes from `app_user.role_id` (no literal-name checks).

---

#### 3.2.1 New-Feature Functional Requirements (v2.0) — origin (N)

**FR-16 — Multi-branch / Multi-store Support**  ·  Priority: **Must**  ·  Origin: N
- **Actors:** Admin, Branch Manager.
- **Description:** Create/manage branches; scope stock, sales, purchases, prescriptions, customers
  and users to a branch; provide consolidated cross-branch reporting to the Admin.
- **Main flow:** Admin creates a branch → users assigned a home branch → every transaction records
  its `branch_id`.
- **Acceptance:** data is branch-scoped; a user sees only their authorised branch unless Admin;
  Admin dashboards can consolidate across branches.

**FR-17 — Barcode / QR Scanning & Generation**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Scan or generate EAN/UPC/QR codes for drugs and invoices; use scanning in POS and
  drug lookup.
- **Acceptance:** scanning a known barcode retrieves the drug; unknown barcode gives a clear message;
  generated labels/barcodes are printable.

**FR-18 — Automated Expiry & Low-Stock Notifications**  ·  Priority: **Should**  ·  Origin: N
- **Description:** A scheduler scans batches for approaching expiry, already-expired stock and low
  stock (`SUM(quantity) ≤ reorder_level`), creating notifications dispatched via in-app / email / SMS.
- **Acceptance:** notifications are produced on schedule, de-duplicated, marked SENT, and viewable /
  acknowledgeable by users.

**FR-19 — Analytics & BI Dashboard**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Dashboards for sales trends, profit, top-selling drugs and stock value, filterable
  by branch and period.
- **Acceptance:** KPIs reconcile exactly with `sale`/`sale_item` and stock data.

**FR-20 — Customer Management**  ·  Priority: **Must**  ·  Origin: N
- **Description:** Create/read/update customer records (name, phone, email, address) and attach a
  customer to a sale.
- **Acceptance:** customers persist; sales can reference a customer; walk-in (no customer) still works.

**FR-21 — Loyalty Programme**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Accrue points on purchases, redeem points, and show the balance; record every
  change in a loyalty ledger.
- **Acceptance:** points accrue/redeem correctly per policy; ledger reconciles with the balance.

**FR-22 — Prescription Management & Dispensing**  ·  Priority: **Must**  ·  Origin: N
- **Description:** Record prescriptions (customer, doctor, items), validate them, dispense against
  them (creating a sale), and track dispensed quantity and status.
- **Acceptance:** prescription-required drugs cannot be sold without a valid prescription; dispensing
  updates item/quantity and prescription status; expired prescriptions are rejected.

**FR-23 — Sales Returns & Refunds**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Process a return against a prior sale, limited to the return window and sold
  quantity; restock, refund and update the sale status; reverse associated loyalty.
- **Acceptance:** the return is atomic; stock and sale status stay consistent; refund equals the
  returned lines.

**FR-24 — Purchase-Order Workflow with Approval**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Manage the PO lifecycle `DRAFT → SUBMITTED → APPROVED → RECEIVED` (or `CANCELLED`),
  with approval by a Branch Manager; receiving creates stock batches.
- **Acceptance:** state transitions are enforced; only authorised roles may approve; receiving
  updates inventory.

**FR-25 — Tax / GST-Compliant Invoicing**  ·  Priority: **Must**  ·  Origin: N
- **Description:** Compute tax per line from the drug's tax rate; produce a compliant invoice/receipt;
  render to printer or PDF.
- **Acceptance:** invoice total = subtotal + tax − discount; the invoice is reproducible and printable.

**FR-26 — Data Export & Backup / Restore**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Export data (CSV/PDF) and run scheduled backups with a documented restore procedure.
- **Acceptance:** exports match the data; a backup can be restored without loss.

**FR-27 — REST API, Integration & Offline Sync**  ·  Priority: **Should**  ·  Origin: N
- **Description:** Expose operations through a REST API for web/mobile clients; mobile clients cache
  locally and synchronise.
- **Acceptance:** API calls are authenticated and authorized; sync reconciles offline changes without
  data loss.

**FR-28 — Strong Authentication**  ·  Priority: **Must**  ·  Origin: N
- **Description:** Password reset, account lockout after N failed attempts, optional 2FA and a strong
  password policy.
- **Acceptance:** lockout triggers and clears correctly; reset works; 2FA is verified when enabled; no
  user enumeration in responses.

**FR-29 — Change Audit Trail**  ·  Priority: **Should**  ·  Origin: Q, N
- **Description:** Record who did what (action, entity, entity id) for sensitive operations
  (create/update/delete/approve/login).
- **Acceptance:** audit entries are created for the listed operations and are queryable by Admin.

---

### 3.3 Non-Functional Requirements

| ID | Category | Requirement (measurable) | Origin |
|---|---|---|---|
| **NFR-01** | **Security** | 100% of DB access uses parameterised statements (no concatenation); passwords stored hashed+salted (never recoverable); DB account is least-privilege; authorization enforced server-side by role | Q |
| **NFR-02** | **Maintainability** | Layered architecture; no duplicated boilerplate; no god class; every class unit-testable; one entry point | Q |
| **NFR-03** | **Performance** | Pooled connections; indexed lookups; typical screen response **< 2 s** for the target dataset | Q |
| **NFR-04** | **Reliability / Integrity** | Sale and purchase operations are **atomic** (all-or-nothing); PK/FK/constraints enforce referential integrity | Q |
| **NFR-05** | **Portability** | No machine-absolute paths; all configuration externalised; builds on a supported LTS JDK via Maven/Gradle | Q |
| **NFR-06** | **Usability** | Existing workflow preserved; consistent, role-appropriate screens; clear error messages; no information leakage in failures | P |
| **NFR-07** | **Testability** | Business logic separated from UI; automated unit + integration tests exist and run in CI | Q |
| **NFR-08** | **Data integrity** | Dates as `DATE`/`DATETIME`; money as `DECIMAL`; surrogate keys + FKs; `utf8mb4` encoding | Q |
| **NFR-09** | **Auditability** | Login audit and full sales history retained and queryable | P |
| **NFR-10** | **Documentation** | Requirements, design, configuration and user documentation maintained | Q |
| **NFR-11** | **Scalability** | Schema and code allow additional branches/volume without redesign (batches, lookup tables) | Q |
| **NFR-12** | **Availability / Recoverability** | Backups/restore procedure defined; DB failure produces a clear error, not data corruption | Q |

---

### 3.4 Data Requirements

The target database is the normalised schema `pharmacy_ng` (**22 tables**) — design in
`diagrams/target_system/01_target_database_schema.drawio` and `TARGET_DESIGN.md` §6.

| # | Table | Purpose | Key design | Origin |
|---|---|---|---|---|
| 1 | `role` | Roles (Admin, Branch Manager, Employee, Customer, Supplier) | PK `role_id`, unique name | P |
| 2 | `branch` | Branch/store master | surrogate PK; unique name; enables multi-branch | N |
| 3 | `drug_type` | Lookup of drug types | replaces free-text `TYPE` | P |
| 4 | `storage_place` | Storage locations | splits `PLACE='N-Right'` into section + shelf | P |
| 5 | `company` | Suppliers | surrogate PK `company_id`; unique name; email/contact | P |
| 6 | `app_user` | Users/employees | `role_id`+`branch_id` FKs; `password_hash`; `dob` DATE; lockout columns | P, N |
| 7 | `customer` | Customers | loyalty points; branch FK | N |
| 8 | `drug` | Drug catalogue | catalogue attributes only; `company_id` FK; `reorder_level`; `tax_rate`; `is_prescription` | P, N |
| 9 | `stock_batch` | One row per production/expiry batch | production/expiry/quantity/cost/place + `branch_id` | P, N |
| 10 | `purchase_order` | Purchase header | normalises flat `purchase`; **status/approval workflow** | P, N |
| 11 | `purchase_item` | Purchase lines | `po_id` + `drug_id` FKs | P |
| 12 | `sale` | Sales header (invoice) | normalises `sales`/`history_sales`; branch/user/customer FKs; tax fields; status | P, N |
| 13 | `sale_item` | Sales lines | `sale_id`/`drug_id`/`batch_id` FKs; `tax_rate` | P, N |
| 14 | `sale_return` | Returns header | against a sale; refund total; branch/user FKs | N |
| 15 | `sale_return_item` | Return lines | return FK + sale_item FK; quantity/refund | N |
| 16 | `loyalty_transaction` | Loyalty ledger | customer FK; points delta | N |
| 17 | `prescription` | Prescription header | customer/branch FKs; doctor; dates; status | N |
| 18 | `prescription_item` | Prescription lines | prescription/drug FKs; dosage; dispensed qty | N |
| 19 | `notification` | Expiry/low-stock alerts | type/severity; drug/batch/branch FKs; channel/status | N |
| 20 | `login_audit` | Login audit | replaces `login`; user FK; `login_time` DATETIME; IP; success | P, N |
| 21 | `audit_log` | Action audit trail | user; action; entity/entity id; timestamp | N |
| 22 | `message` | Messaging | merges `inbox` + `message_history`; adds `sent_at`, `is_read` | P |

**Data migration (ETL) — key transformations:** `users.PASSWORD` → `password_hash` (hash+salt);
`company.NAME` → surrogate `company_id`; `drugs.TYPE` → `drug_type` lookup; `PLACE` → structured
`storage_place`; `drugs` production/expiry/quantity/cost/place → `stock_batch`; `drugs.EXPIRY` →
derived; `drugs.QUANTITY` → `SUM(stock_batch.quantity)`; `sales`+`history_sales` → `sale`+`sale_item`;
`purchase` → `purchase_order`+`purchase_item`; `login` → `login_audit`; `inbox`+`message_history` →
`message`; **`expiry` dropped**.

---

## 4. Requirements Traceability

### 4.1 Requirement ↔ legacy source ↔ alteration

| Requirement | Legacy source (frames) | Related Δ |
|---|---|---|
| FR-01 | `Login` | A-01, A-12 |
| FR-02 | `User` | A-03, A-14 |
| FR-03 | `Drug`, `Drug_List` | A-15, A-16, A-17 |
| FR-04 | `Company` | A-16 |
| FR-05 | `Buy_Drug`, `All_Deal` | A-10, A-19 |
| FR-06 | `Sales_Bill` | A-08, A-10, A-19 |
| FR-07 | `Search_Drug` | A-08 |
| FR-08 | `Shift_Sales` | A-21 |
| FR-09 | `Change_Password` | A-12 |
| FR-10 | `Move_Drug`, `Edit_Price` | A-17 |
| FR-11 | `Renew_Validity` | A-18, A-22 |
| FR-12 | `Expired_Drug`, `Almost_Finish`, `Warning*` | A-22, A-23 |
| FR-13 | `Inbox`, `Send`, `Show_Message` | A-20 |
| FR-14 | `Login_Details` | A-21 |
| FR-15 | `Pharmacy` (broken gate) | A-03, A-14 |
| FR-16 Multi-branch | *(new — no legacy source)* | A-15 (schema), CT-05 |
| FR-17 Barcode/QR | `Search_Drug`, `Sales_Bill` (text barcode) | A-08 |
| FR-18 Notifications | `Warning`, `Almost_Finish` (manual) | A-22, A-23 |
| FR-19 Analytics | `Shift_Sales` (basic reports) | A-21 |
| FR-20 Customer mgmt | *(new — no legacy source)* | A-15 |
| FR-21 Loyalty | *(new — no legacy source)* | A-15 |
| FR-22 Prescriptions | *(new — no legacy source)* | A-15, A-19 |
| FR-23 Returns | *(new — no legacy source)* | A-10, A-15 |
| FR-24 PO workflow | `Buy_Drug`, `All_Deal` (no approval) | A-19 |
| FR-25 Tax invoicing | `Sales_Bill` (no tax) | A-21 |
| FR-26 Export/backup | *(new — no legacy source)* | — |
| FR-27 REST API / sync | *(new — no legacy source)* | A-04 |
| FR-28 Strong auth | `Login`, `Change_Password` | A-12, A-13 |
| FR-29 Audit trail | `Login_Details` (login only) | A-21 |

### 4.2 Module → requirement coverage

| Module | Requirements |
|---|---|
| M1 Auth & Session | FR-01, FR-09, FR-15 |
| M2 Dashboard | (navigation for all) |
| M3 Drug Inventory | FR-03, FR-07, FR-10 |
| M4 Expiry & Stock | FR-11, FR-12 |
| M5 Purchasing | FR-04, FR-05 |
| M6 Sales / Billing | FR-06 |
| M7 Reporting / Audit | FR-08, FR-14 |
| M8 Messaging | FR-13 |
| Infrastructure | FR-02 |
| M9 Returns | FR-23 |
| M10 Prescriptions | FR-22 |
| M11 Customers & Loyalty | FR-20, FR-21 |
| M12 Notifications | FR-18 |
| M13 Analytics | FR-19 |
| Platform (multi-branch, barcode, API, auth, backup) | FR-16, FR-17, FR-24, FR-25, FR-26, FR-27, FR-28, FR-29 |

---

## 5. Verification and Acceptance

### 5.1 Verification method per requirement type

| Requirement type | Method |
|---|---|
| Functional — core (FR-01…FR-15) | Unit + integration tests; system/use-case tests; **equivalence tests** vs legacy |
| Functional — new features (FR-16…FR-29) | Feature acceptance tests (barcode, notifications, returns, prescriptions, PO approval, analytics, backup, API/sync, lockout/2FA) |
| Non-functional | Targeted tests (security scan, load timing, CI build, transaction rollback) |
| Data | ETL validation: row counts, referential integrity, type checks post-migration |

### 5.2 Equivalence testing (Ch.5 §5.5.7)

**Core** priority areas compared old vs new, results must match:
authentication · purchase posting · sales billing (rows, stock decrement, history, total) ·
expiry & stock lists · shift sales & login audit · messaging.

**New features** (no legacy equivalent) are verified against their acceptance criteria in §3.2.1.

### 5.3 Acceptance criteria (system accepted only if all hold)

1. All **Must** requirements pass their tests.
2. All equivalence tests match the legacy outputs (or differences are recorded intentional Δs).
3. No SQL string concatenation, no plain-text password, no hard-coded `root` credentials.
4. Sale and purchase operations are atomic under induced failure.
5. The application builds reproducibly and CI is green.
6. All **new-feature** acceptance criteria (§3.2.1) pass, and no new feature degrades the preserved core.

---

## Appendix A — Glossary

See §1.3. Additional: **Batch** = production/expiry lot; **Reorder level** = per-drug low-stock
threshold; **Δ** = alteration.

## Appendix B — Use-Case Summary (target)

| Use case | Actors | Requirement |
|---|---|---|
| Authenticate | Admin, Employee | FR-01 |
| Manage Users | Admin | FR-02 |
| Manage Drugs | Admin, Employee | FR-03 |
| Manage Companies | Admin, Employee | FR-04 |
| Record Purchase | Admin, Employee | FR-05 |
| Create Sale / Bill | Employee | FR-06 |
| Search Drug | Employee | FR-07 |
| View Reports / Audit | Admin | FR-08, FR-14 |
| Change Password | Admin, Employee | FR-09 |
| Move Drug / Edit Price | Employee | FR-10 |
| Renew Validity / Restock | Admin, Employee | FR-11 |
| View Expiry / Stock Warnings | Employee | FR-12 |
| Send / Read Messages | Admin, Employee | FR-13 |
| Enforce RBAC | System | FR-15 |
| Manage Branches | Admin, Branch Manager | FR-16 |
| Scan / Generate Barcode | Pharmacist | FR-17 |
| Receive Automated Notifications | Users, Scheduler | FR-18 |
| View Analytics Dashboard | Admin, Branch Manager | FR-19 |
| Manage Customers | Admin, Pharmacist | FR-20 |
| Earn / Redeem Loyalty | Customer | FR-21 |
| Manage & Dispense Prescription | Pharmacist, Customer | FR-22 |
| Process Return / Refund | Pharmacist | FR-23 |
| Approve Purchase Order | Branch Manager, Supplier | FR-24 |
| Print Tax Invoice | Pharmacist | FR-25 |
| Export / Backup / Restore | Admin, Scheduler | FR-26 |
| Sync via REST API | Clients, Scheduler | FR-27 |
| Reset Password / 2FA | All users | FR-28 |
| View Audit Trail | Admin | FR-29 |

---

*End of Software Requirements Specification.*
