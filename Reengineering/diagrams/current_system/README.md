# Current-System Diagram Pack — Pharmacy Management System

Complete set of **as-is (current system)** diagrams for the Pharmacy Management System,
recovered by reverse engineering the legacy 2-tier Swing application and its `pharmacy` database.

> All facts are taken from the actual source (`src/main/*.java`), the database dump
> (`../../../pharmacy.sql`) and the recovered design in `../../Design_Document.md`.

## Files in this folder

| # | File | Diagram | What it shows |
|---|------|---------|---------------|
| 1 | `01_database_schema_diagram.drawio` | **Database schema (tables)** | The 10 legacy tables, PK/FK, the only real FK, and schema problems |
| 2 | `02_current_system_diagram.drawio` | **Current system diagram** | As-is 2-tier monolith: users → frames → `Connect` → MySQL |
| 3 | `03_use_case_diagram.drawio` | **Use-case diagram** | Actors (Admin, Employee) and the 15 recovered use cases |
| 4 | `04_sequence_diagram.drawio` | **Sequence diagram** | 3 pages: Login, Create Sale/Bill, Record Purchase |
| 5 | `05_flowcharts.drawio` | **Flowcharts** | 4 pages: Login, Sale, Purchase, Expiry/Stock warnings |
| 6 | `06_module_diagram.drawio` | **Module diagram** | How modules M1–M8 connect through the hub and share the DB |

### How to open the `.drawio` files
- **Web:** <https://app.diagrams.net> → *Open Existing Diagram* → pick the file.
- **Desktop:** draw.io Desktop.
- **VS Code:** the *Draw.io Integration* extension (double-click the file).
- **Export:** from diagrams.net export to PNG / SVG / PDF for your report.
- Files are plain XML and also open in any text editor.

The same diagrams are reproduced below as **Mermaid** so they render directly on GitHub.

---

## 1. Database Schema Diagram (current / legacy — tables)

```mermaid
erDiagram
    company {
        varchar NAME PK
        varchar ADDRESS
        varchar PHONE
    }
    drugs {
        varchar BARCODE PK
        varchar NAME
        varchar TYPE
        varchar DOSE
        varchar CODE
        double COST_PRICE
        double SELLING_PRICE
        varchar EXPIRY
        varchar COMPANY_NAME "no FK"
        date PRODUCTION_DATE
        date EXPIRATION_DATE
        varchar PLACE
        int QUANTITY
    }
    purchase {
        varchar BARCODE PK
        varchar NAME
        varchar TYPE
        varchar COMPANY_NAME FK
        int QUANTITY
        double PRICE
        double AMOUNT
    }
    sales {
        varchar BARCODE "no PK"
        varchar NAME
        varchar TYPE
        varchar DOSE
        int QUANTITY
        double PRICE
        double AMOUNT
        varchar DATE
    }
    history_sales {
        varchar USER_NAME "no PK"
        varchar BARCODE
        varchar NAME
        varchar TYPE
        varchar DOSE
        int QUANTITY
        double PRICE
        double AMOUNT
        varchar DATE
        varchar TIME
    }
    users {
        int ID PK
        varchar NAME
        varchar DOB
        varchar ADDRESS
        varchar PHONE
        double SALARY
        varchar PASSWORD "plain text"
    }
    login {
        varchar NAME "no PK"
        varchar TYPE
        varchar DATE
        varchar TIME
    }
    inbox {
        varchar MESSAGE_FROM "no PK"
        varchar MESSAGE_TO
        varchar MESSAGE_TEXT
    }
    message_history {
        varchar MESSAGE_FROM "no PK"
        varchar MESSAGE_TO
        varchar MESSAGE_TEXT
    }
    expiry {
        varchar PRODUCT_NAME "orphan"
        varchar PRODUCT_CODE
        varchar DATE_OF_EXPIRY
        int QUANTITY_REMAIN
    }

    company ||--o{ purchase : "FK fkr3 (cascade)"
    company ||--o{ drugs : "implied only, NO FK"
    drugs ||--o{ purchase : "implied by BARCODE"
    drugs ||--o{ sales : "implied by BARCODE"
    drugs ||--o{ history_sales : "implied by BARCODE"
    users ||--o{ login : "implied by NAME"
    users ||--o{ inbox : "implied by MESSAGE_FROM/TO"
    users ||--o{ history_sales : "implied by USER_NAME"
```

