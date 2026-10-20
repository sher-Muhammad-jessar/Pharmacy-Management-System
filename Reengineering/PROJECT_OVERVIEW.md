# Pharmacy Management System — Project Overview

**What the system is performing now, and what its legacy requirements are**

| | |
|---|---|
| **System** | Pharmacy Management System — a pharmacy stock / sales / billing desktop application |
| **Project path** | `D:\SERE\Pharmacy-Management-System` |
| **Document type** | Analysis overview (current behaviour + recovered legacy requirements) |
| **Method baseline** | Tripathy & Naik, *Software Evolution and Maintenance* — Ch.1 (concepts), Ch.4 (re-engineering), Ch.5 (legacy information systems) |
| **Companion documents** | `SERE_Reengineering_Report.md`, `Design_Document.md`, `TARGET_DESIGN.md`, `SRS_Target_System.md`, `diagrams/current_system/README.md`, `../pharmacy.sql` |

> **Note on terminology.** This project has **no formal requirements document** — the only
> documentation shipped with the code is a short `README.md`. Therefore the "legacy
> requirements" below are the requirements **recovered** by reverse-engineering the actual
> behaviour of the running system (source code + database + observed screens). They describe
> what the system *does*, not what a specification once said.

---

## 1. System Identification

| Property | Value |
|---|---|
| Type | 2-tier **Java SE desktop** application (Swing / AWT GUI) |
| Language | Java SE **1.8** |
| GUI toolkit | Swing/AWT, **NetBeans Matisse**-generated (24 `.form` files) |
| Build | **Apache Ant** / NetBeans (plus an Eclipse `.classpath`) — no Maven/Gradle |
| Size | 28 `.java` files ≈ **9,710 LOC**, of which 27 files / ≈9,618 LOC are in one package `main` |
| Libraries | `mysql-connector-java-5.1.40`, `rs2xml` (DbUtils), `JTattoo-1.6.11`, `AbsoluteLayout` |
| Database | **MySQL / MariaDB 10.1.16**, database `pharmacy`, InnoDB, `latin1` |
| Entry point | `main.Main` → `new Login().setVisible(true)` |
| Login seed data | id `1`, password `admin` (also `mark/mark`, `clark/rootaccess`) |
| Packaging | `dist/Pharmacy.jar`, Ant `build.xml`, `manifest.mf` |

---

## 2. What the System Is Performing Now (Current Behaviour)

### 2.1 One-line summary

It runs a **single pharmacy shop**: users log in, and from a dashboard they manage the drug
catalogue, suppliers (companies), purchases, point-of-sale billing, expiry/stock alerts,
shift sales reports, login history and internal messaging — all reading and writing **one
flat MySQL database**.

### 2.2 Execution flow

```
Main  →  Login (ID + password)  →  Pharmacy (dashboard hub)  →  any of 22 sub-screens
                                    │
                                    └── every screen runs raw SQL directly against
                                        MySQL through the static helper Connect.connect()
```

### 2.3 Authentication & session (as performed now)

1. `Login` frame opens and pre-fills greyed "Enter Your ID / Password" placeholders.
2. User enters **User_ID + Password** and clicks **Login**.
3. The frame opens a connection via `Connect.connect()` and runs
   `SELECT ID,NAME,PASSWORD FROM users WHERE ID='<input>'`.
4. It compares the returned `PASSWORD` to the typed password **as plain text**.
5. On success it stores the user's `NAME`, hides itself and opens the `Pharmacy` dashboard;
   on failure it shows "Wrong ID" or "Wrong Password".
6. `Pharmacy` displays the logged-in user's name plus a live **date** and **clock**, and shows
   a **pending-message alert** dialog.

> **Access control is effectively absent.** The dashboard tries to restrict admin screens by
> prompting for an "admin Password" and querying
> `SELECT NAME,PASSWORD FROM users WHERE NAME='Ebrahem Samer'` (and `'Syed Ibrahim'`).
> Neither account exists in the data, so the admin gate **never opens**; and the
> `if (id.equals("1")) … else …` branch in `Login` is identical, so no real role is applied.

### 2.4 The dashboard hub (`Pharmacy`)

