# Software Re-engineering — Design Document
## Pharmacy Management System — Requirements, Database Schema, System Design & Architecture

**Project:** Pharmacy Management System (`D:\SERE\Pharmacy-Management-System`)
**Deliverable type:** Design documentation (analysis + design only — **no source code is modified**)
**Method baseline:** Tripathy & Naik, *Software Evolution and Maintenance* — Ch.1 (concepts), Ch.4 (re-engineering), Ch.5 (legacy information systems)

---

## 0. Deliverables in This Package

| # | File | What it is | How to open |
|---|---|---|---|
| 1 | `Design_Document.docx` (this document) | Full design document | Microsoft Word / LibreOffice |
| 2 | `Design_Document.md` | Same document in Markdown | any text editor |
| 3 | `target_schema.sql` | Target (to-be) database DDL — design artifact | any SQL editor / text editor |
| 4 | `diagrams/01_legacy_ER_diagram.drawio` | As-is database schema | draw.io |
| 5 | `diagrams/02_target_ER_diagram.drawio` | To-be normalised schema | draw.io |
| 6 | `diagrams/03_target_architecture.drawio` | Target layered architecture | draw.io |
| 7 | `diagrams/04_asis_architecture.drawio` | As-is (legacy) architecture + decomposability | draw.io |
| 8 | `diagrams/05_use_case_requirements.drawio` | Requirements / use-case model | draw.io |
| 9 | `diagrams/06_reengineering_model.drawio` | RE + Δ + FE model (abstraction/alteration/refinement) | draw.io |
| 10 | `diagrams/07_migration_roadmap.drawio` | Migration roadmap & cut-over | draw.io |

### How to open the `.drawio` files
`.drawio` files are plain, open XML — they open in many applications:
- **Web (no install):** go to **app.diagrams.net** → *Open Existing Diagram* → choose the file.
- **Desktop (free):** the **draw.io Desktop** application.
- **VS Code:** the free **Draw.io Integration** extension (just double-click the file).
- **Export:** from diagrams.net you can export any diagram to PNG / SVG / PDF / HTML for submission.
- Because the files are XML, they also open in any text editor for inspection.

---

# PART 1 — HOW TO APPROACH THE LEGACY SYSTEM

> Before any change: *analysis, restructuring, modernisation*. Re-engineering does **not** mean throwing the old system away blindly.

## 1. Migration Planning & Portfolio Analysis

We execute the **thirteen migration-planning steps** of Ch.5 §5.4.

| Step | Activity | Result for this project |
|---|---|---|
| 1 | **Portfolio analysis** | Technical quality = **LOW**, business value = **HIGH** → **Quadrant 4** (candidate for redevelopment/migration) |
| 2 | **Identify stakeholders** | Pharmacy owner (sponsor), pharmacists/employees (end users), IT maintainer/developer, the customers (indirect) |
| 3 | **Understand requirements** | Recovered requirements (see Section 2) — captured from the legacy behaviour + user needs |
| 4 | **Create a business case** | Problem, solution, risks, benefits (below) |
| 5 | **Go / no-go decision** | **GO** — migrate/re-engineer |
| 6 | **Understand the LIS** | Reverse engineering (Section 1.2) |
| 7 | **Understand target technology** | Modern LTS JDK, layered Java, DAO/JPA, MySQL/MariaDB, Maven/Gradle |
| 8 | **Evaluate technologies** | Compare JDBC vs JPA, Swing vs JavaFX/web, Ant vs Maven |
| 9 | **Define target architecture** | Layered / N-tier (Section 4) |
| 10 | **Define a strategy** | **Rework + Replace**, executed as **Database-First + Iterative** (Part 2) |
| 11 | **Reconcile with stakeholders** | Confirm scope (functionality preserved) and phased cut-over |
| 12 | **Determine resources** | Effort via **COCOMO II**; team of analyst/developer/tester |
| 13 | **Evaluate feasibility** | Feasible — small codebase (≈9.7 kLOC), clean DB boundary |