**Problems:** denormalisation (name/type/dose/price copied into sales/purchase/history_sales) ·
no PK on `sales`, `history_sales`, `login`, `inbox`, `message_history` ·
`drugs.COMPANY_NAME` has no FK · dates stored as `varchar` · plain-text passwords ·
duplicate `inbox` = `message_history` · orphan `expiry` · `latin1` encoding.

---

## 2. Current System Diagram (as-is architecture)

```mermaid
flowchart TB
    Admin["👤 Admin"]
    Emp["👤 Employee / Pharmacist"]

    subgraph P["Presentation layer — Swing / AWT JFrames (Matisse)"]
        Main["Main (entry point)"]
        LoginF["Login — static Login.id / NAME"]
        Hub["Pharmacy — DASHBOARD HUB (1,520 LOC)\nstatic bus: username1 / today / ex / expired_bar"]
        Frames["22 further JFrames — each embeds raw SQL\ninside its event handlers; 102 concatenated statements"]
    end

    Connect["Connect.java — static helper\nDriverManager.getConnection(url, 'root', '')\nnew connection on EVERY call"]
    DB[("MySQL / MariaDB — database pharmacy\n10 flat denormalised tables · InnoDB · latin1")]

    Admin --> LoginF
    Emp --> LoginF
    Main --> LoginF
    LoginF --> Hub
    Hub --> Frames
    Frames --> Connect
    Hub --> Connect
    Connect --> DB

    note["SEMI-DECOMPOSABLE:\nframes and SQL are inseparable;\nonly the DB boundary is clean (via Connect)"]
```

---

## 3. Use-Case Diagram (current system)

```mermaid
flowchart LR
    Admin(("Admin"))
    Emp(("Employee / Pharmacist"))

    subgraph SYS["Pharmacy Management System (legacy desktop app)"]
        UC1(("Login / Authenticate"))
        UC2(("Manage Users"))
        UC3(("Manage Drugs"))
        UC4(("Manage Companies"))
        UC5(("Record Purchase"))
        UC6(("Create Sale / Bill (POS)"))
        UC7(("Search Drug"))
        UC8(("View Reports / Audit"))
        UC9(("Change Password"))
        UC10(("Move Drug / Edit Price"))
        UC11(("Renew Validity / Restock"))
        UC12(("View Expiry / Stock Warnings"))
        UC13(("Send / Read Messages"))
        UC14(("View Login History"))
        UC15(("Navigate Dashboard (hub)"))
    end

    Admin --> UC1
    Admin --> UC2
    Admin --> UC3
    Admin --> UC4
    Admin --> UC5
    Admin --> UC6
    Admin --> UC8
    Admin --> UC9
    Admin --> UC11
    Admin --> UC13
    Admin --> UC14

    Emp --> UC1
    Emp --> UC3
    Emp --> UC4
    Emp --> UC5
    Emp --> UC6
    Emp --> UC7
    Emp --> UC10
    Emp --> UC12
    Emp --> UC13
    Emp --> UC15

    UC5 -.->|include| UC4
```

---

## 4. Sequence Diagrams (current system)

### 4a. Login / Authenticate

```mermaid
sequenceDiagram
    actor U as User (Admin/Employee)
    participant L as :Login (JFrame)
    participant C as :Connect (static helper)
    participant DB as MySQL: users
    participant P as :Pharmacy (dashboard)

    U->>L: 1: enter ID & Password, click "Login"
    L->>L: 2: validate fields not empty
    L->>C: 3: connect()
    C->>DB: 4: getConnection(jdbc:mysql://localhost/pharmacy, "root", "")
    DB-->>C: 5: Connection
    C-->>L: 6: Connection con
    L->>DB: 7: SELECT ID,NAME,PASSWORD FROM users WHERE ID='{input}'  (string concat!)
    DB-->>L: 8: ResultSet
    L->>L: 9: compare PASSWORD (plain text)
    alt password OK
        L->>P: 10: new Pharmacy(); dispose()
        P-->>U: 11: show dashboard
    else wrong
        L-->>U: 12: "Wrong Password" / "Wrong ID"
    end
    Note over L,DB: SQL injection · plain-text password · identical if/else branches · connection per frame
```