A 1,520-line "god class" that acts as the navigation centre. It:
- shows the user name, **date** and a **1-second clock** (via `javax.swing.Timer`);
- reveals button groups on demand through seven near-identical `enterX()` methods
  (`enteruser`, `enterdrugs`, `enterdrugdetails`, `enterpurchase`, `sales`, `setting`, …);
- provides **Logout** and **Show Message** actions;
- opens every other screen by direct instantiation, e.g. `new Sales_Bill().setVisible(true)`;
- shares state with the other frames through **public static fields**
  (`username1`, `today`, `time`, `ex`, `expired_bar`, and `Login.id` / `Login.NAME`).

### 2.5 Functional modules and what each performs

| # | Module | Frames | What it does now |
|---|--------|--------|------------------|
| **M1** | Authentication & Session | `Login`, `Change_Password`, `changestyle` | Authenticate user; change own password (verifies old password, updates in clear text); apply look-and-feel/theme |
| **M2** | Dashboard / Navigation | `Pharmacy`, `Main` | Hub: date/clock, message alert, role-based button groups, opens all screens, logout |
| **M3** | Drug Inventory | `Drug`, `Drug_List`, `Search_Drug`, `Move_Drug`, `Edit_Price` | **Add / delete / update** drugs (name, type, dose, code, barcode, cost & selling price, company, storage place, production/expiration date, quantity); **list** stock; **search** by name/barcode (`REGEXP`); **move** a drug's storage place; **edit** selling price |
| **M4** | Expiry & Stock Alerts | `Expired_Drug`, `Almost_Finish`, `Warning`, `Warning_List`, `Renew_Validity` | List drugs flagged expired; list drugs below the reorder threshold; show warning/alert dialogs; **renew validity** (reset the `EXPIRY` flag and re-date an expired drug) |
| **M5** | Purchasing | `Buy_Drug`, `All_Deal` | Record a **purchase** from a supplier (insert/update/delete into `purchase`); list all deals; supplier list comes from `company` |
| **M6** | Sales / Billing (POS) | `Sales_Bill`, `Retrieval_Drug` (stub) | **Produce a bill**: validate barcode + quantity, check expiry and stock, **insert a sale line**, **decrement drug quantity**, **append sales history**, compute the running total; "New_Bill"/"Cancel" clear the sales table (`Retrieval_Drug` is an empty stub) |
| **M7** | Reporting / Audit | `Shift_Sales`, `Login_Details` | **Sales-by-shift / by-date** reports; **login history** audit with type/date/time |
| **M8** | Messaging | `Inbox`, `Send`, `Show_Message` | Internal **user-to-user messaging**: list received messages, send a message (cannot send to yourself), read + delete a message |
| — | Infrastructure | `Connect`, `User`, `Company` | `Connect` = single JDBC helper; `User` = add/delete/update employee accounts; `Company` = save/update/delete suppliers |

### 2.6 The data it manages (current)

| Table | Holds |
|---|---|
| `users` | Employee/admin accounts — ID, name, DOB, address, phone, salary, **password (plain text)** |
| `login` | Login history — name, type, date, time |
| `drugs` | Drug catalogue **and stock** — name, type, barcode, dose, code, cost/selling price, expiry flag, company name, production/expiration date, place, quantity |
| `company` | Supplier companies — name, address, phone |
| `purchase` | Purchases recorded — barcode, name, type, company, qty, price, amount |
| `sales` | Current bill lines — barcode, name, type, dose, qty, price, amount, date |
| `history_sales` | Permanent sales log — user, barcode, name, type, dose, qty, price, amount, date, time |
| `inbox` / `message_history` | Messages (two identical tables: live inbox + history) |
| `expiry` | **Unused** orphan table (never queried) |

### 2.7 Business rules actually implemented

- A **sale** decrements `drugs.QUANTITY` and appends a row to `history_sales`
  (three separate auto-commit statements — **not** a transaction).
- A **purchase** inserts a row into `purchase` (the only table with a real foreign key —
  `purchase.COMPANY_NAME → company.NAME`, `ON UPDATE/DELETE CASCADE`).
- **Expiry** is a text flag on `drugs.EXPIRY` (`'Available for use'` / `'Expired'`) plus a
  `EXPIRATION_DATE` stored as text and parsed in code with `split("-")`.