**Business case (Step 4):**
- **Problem:** security holes (SQL injection, hard-coded `root`/blank password, plaintext passwords), no layering, a 1,520-line dashboard, duplicated code, no tests, no CI, dead code.
- **Solution:** re-engineer into a layered, configurable, tested system with a normalised database.
- **Risks:** defect introduction, data loss, business disruption — mitigated by equivalence testing, ETL with cleaning, iterative migration and parallel operation.
- **Benefits:** reduced maintenance cost, removed security exposure, lower risk, easier future feature growth.

**Recommendation:** the system is a **Quadrant-4 legacy system** → **Migrate** (of the six legacy options: Freeze, Outsource, Carry-on, Discard & redevelop, Wrap, Migrate). **Wrap** is kept only as an interim bridge.

## 2. Understanding the Legacy Information System (LIS)

Techniques used: **program comprehension** + **reverse engineering** (Ch.1 §1.6, Ch.4 §4.5).
$\text{Old Implementation} \rightarrow \text{Reverse Engineering} \rightarrow \text{Design Recovery}$

The **IEEE 6-step reverse-engineering process** was applied:

**Local analysis:**
1. **Partition into modular units** → 27 GUI frames grouped into 8 functional modules:

| Module | Frames / classes | Data used |
|---|---|---|
| M1 Auth & Session | `Login`, `Change_Password`, `changestyle` | users, login |
| M2 Dashboard | `Pharmacy` (hub, 1,520 LOC), `Main` | all |
| M3 Drug Inventory | `Drug`, `Drug_List`, `Search_Drug`, `Move_Drug`, `Edit_Price` | drugs |
| M4 Expiry & Stock | `Expired_Drug`, `Almost_Finish`, `Warning`, `Warning_List`, `Renew_Validity` | drugs |
| M5 Purchasing | `Buy_Drug`, `All_Deal` | purchase, company |
| M6 Sales / Billing | `Sales_Bill`, `Retrieval_Drug` (stub) | sales, history_sales, drugs |
| M7 Reporting / Audit | `Shift_Sales`, `Login_Details` | history_sales, login |
| M8 Messaging | `Inbox`, `Send`, `Show_Message` | inbox, message_history |
| — Infrastructure | `Connect`, `User`, `Company` | — |

2. **Describe meanings / identify functional units** → per table above.
3. **Input/output schematics** → GUI widgets = input; JDBC `ResultSet` rows = output; `Connect.connect()` = single DB entrant.

**Global analysis:**
4. **Connected units (call graph)** → `Main → Login → Pharmacy → {all frames}`, with a global `static` field bus (`Pharmacy.username1/today/ex/expired_bar`, `Login.id/NAME`).
5. **Overall system behaviour** → login → role-based dashboard → CRUD on drugs/company/purchases → POS billing that decrements `drugs.QUANTITY` and appends to `history_sales` → expiry/stock warnings → reports → messaging.
6. **Internal structural model** → recovered 2-tier architecture (Section 4.1, diagram 04).

**Recovered design problems:** hard-coded credentials in `Connect.java`; 102 concatenated SQL statements across 21 files (injection); plaintext passwords; `Pharmacy.java` god class; duplicated `main()/clear()/refresh()`; unreachable admin gate (`Pharmacy.java` literal-name checks); `Sales_Bill.get_Total()` accumulation bug; `varchar` dates parsed with `split("-")`; unused `expiry` table; stub `Retrieval_Drug`; no tests / no CI.

## 3. Decomposability Evaluation

Decomposability decides the migration method (Ch.5 §5.5.2):

| Type | Definition | This system? |
|---|---|---|
| Fully decomposable | interfaces, applications and DB are **distinct** components with clean interfaces | ✗ (not fully) |
| **Semi-decomposable** | interfaces are separate, but **applications and database are inseparable** | ✅ **This is our system** |
| Nondecomposable | no functional components can be separated | ✗ |

**Evidence:** the UI frames and the SQL logic are inseparable (SQL is written *inside* Swing event handlers), so interfaces and application logic cannot be separated. **However**, the database service is reachable through a single helper (`Connect.java`), so there is a **clean seam at the database boundary**.

**Consequence:** because the DB boundary is clean, a **Database-First** approach is feasible (it requires a clean interface to the legacy database), combined with the **Iterative** method for the application components. (Section 7.)

---

# SECTION 2 — SYSTEM REQUIREMENTS SPECIFICATION

