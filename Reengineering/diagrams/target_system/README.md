# Target-System Design Pack — Re-engineered Pharmacy Management System

**Design-only deliverables** for the **new (to-be)** system. No source code or SQL is produced —
the database is specified as a **schema design** (diagram + data dictionary).

> These diagrams sit alongside the **legacy/as-is** diagrams (`../` and `../current_system/`),
> which are kept unchanged for comparison. Only the *target* system is designed here.

## Files in this folder

| # | File | Diagram | What it shows |
|---|------|---------|---------------|
| 1 | `01_target_database_schema.drawio` | **New database schema** | 22 normalised tables + the tables added by the new features |
| 2 | `02_target_system_architecture.drawio` | **New system architecture** | Layered/N-tier + REST API + modern services (2 pages: layers, deployment) |
| 3 | `03_target_dfd.drawio` | **New DFD** | Context (level 0) + level-1 process/data-store decomposition |
| 4 | `04_target_flowcharts.drawio` | **New flowcharts** | POS sale, notifications, returns, prescription, PO approval |
| 5 | `05_target_use_case.drawio` | **New use-case diagram** | New actors + new use cases on top of the preserved ones |
| 6 | `06_target_designs.drawio` | **New designs** | Domain class diagram, sequence diagrams, state model |

**Open `.drawio` files** at <https://app.diagrams.net> (Open Existing Diagram), the draw.io desktop
app, or the VS Code *Draw.io Integration* extension; export to PNG/SVG/PDF for the report.

---

## New features added to the modernised system

| ID | Feature | Req. |
|----|---------|------|
| NC-01 | **Multi-branch / multi-store** support | FR-16 |
| NC-02 | **Barcode / QR scanning** & generation | FR-17 |
| NC-03 | **Automated expiry & low-stock notifications** (in-app / email / SMS) | FR-18 |
| NC-04 | **Analytics & BI dashboard** (trends, profit, top drugs, stock value) | FR-19 |
| NC-05 | **Customer management** + **loyalty programme** | FR-20, FR-21 |
| NC-06 | **Prescription management & dispensing** | FR-22 |
| NC-07 | **Sales returns & refunds** (with restock) | FR-23 |
| NC-08 | **Purchase-order workflow with approval** | FR-24 |
| NC-09 | **Tax / GST-compliant invoicing** (PDF / print) | FR-25 |
| NC-10 | **Data export & backup/restore** | FR-26 |
| NC-11 | **REST API / integration & offline-capable sync** | FR-27 |
| NC-12 | **Strong authentication**: reset, lockout, optional 2FA | FR-28 |

Full requirement text is in `../SRS_Target_System.md`.

---

## 1. New Database Schema (design)

22 tables in `pharmacy_ng`. **New tables/columns** are the ones that implement the new features.

