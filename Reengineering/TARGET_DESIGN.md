# Target System Design (Design Document)
## Pharmacy Management System — Re-engineered & Modernised System

| | |
|---|---|
| **Document** | Target (to-be) system design — **design only, no source code / SQL** |
| **System** | Re-engineered Pharmacy Management System |
| **Companion files** | `SRS_Target_System.md`, `ALTERATION_DOCUMENT.md`, `PROJECT_OVERVIEW.md`, `diagrams/target_system/`, `diagrams/current_system/` |
| **Method baseline** | Tripathy & Naik — Ch.1, Ch.4 (re-engineering, forward engineering), Ch.5 (migration) |

> **This document is the forward-engineering (↓ refinement) artifact.** The as-is behaviour is in
> `PROJECT_OVERVIEW.md`; the alterations (Δ) are in `ALTERATION_DOCUMENT.md`; the target
> requirements are in `SRS_Target_System.md`. Here we elaborate the **design** of the new system —
> architecture, components, data, processes, behaviour and the **new features**.

---

## 1. Purpose and Scope

This design realises the target requirements (`SRS_Target_System.md`) as a concrete, buildable
structure. It covers the **re-engineered core** (preserving all legacy functionality) plus the
**new "current-world" features** that modernise the product (§3).

**Out of scope:** implementation code, SQL DDL, deployment scripts. The database is specified as a
**schema design** (diagram + data dictionary).

---

## 2. Design Principles

| Principle | Applied as |
|---|---|
| **Layered / N-tier** | Presentation → Application/Service → Domain → Data Access → Database; dependencies downward only |
| **Separation of concerns** | No UI holds SQL or business rules; only DAOs touch the DB |
| **Single responsibility / no god class** | Concerns split out of the legacy dashboard |
| **Transactional integrity** | Multi-step writes (sale, purchase, return) are one all-or-nothing operation |
| **Secure by default** | Parameterised SQL, hashed+salted passwords, RBAC, least privilege, lockout/2FA |
| **Portable & testable** | Externalised config; business logic separated from UI for automated tests |
| **Backward-compatible behaviour** | First pass preserves legacy workflow; only defects are corrected |

---

## 3. New Features (Modernisation)

These are the additions that bring the system up to date. Each maps to a requirement in the SRS.

| ID | Feature | Req. | Main design impact |
|----|---------|------|--------------------|
| **NC-01** | Multi-branch / multi-store | FR-16 | `branch` entity; branch scoping on users, stock, sales, purchases, prescriptions |
| **NC-02** | Barcode / QR scanning & generation | FR-17 | `drug.barcode` widened (EAN/UPC/QR); scanner input in POS & lookup |
| **NC-03** | Automated expiry & low-stock notifications | FR-18 | `notification` store + `SchedulerService` + email/SMS channel |
| **NC-04** | Analytics & BI dashboard | FR-19 | `AnalyticsService` over sales/stock aggregates (trends, profit, top drugs, stock value) |
| **NC-05** | Customer management + loyalty | FR-20/21 | `customer`, `loyalty_transaction`; loyalty accrual on sale |
| **NC-06** | Prescription management & dispensing | FR-22 | `prescription`, `prescription_item`; Rx-required flag on `drug` |
| **NC-07** | Sales returns & refunds | FR-23 | `sale_return`, `sale_return_item`; restock + status update, atomic |
| **NC-08** | Purchase-order workflow with approval | FR-24 | `purchase_order.status`, `approved_by/at`; typed lifecycle |
| **NC-09** | Tax / GST-compliant invoicing | FR-25 | `drug.tax_rate`, `sale.tax_amount`; PDF/print service |
| **NC-10** | Data export & backup/restore | FR-26 | `BackupExportService`; CSV/PDF export, scheduled backup |
| **NC-11** | REST API / integration & offline sync | FR-27 | API Gateway; mobile clients cache + sync |
| **NC-12** | Strong authentication | FR-28 | hashed+salted, `failed_attempts`/`locked_until`, reset, optional 2FA |

---

## 4. Architecture Design

### 4.1 Layers