> The recovered behaviour is formalised here into requirements — this is the **"Respecify"** change (change of *form*: informal README → formal, testable requirements; change of *scope*: drop dead features). See diagram 05.

## 2.1 Actors / Stakeholders

| Actor | Description |
|---|---|
| **Admin** | Full control: user management, audit, plus all employee functions |
| **Employee / Pharmacist** | Day-to-day inventory, purchasing, sales, warnings, messaging |

## 2.2 Functional Requirements

| ID | Requirement | Description | Legacy source |
|---|---|---|---|
| **FR-01** | Login / Authenticate | User authenticates with credentials; session established; failed logins rejected cleanly | `Login` |
| **FR-02** | Manage Users | Create / read / update / delete employees (admin only) | `User` |
| **FR-03** | Manage Drugs | Create / read / update / delete drugs (name, type, dose, code, barcode, prices, company, place) | `Drug` |
| **FR-04** | Manage Companies | Create / read / update / delete supplier companies | `Company` |
| **FR-05** | Record Purchase | Record a purchase (drug, company, quantity, price, amount) from a supplier | `Buy_Drug`, `All_Deal` |
| **FR-06** | Create Sale / Bill (POS) | Produce a bill: insert sale lines, decrement stock, append sales history — **atomically** | `Sales_Bill` |
| **FR-07** | Search Drug | Find drugs by barcode or name | `Search_Drug` |
| **FR-08** | View Reports / Audit | Sales-by-shift, daily totals, login history | `Shift_Sales`, `Login_Details` |
| **FR-09** | Change Password | User changes own password (stored hashed) | `Change_Password` |
| **FR-10** | Move Drug / Edit Price | Change a drug's storage place; update its selling price | `Move_Drug`, `Edit_Price` |
| **FR-11** | Renew Validity / Restock | Extend dates / restock a drug (new batch) | `Renew_Validity` |
| **FR-12** | View Expiry / Stock Warnings | List expired drugs and drugs below reorder level | `Expired_Drug`, `Almost_Finish`, `Warning`, `Warning_List` |
| **FR-13** | Send / Read Messages | Internal user-to-user messaging with read status | `Inbox`, `Send`, `Show_Message` |
| **FR-14** | View Login History | Audit of logins with type/date/time | `Login_Details` |

## 2.3 Non-Functional Requirements

| ID | Category | Requirement |
|---|---|---|
| **NFR-01** | Security | All SQL **parameterised** (no string concatenation); passwords **hashed + salted**; DB account is **least-privilege** (not `root`); RBAC enforced by role |
| **NFR-02** | Maintainability | **Layered** design; no duplicated boilerplate; unit-testable classes; one entry point |
| **NFR-03** | Performance | **Connection pooling**; indexed lookups; typical screen response < 2 s |
| **NFR-04** | Reliability / Integrity | Sale and purchase operations are **transactional** (all-or-nothing); PKs/FKs/constraints enforce integrity |
| **NFR-05** | Portability | **No** machine-absolute paths; configuration **externalised**; modern LTS JDK; reproducible build (Maven/Gradle) |
| **NFR-06** | Usability | Existing workflow preserved; consistent, role-appropriate screens |
| **NFR-07** | Testability | Business logic separated from UI so that automated (unit/integration) tests are possible |
| **NFR-08** | Data integrity | Dates stored as `DATE`/`DATETIME`; money as `DECIMAL`; proper keys and foreign keys |
| **NFR-09** | Auditability | Login audit and full sales history retained |
| **NFR-10** | Documentation | Design, user and configuration documentation updated |

## 2.4 Requirements Traceability

| Recovered module | Functional requirements |
|---|---|
| M1 | FR-01, FR-09 |
| M2 | (navigation — covered by all FRs) |
| M3 | FR-03, FR-07, FR-10 |
| M4 | FR-11, FR-12 |
| M5 | FR-04, FR-05 |
| M6 | FR-06 |
| M7 | FR-08, FR-14 |
| M8 | FR-13 |
| — | FR-02 (users/admin) |

---

# SECTION 3 — DATABASE SCHEMA

## 3.1 Legacy (As-Is) Schema

Recovered from `pharmacy.sql` (MariaDB 10.1, database `pharmacy`, InnoDB, `latin1`) — see **diagram 01**.