```mermaid
erDiagram
    role ||--o{ app_user : has
    branch ||--o{ app_user : "home of"
    branch ||--o{ customer : "registered at"
    branch ||--o{ stock_batch : "stored at"
    branch ||--o{ sale : "made at"
    branch ||--o{ purchase_order : "raised by"
    branch ||--o{ prescription : "issued at"
    drug_type ||--o{ drug : classifies
    company ||--o{ drug : supplies
    company ||--o{ purchase_order : "supplied by"
    drug ||--o{ stock_batch : "stocked as"
    storage_place ||--o{ stock_batch : "kept in"
    purchase_order ||--o{ purchase_item : contains
    drug ||--o{ purchase_item : "line of"
    sale ||--o{ sale_item : contains
    drug ||--o{ sale_item : "line of"
    stock_batch ||--o{ sale_item : "consumed by"
    app_user ||--o{ sale : "cashier of"
    customer ||--o{ sale : "buyer of"
    sale ||--o{ sale_return : "returned by"
    sale_return ||--o{ sale_return_item : contains
    sale_item ||--o{ sale_return_item : "returns"
    customer ||--o{ loyalty_transaction : earns
    sale ||--o{ loyalty_transaction : "generates"
    customer ||--o{ prescription : "has"
    prescription ||--o{ prescription_item : contains
    drug ||--o{ prescription_item : "prescribed as"
    drug ||--o{ notification : "about"
    app_user ||--o{ login_audit : "logs in"
    app_user ||--o{ audit_log : "acts"
    app_user ||--o{ message : "sends/receives"

    role { int role_id PK
           varchar role_name }
    branch { int branch_id PK
             varchar name }
    app_user { int user_id PK
               varchar password_hash
               int role_id FK
               int branch_id FK
               tinyint failed_attempts }
    customer { int customer_id PK
               int loyalty_points
               int branch_id FK }
    drug { int drug_id PK
           varchar barcode
           decimal tax_rate
           boolean is_prescription
           int reorder_level }
    stock_batch { int batch_id PK
                  int drug_id FK
                  int branch_id FK
                  date expiration_date
                  int quantity }
    sale { int sale_id PK
           varchar invoice_no
           decimal tax_amount
           decimal total_amount
           int customer_id FK }
    sale_return { int return_id PK
                  int sale_id FK
                  decimal total_refund }
    prescription { int prescription_id PK
                   int customer_id FK
                   varchar doctor_name
                   date issued_date }
    notification { int notification_id PK
                   varchar type
                   varchar channel
                   varchar status }
```

**Data dictionary (new objects only):**

| Table / column | Purpose | Feature |
|---|---|---|
| `branch` | store/branch master | NC-01 |
| `app_user.branch_id`, `is_active`, `failed_attempts`, `locked_until`, `email` | branch scoping + lockout/reset | NC-01, NC-12 |
| `customer`, `loyalty_transaction` | customers + loyalty ledger | NC-05 |
| `prescription`, `prescription_item` | prescriptions & dispensing | NC-06 |
| `sale.customer_id`, `subtotal`, `tax_amount`, `discount`, `payment_method`, `status` | tax invoice + customer + returns status | NC-05, NC-07, NC-09 |
| `sale_item.batch_id`, `tax_rate` | FEFO consumption + tax | NC-02, NC-09 |
| `sale_return`, `sale_return_item` | returns/refunds with restock | NC-07 |
| `purchase_order.status`, `approved_by`, `approved_at` | PO workflow/approval | NC-08 |
| `drug.tax_rate`, `is_prescription`, `is_active`; `drug.barcode` widened | tax, Rx-only, soft-delete, EAN/QR | NC-02, NC-06, NC-09 |
| `notification` | expiry/low-stock alerts + channel/status | NC-03 |
| `audit_log`; `login_audit.ip_address`, `success` | action audit + stronger login audit | NC-12 |

## 2. New System Architecture

```mermaid
flowchart TB
    subgraph CL["Clients"]
      D[Desktop app - JavaFX]
      W[Web SPA]
      M[Mobile app - offline+sync]
      S[Barcode / QR scanner]
    end
    G[API Gateway / REST API - JWT, rate limit]
    subgraph P["Presentation"]
      V[Views - MVC/MVVM - no SQL, no rules]
    end
    subgraph SVC["Application / Service layer"]
      A1[AuthService]:::s
      A2[UserService]:::s
      A3[InventoryService]:::s
      A4[BatchService]:::s
      A5[SalesService POS]:::s
      A6[PurchaseService]:::s
      A7[ReturnService]:::s
      A8[PrescriptionService]:::s
      A9[CustomerLoyaltyService]:::s
      A10[NotificationService]:::s
      A11[AnalyticsService]:::s
      A12[ReportService]:::s
      A13[MessageService]:::s
      A14[AuditService]:::s
      A15[BackupExportService]:::s
      A16[SchedulerService]:::s
    end
    DM[Domain / Model - entities + rules]
    DAO[Data Access - DAO/Repository · pool · transactions]
    DB[(MySQL/MariaDB pharmacy_ng)]
    CL --> G --> P --> SVC --> DM --> DAO --> DB
    classDef s fill:#d5e8d4,stroke:#82b366;
```