| Layer | Responsibility | Contains |
|---|---|---|
| **Clients** | User interaction | Desktop (JavaFX), Web SPA, Mobile (offline+sync), barcode/QR scanner |
| **API Gateway** | AuthN (JWT), rate limiting, routing, versioning | REST API façade for all clients |
| **Presentation** | Render views, capture input (no SQL, no rules) | Login, Dashboard, POS, Inventory, Purchasing, Returns, Prescriptions, Customers, Analytics, Messaging views |
| **Application / Service** | Use-case logic, validation, transactions, authorization | AuthService, UserService, InventoryService, BatchService, SalesService, PurchaseService, ReturnService, PrescriptionService, CustomerLoyaltyService, NotificationService, AnalyticsService, ReportService, MessageService, AuditService, BackupExportService, SchedulerService |
| **Domain / Model** | Entities + business rules (pure, testable) | Drug, StockBatch, Sale/SaleItem, PurchaseOrder/Item, AppUser/Role, Company, Customer, Prescription, Return, Notification, Branch, Message |
| **Data Access (DAO/Repository)** | The **only** DB access; parameterised SQL/ORM; pooling; transactions | Repositories per aggregate, ConnectionPool, TransactionManager |
| **Database** | Persist data | MySQL/MariaDB `pharmacy_ng` (normalised) |
| **Cross-cutting** | Applied across layers | Configuration, Logging, Security/RBAC/JWT, Validation, Exception handling, Caching, Auditing, Scheduling, i18n |

**Rule:** dependencies point downwards only — this removes the legacy global `static` field bus.

### 4.2 Deployment (design)

Stateless application server(s) behind an API gateway/load balancer; a connection-pooled data
access layer to `pharmacy_ng`; outbound integrations to an **email/SMS gateway**, a
**printer/PDF service** and an optional **payment gateway**; mobile clients keep a local cache and
**synchronise** through the API.

See `diagrams/target_system/02_target_system_architecture.drawio` (page 2).

---

## 5. Component / Module Design

| Module | Services | Responsibilities |
|---|---|---|
| M1 Auth & Access | AuthService, UserService | login, logout, password change/reset, 2FA, RBAC, user & role management |
| M2 Dashboard | (UI) | role-aware navigation, alerts, date/time |
| M3 Inventory | InventoryService, BatchService | drugs, batches, storage place, price, restock, search/scan, FEFO |
| M4 Stock Intelligence | NotificationService, SchedulerService | expiry & low-stock detection, alert dispatch |
| M5 Purchasing | PurchaseService | supplier, purchase order lifecycle + approval, receiving |
| M6 Sales / POS | SalesService | billing, tax, stock decrement (FEFO), loyalty, invoices |
| M7 Returns | ReturnService | returns, refunds, restock, status updates |
| M8 Prescriptions | PrescriptionService | capture, validate, dispense against prescription |
| M9 Customers | CustomerLoyaltyService | customer records, loyalty accrual/redemption |
| M10 Reporting & Analytics | ReportService, AnalyticsService | shift/daily reports, dashboards, KPIs |
| M11 Messaging & Audit | MessageService, AuditService | internal messaging, login & action audit |
| M12 Platform | BackupExportService, API Gateway | export/backup, REST API, offline sync |

**Key rule:** no component opens its own DB connection; services own transactions; DAOs are the
only DB talkers.

---

## 6. Data Design (Schema)

Target database **`pharmacy_ng`** — normalised, **22 tables**, `utf8mb4`, surrogate keys, full
foreign keys. Full diagram: `diagrams/target_system/01_target_database_schema.drawio`.

### 6.1 Table groups

| Group | Tables |
|---|---|
| Reference | `role`, `drug_type`, `storage_place`, `branch` **(new)** |
| Master | `company`, `app_user`, `customer` **(new)**, `drug`, `stock_batch` |
| Purchasing | `purchase_order` (workflow **new**), `purchase_item` |
| Sales | `sale`, `sale_item`, `sale_return` **(new)**, `sale_return_item` **(new)**, `loyalty_transaction` **(new)** |
| Prescription | `prescription` **(new)**, `prescription_item` **(new)** |
| Notification / Audit | `notification` **(new)**, `login_audit`, `audit_log` **(new)** |
| Messaging | `message` |

### 6.2 What changed vs the legacy schema

- **Normalised** to 3NF: surrogate keys + real FKs (legacy had 5 tables without a PK and 1 FK).
- **Batch-based stock**: production/expiry/quantity/place moved off `drug` onto `stock_batch`.
- **Header/detail** sales & purchases (`sale`+`sale_item`, `purchase_order`+`purchase_item`).
- **Correct types**: `DATE`/`DATETIME`, `DECIMAL` money, `utf8mb4`.
- **Merged** `inbox`+`message_history` into `message`; **dropped** the orphan `expiry`.
- **Added** the new-feature tables/columns listed in §3 and the folder README.

### 6.3 Data migration (ETL)