| Table | Columns | Key |
|---|---|---|
| `company` | NAME, ADDRESS, PHONE | PK NAME |
| `drugs` | NAME, TYPE, BARCODE, DOSE, CODE, COST_PRICE, SELLING_PRICE, EXPIRY, COMPANY_NAME, PRODUCTION_DATE, EXPIRATION_DATE, PLACE, QUANTITY | PK BARCODE |
| `purchase` | BARCODE, NAME, TYPE, COMPANY_NAME, QUANTITY, PRICE, AMOUNT | PK BARCODE; FK COMPANY_NAME→company |
| `sales` | BARCODE, NAME, TYPE, DOSE, QUANTITY, PRICE, AMOUNT, DATE | none |
| `history_sales` | USER_NAME, BARCODE, NAME, TYPE, DOSE, QUANTITY, PRICE, AMOUNT, DATE, TIME | none |
| `users` | ID, NAME, DOB, ADDRESS, PHONE, SALARY, PASSWORD | PK ID |
| `login` | NAME, TYPE, DATE, TIME | none |
| `inbox` | MESSAGE_FROM, MESSAGE_TO, MESSAGE_TEXT | none |
| `message_history` | MESSAGE_FROM, MESSAGE_TO, MESSAGE_TEXT | none |
| `expiry` | PRODUCT_NAME, PRODUCT_CODE, DATE_OF_EXPIRY, QUANTITY_REMAIN | none — **orphan / unused** |

## 3.2 Problems Found in the Legacy Schema

1. **Denormalisation** — drug name/type/dose/price are copied into `sales`, `purchase`, `history_sales`.
2. **No primary keys** on `sales`, `history_sales`, `login`, `inbox`, `message_history`, `expiry`.
3. **Missing FK** — `drugs.COMPANY_NAME` has no foreign key (only `purchase` does).
4. **Wrong data types** — dates stored as `varchar` and parsed with `split("-")`; `PASSWORD varchar(20)` plain text.
5. **Duplication** — `inbox` and `message_history` are identical in shape.
6. **Dead structure** — `expiry` table is unused.
7. **Encoding** — `latin1` (should be `utf8mb4`).

## 3.3 Target (To-Be) Normalised Schema

Derived by **Data Reverse Engineering / DBRE** (Ch.4 §4.8): *data-structure extraction* (DDL + program analysis) then *data-structure conceptualisation* (untranslate + normalise). See **diagram 02** and `target_schema.sql`.

| # | Table | Purpose | Key design change |
|---|---|---|---|
| 1 | `role` | Lookup of roles (Admin, Employee) | new — replaces implicit role name |
| 2 | `app_user` | Users/employees | renamed from `users`; adds `role_id` FK; `password_hash` (hashed); `dob` is `DATE` |
| 3 | `company` | Suppliers | surrogate PK `company_id`; `name` unique |
| 4 | `drug_type` | Lookup of drug types (`Bills`, `Injection`, `Drink`…) | new — replaces free-text `TYPE` |
| 5 | `storage_place` | Storage places | new — splits `PLACE` `'N-Right'` into `section='N'`, `shelf='Right'` |
| 6 | `drug` | Drug catalogue | keeps catalogue attributes only; `company_id` **FK**; `reorder_level` replaces the hard-coded `< 10` |
| 7 | `stock_batch` | One row per production/expiry batch | **new** — production/expiry/quantity/cost/place moved here (legacy wrongly kept them on `drugs`) |
| 8 | `purchase_order` | Purchase header | new — normalises flat `purchase` |
| 9 | `purchase_item` | Purchase lines | new — `po_id` + `drug_id` FKs |
| 10 | `sale` | Sales header (invoice) | new — normalises `sales`/`history_sales`; `user_id` FK; `sale_datetime DATETIME` |
| 11 | `sale_item` | Sales lines | new — `sale_id` + `drug_id` FKs |
| 12 | `login_audit` | Login audit | replaces `login`; `user_id` FK; `login_time DATETIME` |
| 13 | `message` | Messaging | merges `inbox` + `message_history`; adds `sent_at`, `is_read` |

### 3.3.1 Data Dictionary — Legacy → Target mapping (ETL mapping)