Dependencies point **downwards only**. Cross-cutting: config, logging, security/RBAC/JWT,
validation, error handling, caching, auditing, scheduling, i18n.

## 3. New DFD

**Level 0 (context):** external entities Admin, Pharmacist, **Branch Manager**, **Customer**,
**Supplier**, **Email/SMS Gateway**, **Printer/Payment**; one process = *Pharmacy Management System*.

```mermaid
flowchart LR
    Admin[Admin] --> P((0 Pharmacy\nManagement\nSystem))
    Pharm[Pharmacist] --> P
    Mgr[Branch Manager] --> P
    Cust[Customer] --> P
    Sup[Supplier] --> P
    P --> Notif[Email/SMS Gateway]
    P --> Cust
    P --> Sup
    P --> Print[Printer/Payment]
```

**Level 1:** processes and data stores (D = data store):

```mermaid
flowchart LR
    Admin[Admin] --> P1((1.0 Auth & Access))
    Pharm[Pharmacist] --> P2((2.0 Inventory))
    Mgr[Branch Manager] --> P3((3.0 Purchasing))
    Pharm --> P4((4.0 Sales/POS))
    Pharm --> P5((5.0 Returns))
    Cust[Customer] --> P6((6.0 Prescriptions))
    Cust --> P7((7.0 Customers & Loyalty))
    P8((8.0 Notifications)) --> Notif[Email/SMS]
    P9((9.0 Reporting & Analytics))
    P10((10.0 Messaging & Audit))

    P1 --- D1[(D1 app_user, role, branch)]
    P2 --- D2[(D2 drug, drug_type, stock_batch, storage_place)]
    P3 --- D3[(D3 company, purchase_order, purchase_item)]
    P4 --- D4[(D4 sale, sale_item)]
    P5 --- D5[(D5 sale_return, sale_return_item)]
    P6 --- D6[(D6 prescription, prescription_item)]
    P7 --- D7[(D7 customer, loyalty_transaction)]
    P8 --- D8[(D8 notification)]
    P10 --- D9[(D9 audit_log, login_audit, message)]
```

## 4. New Flowcharts

```mermaid
flowchart TD
    S([START]) --> A[Scan / type barcode]
    A --> Q{Drug found?}
    Q -- No --> X[/unknown barcode/]
    Q -- Yes --> RX{Prescription required?}
    RX -- Yes --> V[Verify prescription FR-22] --> ST
    RX -- No --> ST{Stock available? sum batches}
    ST -- No --> R[/Reject insufficient stock/]
    ST -- Yes --> F[Select FEFO batch · compute amount + tax]
    F --> M{More items?}
    M -- Yes --> A
    M -- No --> C[Attach customer · loyalty]
    C --> PAY{Payment OK?}
    PAY -- Yes --> TX["TRANSACTION: insert sale + items · decrement batch FEFO · loyalty · audit → COMMIT"]
    TX --> PR[/Print / PDF invoice/] --> E([END])
    PAY -- No --> E
```

Other target flowcharts (in the `.drawio`): **automated notifications**, **sales return/refund**,
**prescription dispensing**, **purchase-order approval**.

## 5. New Use-Case Diagram

```mermaid
flowchart LR
    Admin((Admin))
    Mgr((Branch Manager))
    Pharm((Pharmacist))
    Cust((Customer))
    Sup((Supplier))
    Sched((Scheduler))

    subgraph SYS["Pharmacy Management System (re-engineered)"]
      UC1((Login))
      UC2((Change Password))
      UC3((Reset Password / 2FA))
      UC4((Manage Users))
      UC5((Manage Branches))
      UC6((View Login History / Audit))
      UC7((Send / Read Messages))
      UC8((Manage Drugs))
      UC9((Manage Companies))
      UC10((Search / Scan Drug))
      UC11((Move Drug / Edit Price))
      UC12((Renew Validity / Restock))
      UC13((View Expiry / Stock Warnings))
      UC14((Create Sale / Bill POS))
      UC15((Manage Customers))
      UC16((Loyalty Points))
      UC17((Manage Prescriptions))
      UC18((Dispense Prescription))
      UC19((Record Purchase))
      UC20((Approve Purchase Order))
      UC21((Process Return / Refund))
      UC22((Analytics Dashboard))
      UC23((Export / Backup & Restore))
      UC24((Generate Notifications))
      UC25((Sync via REST API))
    end

    Admin --> UC1
    Admin --> UC4
    Admin --> UC5
    Admin --> UC6
    Admin --> UC22
    Mgr --> UC20
    Mgr --> UC5
    Mgr --> UC22
    Pharm --> UC8
    Pharm --> UC10
    Pharm --> UC14
    Pharm --> UC18
    Pharm --> UC21
    Pharm --> UC13
    Cust --> UC15
    Cust --> UC16
    Cust --> UC17
    Sup --> UC19
    Sup --> UC20
    Sched --> UC24
    Sched --> UC23
    Sched --> UC25
```