One-time **Extract → Transform (+clean) → Load** from `pharmacy` (legacy) to `pharmacy_ng`:
`users.PASSWORD` → `password_hash` (hash+salt); `PLACE` → `storage_place`; `drugs` batch data →
`stock_batch`; `sales`+`history_sales` → `sale`+`sale_item`; `purchase` → `purchase_order`+`item`;
`login` → `login_audit`; `inbox`+`message_history` → `message`; new columns defaulted.

---

## 7. Process Design (DFD & Flowcharts)

- **DFD**: context (level 0) + level-1 decomposition into 10 processes and 9 data stores —
  `diagrams/target_system/03_target_dfd.drawio`.
- **Flowcharts**: POS sale (barcode, tax, FEFO, atomic), automated notifications, sales
  return/refund, prescription dispensing, purchase-order approval —
  `diagrams/target_system/04_target_flowcharts.drawio`.

---

## 8. Behaviour Design (Sequence & State)

- **POS sale sequence** — transactional: check stock → FEFO batch → insert sale/items → decrement
  batch → loyalty → audit → commit. Any failure rolls back.
- **Login sequence** — fetch user → lockout check → verify hash → optional 2FA → create session
  (role, branch) → audit. Invalid → generic error + failed-attempt counter.
- **State model** — `purchase_order`: `DRAFT → SUBMITTED → APPROVED → RECEIVED` / `CANCELLED`.

See `diagrams/target_system/06_target_designs.drawio`.

---

## 9. User-Interaction Design

Role-aware navigation replaces the legacy broken gate:

| Actor | Sees |
|---|---|
| **Admin** | everything + user/branch management + audit + analytics |
| **Branch Manager** | approvals, branch analytics, reports, warnings |
| **Pharmacist / Employee** | inventory, POS, returns, prescriptions, warnings, messaging |
| **Customer** | (self-service) their prescriptions/loyalty via a customer channel |
| **Supplier** | purchase orders / confirmations |
| **Scheduler (system)** | notifications, backups, sync (no UI) |

Use-case model: `diagrams/target_system/05_target_use_case.drawio`.

---

## 10. Design Decisions & Rationale

| Decision | Rationale |
|---|---|
| Layered / N-tier | Separates concerns; testable; removes the god class and static bus |
| Normalised 3NF schema | Removes redundancy; enforces integrity; real date/decimal types |
| Batch-based stock with FEFO | Correct inventory; expiry-aware selling |
| DAO + parameterised SQL + pool | Fixes injection; centralises access; performance |
| Hashed+salted passwords + RBAC + lockout/2FA | Removes credential exposure; real authorization |
| REST API + multi-client | Enables web/mobile/offline without rewriting the core |
| New-feature tables (customer, prescription, return, notification, branch) | Deliver the modern features while keeping the core intact |
| Externalised configuration | Portability and security |

---

## 11. Design Constraints

- **First pass preserves functionality** (equivalence testing); only defects are corrected.
- DAO layer is the **only** DB access point; UI holds no SQL/rules.
- All SQL parameterised; secrets externalised.
- Dates as `DATE`/`DATETIME`; money as `DECIMAL`.
- New features must not break the preserved core workflow.

---

## 12. Traceability (design → requirement)

| Design element | Requirements |
|---|---|
| AuthService / RBAC / lockout / 2FA | FR-01, FR-09, FR-15, FR-28 |
| InventoryService / BatchService | FR-03, FR-07, FR-10, FR-11, FR-17 |
| SalesService (POS, tax, FEFO) | FR-06, FR-25 |
| ReturnService | FR-23 |
| PrescriptionService | FR-22 |
| CustomerLoyaltyService | FR-20, FR-21 |
| PurchaseService (workflow) | FR-04, FR-05, FR-24 |
| NotificationService / SchedulerService | FR-12, FR-18 |
| AnalyticsService / ReportService | FR-08, FR-14, FR-19 |
| MessageService / AuditService | FR-13, FR-14, FR-29 |
| BackupExportService | FR-26 |
| API Gateway / sync | FR-27 |
| `branch` entity | FR-16 |

---

## 13. Summary

The target design turns the legacy 2-tier monolith into a **layered, secure, multi-branch,
API-enabled** system that keeps every existing function and adds modern capabilities
(analytics, notifications, prescriptions, returns, loyalty, purchasing workflow, barcode, tax
invoicing, backup, strong auth). The database is normalised; the UI is separated from logic; and
all behaviour is expressed through the target diagrams in `diagrams/target_system/`.

*Design artifact only — no source code or SQL is produced.*