| Legacy | Target | Transformation |
|---|---|---|
| `users.ID/NAME/DOB/ADDRESS/PHONE/SALARY` | `app_user.*` | rename; `DOB` `varchar`→`DATE`; add `role_id` |
| `users.PASSWORD` | `app_user.password_hash` | hash + salt |
| `company.NAME` | `company.company_id` / `name` | replace natural PK by surrogate PK |
| `drugs.TYPE` | `drug_type.type_id` | lookup normalisation |
| `drugs.PLACE` `'N-Right'` | `storage_place.section`,`shelf` | **untranslate** the packed value |
| `drugs.PRODUCTION_DATE/EXPIRATION_DATE/QUANTITY/COST_PRICE/PLACE` | `stock_batch.*` | move attributes to the batch (1 drug : N batches) |
| `drugs.EXPIRY` `'Available for use'` | (*derived*) | computed from `stock_batch.expiration_date` vs today |
| `drugs.COMPANY_NAME` | `drug.company_id` | text → FK |
| `drugs.QUANTITY` | `SUM(stock_batch.quantity)` | derived aggregate |
| `purchase.*` | `purchase_order` + `purchase_item` | split header/detail |
| `sales.*` / `history_sales.*` | `sale` + `sale_item` | merge + split; `DATE`+`TIME`→`DATETIME`; `USER_NAME`→`user_id` |
| `login.*` | `login_audit.*` | `NAME`→`user_id`; `DATE`+`TIME`→`login_time` |
| `inbox` + `message_history` | `message` | merge; add `sent_at`, `is_read` |
| `expiry` | *(dropped)* | unused — removed (Reductive maintenance) |

**ETL** (Extract → Transform + clean → Load) is used for the data conversion, as required by Ch.5 §5.3.

## 3.4 DDL Reference
The full target DDL is provided as `target_schema.sql` (database `pharmacy_ng`).

---

# SECTION 4 — SYSTEM DESIGN & ARCHITECTURE

## 4.1 As-Is Architecture (recovered)

2-tier monolith: `Main → Login → Pharmacy (hub) → 22 frames`, each frame embedding raw SQL, all reaching the DB through one static helper `Connect.java`. See **diagram 04**.

## 4.2 Target Architecture (to-be)

A **layered / N-tier** architecture — see **diagram 03**:

| Layer | Responsibility | Contains |
|---|---|---|
| **1. Presentation** | Render UI, capture input | Login, Dashboard, Drug Management, Purchasing, Sales/POS, Reports, Messaging (no SQL, no business rules) |
| **2. Application / Service** | Use-case logic, validation, transactions | AuthService, InventoryService, PurchaseService, SalesService, ReportService, MessageService, Expiry/Stock NotificationService |
| **3. Domain / Model** | Entities + business rules (pure Java) | Drug, StockBatch, Sale/SaleItem, PurchaseOrder/PurchaseItem, AppUser/Role, Company, Message, StoragePlace |
| **4. Data Access (DAO/Repository)** | The **only** layer that talks to the DB; parameterised SQL; pooling; transactions | DrugDAO, SaleDAO, PurchaseDAO, UserDAO, ReportDAO, MessageDAO, ConnectionPool, TransactionManager |
| **5. Database** | Persist data | MySQL/MariaDB `pharmacy_ng` (normalised) |
| **Cross-cutting** | Applied across layers | Configuration, Logging, Security/RBAC, Validation, Exception Handling |

**Rule:** dependencies point **downwards only** (UI → Service → Domain → DAO → DB). This removes the global `static` field bus and the cross-frame coupling.

## 4.3 Component Design Highlights

- **No frame opens a DB connection.** All DB access goes through DAOs; the service layer owns transactions (fixes NFR-04).
- **Authentication** → `AuthService` verifies a hashed password and writes `login_audit`; role comes from `app_user.role_id` (fixes the unreachable literal-name admin gate).
- **Sales** → `SalesService.createSale()` runs in **one transaction**: insert `sale` + `sale_item`, decrement `stock_batch.quantity`, write history (fixes the `get_Total()` bug and partial-update risk).
- **Expiry** → derived from `stock_batch.expiration_date` (fixes fragile `varchar` date `split()` logic).
- **Configuration** is externalised (env/properties) — `Connect.java`'s hard-coded URL/`root`/blank password is removed (fixes NFR-01/NFR-05).

## 4.4 Deployment