- **Low stock** is a **hard-coded threshold** (`QUANTITY < 10`), not a per-drug value.
- Dates are stored as `varchar` throughout and formatted/parsed manually.

### 2.8 Operating characteristics

| Aspect | Current reality |
|---|---|
| Architecture | 2-tier monolith; no service, DAO or domain layers |
| Data access | Raw string-concatenated SQL inside Swing event handlers (102 statements across 21 files); one new DB connection per frame |
| Concurrency | None — single-user desktop; `sales` is a shared scratch table |
| Reliability | Sales/purchase writes are non-transactional (partial-update risk) |
| Reporting | Sales by shift/date, login history, stock & expiry lists |
| Output | On-screen invoices/bills, receipts, reports (printable via the UI) |
| Tests / CI | None (no `test/` directory; CI workflow is only `stale.yml`) |

---

## 3. Legacy Requirements (Recovered)

Because the only shipped "specification" is the README, the requirements below were
**recovered** from the running system by reverse engineering (source partitioning, call/
dependency analysis, and behaviour observation). They are the requirements the legacy
system actually satisfies — the baseline the re-engineered target must remain equivalent to.

### 3.1 Actors / stakeholders

| Actor | Description |
|---|---|
| **Admin** | Full control — user management, audit, plus all employee functions |
| **Employee / Pharmacist** | Day-to-day inventory, purchasing, sales, warnings, messaging |
| *(Customers, owner, maintainer)* | Indirect stakeholders: receive bills; sponsor and maintain the system |

### 3.2 Recovered functional requirements

| ID | Requirement | Screens that satisfy it today |
|----|-------------|-------------------------------|
| **FR-01** | Login / Authenticate — establish a session from credentials; reject failures | `Login` |
| **FR-02** | Manage Users — create / read / update / delete employee accounts (admin) | `User` |
| **FR-03** | Manage Drugs — CRUD on the drug catalogue | `Drug`, `Drug_List` |
| **FR-04** | Manage Companies — CRUD on supplier companies | `Company` |
| **FR-05** | Record Purchase — record a purchase from a supplier | `Buy_Drug`, `All_Deal` |
| **FR-06** | Create Sale / Bill (POS) — insert sale lines, decrement stock, append history | `Sales_Bill` |
| **FR-07** | Search Drug — find drugs by barcode or name | `Search_Drug` |
| **FR-08** | View Reports / Audit — sales by shift, daily totals | `Shift_Sales` |
| **FR-09** | Change Password — user changes own password | `Change_Password` |
| **FR-10** | Move Drug / Edit Price — change storage place; update selling price | `Move_Drug`, `Edit_Price` |
| **FR-11** | Renew Validity / Restock — extend dates / restock a drug | `Renew_Validity` |
| **FR-12** | View Expiry / Stock Warnings — list expired and low-stock drugs | `Expired_Drug`, `Almost_Finish`, `Warning`, `Warning_List` |
| **FR-13** | Send / Read Messages — internal messaging with history | `Inbox`, `Send`, `Show_Message` |
| **FR-14** | View Login History — audit of logins with type/date/time | `Login_Details` |

### 3.3 Recovered non-functional requirements (as currently realised)

| ID | Category | Requirement (as the legacy system stands) |
|----|----------|-------------------------------------------|
| **NFR-01** | Security | **Weak today** — SQL is concatenated (injection), passwords stored plainly, DB account is `root` with a blank password, RBAC not enforced. *Target:* parameterised SQL, hashed+salted passwords, least-privilege account, RBAC. |
| **NFR-02** | Maintainability | **Poor today** — no layering, duplicated `main()/clear()/refresh()` in ~24 frames, one god class. *Target:* layered design, no duplication, unit-testable classes. |
| **NFR-03** | Performance | Acceptable for a single shop; a new connection is opened per screen. *Target:* connection pooling, indexed lookups, < 2 s response. |
| **NFR-04** | Reliability / Integrity | **Weak today** — sale/purchase are multi-statement and non-transactional. *Target:* all-or-nothing transactions + PK/FK constraints. |
| **NFR-05** | Portability | **Pinned** — Java 8, Ant, machine-absolute JAR paths, hard-coded DB URL. *Target:* externalised config, modern LTS JDK, reproducible build. |
| **NFR-06** | Usability | Existing workflow must be preserved; role-appropriate screens. |
| **NFR-07** | Testability | **None today** (business logic sits in event handlers). *Target:* logic separated from UI. |
| **NFR-08** | Data integrity | **Weak today** — dates as `varchar`, money as `double`, 5 tables without a PK, 1 FK total. *Target:* `DATE`/`DATETIME`, `DECIMAL`, proper keys/FKs. |
| **NFR-09** | Auditability | Login audit + full sales history must be retained. |
| **NFR-10** | Documentation | Design/user/config documentation must be produced. |