### 4b. Create Sale / Bill (POS)

```mermaid
sequenceDiagram
    actor E as Employee
    participant B as :Sales_Bill
    participant C as :Connect
    participant D as DB: drugs
    participant S as DB: sales
    participant H as DB: history_sales

    E->>B: 1: enter Barcode + Quantity, click "Get_Bill"
    B->>B: 2: validate inputs
    B->>B: 3: check_Bill() duplicate barcode+qty?
    B->>C: 4: connect()
    C-->>B: 5: Connection
    B->>D: 6: SELECT ... FROM drugs WHERE BARCODE='{input}'
    D-->>B: 7: row
    B->>B: 8: alt EXPIRY='Expired' → offer Renew_Validity
    B->>S: 9: INSERT INTO sales (...)
    B->>D: 10: UPDATE drugs SET QUANTITY = rest_drug
    B->>H: 11: INSERT INTO history_sales (...)
    B->>S: 12: get_Total() SELECT AMOUNT FROM sales (loop)
    S-->>B: 13: AMOUNT rows
    B-->>E: 14: show bill + total
    Note over B,H: NOT transactional (auto-commit) · raw SQL · get_Total() accumulation bug
```

### 4c. Record Purchase

```mermaid
sequenceDiagram
    actor A as Admin / Employee
    participant B as :Buy_Drug
    participant C as :Connect
    participant CO as DB: company
    participant P as DB: purchase

    A->>B: 1: open form, enter purchase details
    B->>C: 2: connect()
    C-->>B: 3: Connection
    B->>CO: 4: SELECT NAME FROM company
    CO-->>B: 5: company list
    B->>B: 6: validate fields
    B->>P: 7: INSERT / UPDATE / DELETE purchase (raw SQL)
    P-->>B: 8: affected rows
    B-->>A: 9: confirmation dialog
    Note over P,CO: purchase.COMPANY_NAME is the ONLY declared FK (fkr3 → company, cascade)
```

---

## 5. Flowcharts (current system)

### 5a. Login

```mermaid
flowchart TD
    S([START]) --> A[Enter User_ID and Password, click Login]
    A --> D1{Fields empty?}
    D1 -- Yes --> I1[/Show "Complete Your Login Information"/] --> A
    D1 -- No --> Q[SELECT ID,NAME,PASSWORD FROM users<br/>WHERE ID = input]
    Q --> D2{Row with this ID found?}
    D2 -- No --> I2[/Show "Wrong ID"/] --> E([END])
    D2 -- Yes --> D3{Password matches?}
    D3 -- No --> I3[/Show "Wrong Password"/] --> E
    D3 -- Yes --> P[NAME = res.NAME; new Pharmacy();<br/>dispose(); show dashboard] --> E
```

### 5b. Create Sale / Bill (POS)

```mermaid
flowchart TD
    S([START]) --> A[Enter Barcode + Quantity, click Get_Bill]
    A --> D1{Inputs complete?}
    D1 -- No --> I1[/"Missing Information"/] --> A
    D1 -- Yes --> D2{Duplicate barcode+qty in sales?}
    D2 -- Yes --> D2b{Confirm repeat?}
    D2b -- No --> Q
    D2 -- No --> Q[SELECT drug by BARCODE]
    Q --> D3{Drug found?}
    D3 -- No --> I2[/Show error/] --> E([END])
    D3 -- Yes --> D4{EXPIRY = 'Expired'?}
    D4 -- Yes --> R[/Offer Renew_Validity/] --> P1
    D4 -- No --> P1[INSERT INTO sales]
    P1 --> P2[UPDATE drugs SET QUANTITY = rest_drug]
    P2 --> P3[INSERT INTO history_sales ... DATE,TIME]
    P3 --> P4["get_Total(): loop SELECT AMOUNT FROM sales (BUG); refresh()"]
    P4 --> E
```