- **Client:** desktop app (modern UI stack) or thin client.
- **Server/DB:** MySQL/MariaDB `pharmacy_ng`.
- **Build:** Maven/Gradle producing a reproducible artifact (replacing Ant + machine-absolute paths).
- During migration, a **forward gateway** plus **Data Banker** allow new and legacy components to coexist (Section 9).

## 4.5 Key Design Decisions

| Decision | Rationale |
|---|---|
| Layered architecture | Separates concerns; enables testing; removes duplication |
| Normalised schema (3NF) | Removes redundancy; enforces integrity; supports real date logic |
| DAO + parameterised SQL | Fixes SQL injection; centralises data access |
| Hash + salt passwords | Removes plaintext credential exposure |
| Batch-based stock (`stock_batch`) | Correctly models production/expiry/quantity per batch |
| Externalised configuration | Portability and security |

---

# PART 2 — HOW TO RE-ENGINEER THE SYSTEM

Re-engineering is formally:

$$\text{Re-engineering} = \text{Reverse Engineering} + \Delta + \text{Forward Engineering}$$

where **Δ** captures alterations in **functionality** or **implementation technique**. See **diagram 06**.

---

# SECTION 5 — THE THREE PRINCIPLES, IN DETAIL: ABSTRACTION → ALTERATION → REFINEMENT

These three principles underlie everything. Each is defined, and its concrete use in this project is stated separately.

## 5.1 ABSTRACTION — *how we raise the level of understanding*

**Definition (Ch.4 §1.2):** *the level of abstraction of a representation is gradually increased by successively replacing details with abstract information; one produces a view that focuses on selected system characteristics by hiding information about other characteristics.*

**Direction:** **upward (↑)**. **Where used:** **Reverse Engineering** — examine only, **never change**.

**The abstraction ladder:** *how?* → *what & how?* → *what?* → *why?*, i.e.
Implementation → Design → Requirements → Concept.

**How we perform abstraction on THIS project (step by step):**

1. **From source code to a call/dependency graph.** Each frame is reduced from hundreds of lines of Swing code to a *node*; the fact that it calls `Connect` and touches `drugs` becomes an *edge*. Detail (widgets, listeners) is hidden; structure is revealed.
2. **From frames to functional modules (chunking).** 27 frames are abstracted into **8 functional modules M1–M8**. This is "chunking": building a higher-level structure from lower-level ones.
3. **From event handlers to business rules.** SQL statements buried in `ActionListener` bodies are abstracted into *rules* ("a sale decrements stock and is recorded in history"), i.e. recovering the *intent* while hiding the *mechanism*.
4. **From the physical schema to a conceptual schema (DBRE).** The `pharmacy.sql` physical tables are abstracted into entities and relationships: `PLACE='N-Right'` becomes the concept *StoragePlace(section, shelf)*; `TYPE='Bills'` becomes the concept *DrugType*; `QUANTITY` on `drugs` becomes the concept *batch quantity*.
5. **From implementation to requirements.** The recovered behaviour is written as use cases (diagram 05) — the highest abstraction we need here.

**Output of abstraction:** a set of models — call graph, module map, ER/conceptual model, use-case model — each *more abstract* than the code, with **no change to the system**.

**Rule to respect (Ch.4 §4.5):** abstraction is a process of **examination, not change** — the legacy system is left untouched during this step.

## 5.2 ALTERATION — *how and where we change the system*

**Definition (Ch.4 §1.2):** *alteration is the making of some changes to a system representation; it does **not** change the degree of abstraction and does not involve modification/deletion/addition of information at that level.* It is a **horizontal (→) move** and is the **only non-essential** principle — yet it is almost always present. **This is the Δ.**

**Two dimensions of alteration (Ch.4 §1.3):**
- **change in functionality** — arises from changed **business rules**; and
- **change in implementation technique** — e.g. procedural → object-oriented, JDBC → DAO/JPA.

**Where we apply alteration in THIS project (at the level we abstracted to):**