## 6. New Designs (class / sequence / state)

**Domain class model** (key classes): `Branch`, `Role`, `Company`, `DrugType`, `AppUser`, `Drug`,
`StoragePlace`, `Prescription`, `StockBatch`, `Customer`, `Sale`, `PurchaseOrder`, `SaleItem`,
`SaleReturn`, `PurchaseItem`, `Notification`, `LoyaltyTransaction`, `PrescriptionItem`,
`SaleReturnItem`, `Message` — full detail in `06_target_designs.drawio`.

**Sequence — POS sale (transactional, FEFO, tax, loyalty):**

```mermaid
sequenceDiagram
    actor P as Pharmacist
    participant V as POS View
    participant SS as SalesService
    participant IS as InventoryService
    participant SD as SaleDAO
    participant DB as pharmacy_ng

    P->>V: scan barcode / add item
    V->>SS: createSale(items, customer, branch, user)
    SS->>IS: checkStock(drug, qty)
    IS->>DB: SELECT batches ORDER BY expiration_date (FEFO)
    IS-->>SS: available = true
    SS->>SD: beginTransaction()
    SD->>DB: INSERT sale + sale_item(s)
    SS->>IS: decrementBatch(batch, qty)
    SS->>SD: update loyalty + write audit_log
    SS->>DB: COMMIT
    SS-->>P: invoice (print / PDF)
    Note over SS,DB: any failure → rollback (no partial sale)
```

**Sequence — login (hashed password, RBAC, optional 2FA):**

```mermaid
sequenceDiagram
    actor U as User
    participant LV as LoginView
    participant AS as AuthService
    participant UD as UserDAO
    participant NS as NotificationService
    participant AU as AuditService

    U->>LV: credentials
    LV->>AS: authenticate(name, pwd)
    AS->>UD: findByName(name)
    UD-->>AS: app_user + role + branch
    AS->>AS: isLocked? verify hash → ok
    AS->>NS: [if 2FA] send one-time code
    NS-->>AS: 2FA verified
    AS->>AU: create session (role, branch)
    AU->>UD: write login_audit + audit_log
    AS-->>LV: session token
    LV-->>U: open role-based dashboard
    Note over AS,UD: invalid → generic error, increment failed_attempts, lock after N
```

**State model — purchase order:** `DRAFT → SUBMITTED → APPROVED → RECEIVED`; `SUBMITTED/DRAFT → CANCELLED`.

---

## Summary — what the target design changes

| Aspect | Legacy | Target |
|---|---|---|
| Architecture | 2-tier monolith | Layered/N-tier + REST API (desktop/web/mobile) |
| Scope | single shop | **multi-branch** |
| Inventory | quantity on `drugs` | per-batch, FEFO, multi-branch |
| Sales | flat `sales` + `history_sales`, non-transactional | `sale` + `sale_item`, **atomic**, tax, customer |
| Extras | — | returns, prescriptions, loyalty, analytics, notifications, PO approval, backup, API |
| Security | plain text, injection, broken gate | hashed+salted, parameterised, RBAC, lockout/2FA, audit |
| Database | 10 flat tables, 1 FK | 22 normalised tables, full FKs, utf8mb4 |