### 5c. Record Purchase

```mermaid
flowchart TD
    S([START]) --> A[Open Buy_Drug; populate Company combo]
    A --> B[Enter Barcode, Name, Type, Company, Qty, Cost]
    B --> D{Which action?}
    D -- Insert --> I[INSERT INTO purchase]
    D -- Update --> U[UPDATE purchase SET ...]
    D -- Delete --> X[DELETE FROM purchase WHERE BARCODE=input]
    I --> F[Rebuild table + confirmation]
    U --> F
    X --> F
    F --> E([END])
```

### 5d. Expiry & Stock Warnings (M4)

```mermaid
flowchart TD
    S([START]) --> A[SELECT * FROM drugs — scan stock]
    A --> D1{"EXPIRATION_DATE before today? (varchar parsed with split)"}
    D1 -- Yes --> P1[List in Expired_Drug / offer Renew_Validity]
    D1 -- No --> D2
    P1 --> D2{"QUANTITY below 10? (hard-coded threshold)"}
    D2 -- Yes --> P2[List in Almost_Finish]
    D2 -- No --> P3[Show Warning / Warning_List] --> E([END])
    P2 --> P3
```

---

## 6. Module Diagram (how modules are connected)

```mermaid
flowchart TB
    M1["M1 — Authentication & Session\nLogin · Change_Password · changestyle"]
    M3["M3 — Drug Inventory\nDrug · Drug_List · Search_Drug · Move_Drug · Edit_Price"]
    M4["M4 — Expiry & Stock Alerts\nExpired_Drug · Almost_Finish · Warning · Warning_List · Renew_Validity"]
    M8["M8 — Messaging\nInbox · Send · Show_Message"]
    M5["M5 — Purchasing\nBuy_Drug · All_Deal"]

    M2["M2 — DASHBOARD / NAVIGATION (HUB)\nPharmacy (1,520 LOC) · Main\nglobal static bus: username1 / today / ex / expired_bar"]

    M6["M6 — Sales / Billing (POS)\nSales_Bill · Retrieval_Drug (stub)"]
    M7["M7 — Reporting / Audit\nShift_Sales · Login_Details"]
    Infra["INFRASTRUCTURE\nConnect · User · Company"]

    DB[("SHARED DATABASE `pharmacy`\ncompany · drugs · purchase · sales · history_sales · users · login · inbox · message_history · expiry")]

    M1 -->|login OK| M2
    M2 --> M3
    M2 --> M4
    M2 --> M8
    M2 --> M5
    M2 --> M6
    M2 --> M7
    M2 -->|new X.setVisible true| Infra

    M1 -.->|users, login| DB
    M3 -.->|drugs| DB
    M4 -.->|drugs| DB
    M5 -.->|purchase, company| DB
    M6 -.->|drugs, sales, history_sales| DB
    M7 -.->|history_sales, login| DB
    M8 -.->|inbox, message_history| DB
```

**Reading it:** all navigation radiates from the `Pharmacy` hub (star topology); every module
talks straight to its own tables (no shared data layer); the global `static` field bus couples
the frames → the hub carries the system's highest coupling (Henry–Kafura `Cp`).

---

## Summary of the current system

| Aspect | Current (as-is) state |
|---|---|
| Architecture | 2-tier Java SE desktop monolith (Swing), no service/DAO/domain layers |
| Decomposability | Semi-decomposable — clean seam only at the DB boundary (`Connect.java`) |
| Modules | 8 recovered functional modules M1–M8 + infrastructure, coupled via the `Pharmacy` hub |
| Data access | Raw string-concatenated SQL inside Swing event handlers (102 statements / 21 files) |
| Security | SQL injection everywhere, plain-text passwords, hard-coded `root` blank-password DB account |
| Database | 10 flat denormalised tables, 5 without a PK, 1 real FK, `varchar` dates, orphan `expiry` |
| Quality | God class (`Pharmacy`, 1,520 LOC), duplicated boilerplate, dead code, no tests, no CI |