| Alteration level | Alteration performed |
|---|---|
| **Requirements** | Formalise informal behaviour into FR-01…FR-14 (change of *form*); tighten scope — **drop** the dead `expiry` feature and the unused helper (change of *scope*) |
| **Design** | Restructure the architecture 2-tier → layered; redefine the data model to the normalised schema; replace fragile algorithms (date `split()`, `get_Total()` loop) |
| **Implementation technique** | Inline SQL → DAO with parameterised queries; single connection per call → **connection pool**; plaintext password compare → **hash + verify**; Ant + absolute JAR paths → Maven/Gradle; Swing/Matisse frames → testable UI |

**Critical rule we obey:** the first re-engineering pass introduces **no new functionality** (Ch.5 §5.3) — *except* correcting genuine defects — so that the new system can be proven **equivalent** to the old one. Alteration is thus **technique-focused**, which is exactly the "change in implementation technique" dimension.

## 5.3 REFINEMENT — *how we rebuild the new system*

**Definition (Ch.4 §1.2):** *refinement is the reverse of abstraction — the level of abstraction is gradually decreased by successively replacing aspects of the system with more detail.*

**Direction:** **downward (↓)**. **Where used:** **Forward Engineering** — the traditional path Concept → Requirements → Design → Implementation.

**How we perform refinement on THIS project (step by step):**

1. **From the altered conceptual/design models down to a concrete design** — the target architecture (diagram 03) and the target schema (diagram 02 + `target_schema.sql`) are elaborated into concrete classes, interfaces and tables.
2. **From design to code** — each target class (Drag, StockBatch, SaleDAO, SalesService, …) is implemented with full detail (fields, methods, SQL, validation).
3. **From the conceptual data model to the physical DDL** — entities become tables, attributes become columns with concrete types (`DECIMAL`, `DATE`, `DATETIME`, `VARCHAR`), relationships become foreign keys.
4. **From requirements to test cases** — acceptance/equivalence tests are elaborated from FR-01…FR-14.

**Output of refinement:** the **new implementation** — a working, layered, tested system running on the normalised database.

## 5.4 How the three chain together (one pass)

$$\underbrace{\text{legacy code}}_{\text{Implementation}}\;\xrightarrow{\text{ABSTRACTION ↑}}\;\underbrace{\text{recovered design + requirements}}_{\text{Design/Requirements}}\;\xrightarrow{\text{ALTERATION →}}\;\underbrace{\text{new design + requirements}}_{\text{Design/Requirements}}\;\xrightarrow{\text{REFINEMENT ↓}}\;\underbrace{\text{new code}}_{\text{Implementation}}$$

---

# SECTION 6 — STEP 1: CHOOSE THE RE-ENGINEERING STRATEGY (and why)

| Strategy | Principles used | Meaning |
|---|---|---|
| **Rewrite** | Alteration only | Transform at the **same** abstraction level |
| **Rework** | Abstraction + Alteration + Refinement | Abstract, restructure, then refine back |
| **Replace** | Abstraction + Refinement | Hide a characteristic, rebuild with the new characteristic |

**SELECTION: a hybrid — Rework (core) + Replace (UI) + Rewrite (build/config).**

| Layer | Strategy | **Why** |
|---|---|---|
| Domain logic + data access | **Rework** | The business rules buried in event handlers are valuable but unstructured. We **abstract** them out (control/data-flow understanding), **alter** them (parameterised SQL, transactions, layering), and **refine** them back into Java service/DAO classes. This preserves proven logic while removing the mess — the textbook Rework path. |
| Presentation (Swing `.form` frames) | **Replace** | The Swing/Matisse structure is untestable and entangled with logic. We represent the screen *intent* at a higher level (use cases/UI model), hide the Swing detail, and **refine** into a new UI stack — exactly the Replace pattern. |
| Build & configuration | **Rewrite** | Pure same-level substitution (Ant → Maven; hard-coded values → external config). No abstraction needed. |

**Why not a single pure strategy?** A pure **Rewrite** would carry the bad structure forward; a pure **Replace** would discard working logic unnecessarily. The hybrid matches the reality that *some* parts need rethinking while *others* only need retargeting.

**Rehosting fallback:** if scope must shrink, we fall back to **rehosting** — re-engineer with **no feature change**, improving only qualities (efficiency, maintenance cost).

---

# SECTION 7 — STEP 2: SELECT A MIGRATION / EVOLUTION METHOD (and why)