### 3.4 Platform / environment requirements (from project README)

| Category | Requirement |
|---|---|
| **Hardware** | Intel Pentium **or** AMD processor; **1 GB+** DDR RAM; **40 GB** hard disk |
| **Software** | Windows / macOS / Linux; JRE and JDK; a MySQL server (WAMP, XAMPP or equivalent) |
| **Setup** | Create the `pharmacy` database from `../pharmacy.sql`, then build & run from the IDE |
| **Login (default)** | id `1`, password `admin` (changeable in MySQL or via the UI) |

### 3.5 Scope of the recovered requirements

- **In scope (working features):** everything in FR-01 … FR-14 above.
- **Dead / unused structure (out of scope):** the `expiry` table (never used), the
  `Retrieval_Drug` stub (empty), the `if(id.equals("1"))` dead branch in `Login`, the
  unreachable admin gate in `Pharmacy`.

---

## 4. Why the System Is "Legacy" (drivers for re-engineering)

| Driver | Evidence |
|---|---|
| **Security exposure** | SQL injection in 102 concatenated statements; plain-text passwords; `root`/blank DB credentials |
| **Broken access control** | Admin gate queries non-existent users (`Ebrahem Samer`, `Syed Ibrahim`); identical login branches |
| **Maintainability** | 1,520-line `Pharmacy` god class; duplicated boilerplate; 7 near-identical `enterX()` methods |
| **Correctness risks** | `Sales_Bill.get_Total()` accumulates inside its loop; `varchar` dates parsed with `split("-")` |
| **Dead / stub code** | unused `expiry` table; empty `Retrieval_Drug`; commented-out remnants |
| **No safety net** | no tests, no CI (only `stale.yml`), no design documentation |
| **Pinned, obsolete stack** | Java 8, Ant, MySQL Connector/J 5.1.40, Swing/Matisse |

**Portfolio verdict:** **low technical quality, high business value → Quadrant 4**, i.e. a
legacy system to be **migrated / re-engineered** (not frozen, outsourced or discarded).

---

## 5. Requirement Traceability (module → requirement)

| Recovered module | Functional requirements satisfied |
|---|---|
| M1 — Auth & Session | FR-01, FR-09 |
| M2 — Dashboard / Navigation | (navigation — supports all FRs) |
| M3 — Drug Inventory | FR-03, FR-07, FR-10 |
| M4 — Expiry & Stock | FR-11, FR-12 |
| M5 — Purchasing | FR-04, FR-05 |
| M6 — Sales / Billing | FR-06 |
| M7 — Reporting / Audit | FR-08, FR-14 |
| M8 — Messaging | FR-13 |
| Infrastructure | FR-02 (user/admin management) |

---

## 6. Summary

| Question | Answer |
|---|---|
| **What is it performing now?** | A single-shop pharmacy desktop app: login → dashboard → drug/company/purchase management, POS billing with stock decrement, expiry & low-stock alerts, shift-sales and login-audit reports, and internal messaging — all against one flat MySQL database via a static JDBC helper. |
| **What are its legacy requirements?** | 14 recovered functional requirements (FR-01…FR-14) across 8 modules, plus 10 non-functional requirements that are currently **met poorly** (security, maintainability, integrity, portability, testability). They were reverse-engineered because the project shipped with no formal specification — only a README. |
| **Scope note** | The first re-engineering pass must **preserve this functionality** (no new features) so the new system can be proven equivalent to the legacy one, while fixing the genuine defects identified above. |

*No source code was modified. This document is an analysis artifact.*