| Method | Fits when |
|---|---|
| Cold Turkey (Big Bang) | small, stable system, and new features are guaranteed |
| **Database First** | fully/cleanly decomposable at the **DB interface** (forward gateway) |
| Database Last | fully decomposable; applications migrated first (reverse gateway) |
| Composite DB / Chicken Little | parallel operation with gateways + a transaction coordinator (two-phase commit) |
| Butterfly | no simultaneous dual-DB access; sample datastore + TempStores |
| **Iterative** | re-engineer one component at a time; four component states coexist |

**SELECTION: DATABASE-FIRST + ITERATIVE.**

**Why Database-First:**
- The system is **semi-decomposable**, but the **DB boundary is clean** (all access funnels through `Connect.java`), which is precisely the precondition Ch.5 §5.5.2 requires.
- Migrating the schema + data first lets the team start receiving productivity benefits early, while a **forward gateway** keeps legacy components working against the new database.

**Why Iterative (not Cold Turkey):**
- The pharmacy is **live and business-critical** → Big Bang carries high risk of downtime and failure.
- Iterative keeps the system **operational throughout**, **preserves user and maintainer familiarity**, and allows **equivalence tests after each component**.
- Concretely: *classify data → redesign DB → restore legacy components to use the **Data Banker** → migrate data → re-engineer procedures → equivalence-test → shrink the **Residual DB** → next component*, repeating until the Residual DB is empty. Metadata is then cleaned and documentation reconstructed. See **diagram 07**.

**Cut-over selection:** **Parallel Operation** first (old and new run side by side, outputs compared), then **Phased Interoperability** (module by module), then retire the legacy system — avoiding both cut-and-run risk and a one-shot switch.

---

# SECTION 8 — STEP 3: MODERNISE AND CLEAN UP

- **Restructure internal code** into modular, layered units (Section 4) — the monolithic dashboard and per-frame duplication are replaced.
- **Remove dead structure:** drop the unused `expiry` table, the stub `Retrieval_Drug` path, the unreachable admin gate and the duplicated `main()`/`clear()`/`refresh()` boilerplate (Reductive + Groomative maintenance, Chapin et al.).
- **Reconstruct documentation** and **clean metadata** once components have transitioned — the `Metadata` that routed data during migration is reduced to describe only the New DB, and the Data Banker's residual-routing code is withdrawn.

---

# SECTION 9 — MIGRATION ROADMAP & PHASES

See **diagram 07**. Summary:

| Phase | Activity |
|---|---|
| **1. Analysis & Planning** | Portfolio analysis, stakeholders, requirements, business case, go/no-go, reverse engineering, target architecture |
| **2. Database-First Migration** | Convert schema; **ETL** the data; stand up a forward gateway |
| **3. Iterative Re-engineering** | Re-engineer components M1…M8 one at a time |
| **4. Equivalence Testing** | Old output ≡ new output after each iteration (Ch.5 §5.5.7) |
| **5. Cut-over & Retire** | Parallel run → phased cut-over → legacy retired |

**Per-iteration steps (M1…M8):** analyze component → classify its data (primary vs residual) → restore to use the Data Banker → migrate that component's data → re-engineer the procedure → equivalence test → shrink Residual DB.

---

# SECTION 10 — SUMMARY OF WHAT WAS PRODUCED

1. **Requirements specification** — 14 functional + 10 non-functional requirements, with a traceability matrix (Section 2, diagram 05).
2. **Database schema** — the as-is schema (diagram 01) with its problems, and the **normalised to-be schema** (diagram 02 + `target_schema.sql`) with a full legacy→target ETL mapping (Section 3).
3. **System design & architecture** — as-is 2-tier monolith (diagram 04) and the **target layered architecture** (diagram 03), with component-level design decisions (Section 4).
4. **Part 1** — migration planning & portfolio analysis, LIS understanding, decomposability evaluation (Sections 1–3).
5. **Part 2** — the general model, **Abstraction → Alteration → Refinement explained in detail and separately** (Section 5), strategy selection **Rework + Replace** (Section 6), migration method **Database-First + Iterative** (Section 7), modernisation & clean-up (Section 8).
6. **All diagrams as editable `.drawio` files** — openable in draw.io, the desktop app, or VS Code, and exportable to PNG/SVG/PDF.

*No source code was modified. All artifacts are design/documentation files.*
