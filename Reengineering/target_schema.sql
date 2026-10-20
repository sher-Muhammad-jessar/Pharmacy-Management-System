-- =====================================================================
--  PHARMACY MANAGEMENT SYSTEM  --  TARGET (TO-BE) DATABASE SCHEMA
--  Deliverable of the Software Re-engineering project (design artifact).
--  Engine: MySQL / MariaDB
--
--  NOTE: This is a DESIGN artifact produced by Data Reverse Engineering
--        (Ch.4 §4.8) + data re-engineering. It does NOT modify the
--        existing application code or the existing pharmacy.sql dump.
--
--  Derived from the legacy schema `pharmacy` by:
--    (1) Data-structure extraction   (DDL text analysis + program analysis)
--    (2) Data-structure conceptualization (untranslate + normalise)
-- =====================================================================

CREATE DATABASE IF NOT EXISTS pharmacy_ng
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

USE pharmacy_ng;

-- ---------------------------------------------------------------------
-- LOOKUP / REFERENCE TABLES
-- ---------------------------------------------------------------------

CREATE TABLE role (
  role_id     INT          NOT NULL AUTO_INCREMENT,
  role_name   VARCHAR(20)  NOT NULL,
  PRIMARY KEY (role_id),
  UNIQUE KEY uq_role_name (role_name)
) ENGINE=InnoDB;

CREATE TABLE drug_type (
  type_id     INT          NOT NULL AUTO_INCREMENT,
  type_name   VARCHAR(20)  NOT NULL,
  PRIMARY KEY (type_id),
  UNIQUE KEY uq_type_name (type_name)
) ENGINE=InnoDB;

CREATE TABLE storage_place (
  place_id    INT          NOT NULL AUTO_INCREMENT,
  section     VARCHAR(20)  NOT NULL,     -- e.g. 'N'
  shelf       VARCHAR(20)  NOT NULL,     -- e.g. 'Right'
  PRIMARY KEY (place_id),
  UNIQUE KEY uq_place (section, shelf)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- MASTER DATA
-- ---------------------------------------------------------------------

CREATE TABLE company (
  company_id  INT          NOT NULL AUTO_INCREMENT,
  name        VARCHAR(50)  NOT NULL,
  address     VARCHAR(50)  NOT NULL,
  phone       VARCHAR(20)  NOT NULL,
  PRIMARY KEY (company_id),
  UNIQUE KEY uq_company_name (name)
) ENGINE=InnoDB;

CREATE TABLE app_user (
  user_id        INT            NOT NULL AUTO_INCREMENT,
  name           VARCHAR(50)    NOT NULL,
  dob            DATE           NULL,               -- was varchar(20) '23-12-1995'
  address        VARCHAR(100)   NOT NULL,
  phone          VARCHAR(20)    NOT NULL,
  salary         DECIMAL(10,2)  NOT NULL,
  password_hash  VARCHAR(255)   NOT NULL,           -- was plain text varchar(20)
  role_id        INT            NOT NULL,
  PRIMARY KEY (user_id),
  UNIQUE KEY uq_user_name (name),
  CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES role (role_id)
) ENGINE=InnoDB;

CREATE TABLE drug (
  drug_id        INT            NOT NULL AUTO_INCREMENT,
  barcode        VARCHAR(20)    NOT NULL,
  name           VARCHAR(50)    NOT NULL,
  drug_type_id   INT            NOT NULL,
  dose           VARCHAR(10)    NOT NULL,
  code           VARCHAR(10)    NOT NULL,
  cost_price     DECIMAL(10,2)  NOT NULL,
  selling_price  DECIMAL(10,2)  NOT NULL,
  company_id     INT            NOT NULL,           -- was COMPANY_NAME text, NO FK
  reorder_level  INT            NOT NULL DEFAULT 10,-- replaces the hard-coded "< 10"
  PRIMARY KEY (drug_id),
  UNIQUE KEY uq_drug_barcode (barcode),
  CONSTRAINT fk_drug_type    FOREIGN KEY (drug_type_id) REFERENCES drug_type (type_id),
  CONSTRAINT fk_drug_company FOREIGN KEY (company_id)   REFERENCES company (company_id)
) ENGINE=InnoDB;

-- A drug has MANY batches: production/expiry date + quantity + place
-- belong to the BATCH, not to the drug (legacy stored them on `drugs`).
CREATE TABLE stock_batch (
  batch_id        INT            NOT NULL AUTO_INCREMENT,
  drug_id         INT            NOT NULL,
  production_date DATE           NULL,
  expiration_date DATE           NULL,              -- enables real expiry logic
  quantity        INT            NOT NULL DEFAULT 0,-- the old drugs.QUANTITY lives here
  cost_price      DECIMAL(10,2)  NOT NULL,
  place_id        INT            NOT NULL,          -- was drugs.PLACE 'N-Right'
  PRIMARY KEY (batch_id),
  KEY idx_batch_drug (drug_id),
  KEY idx_batch_expiry (expiration_date),
  CONSTRAINT fk_batch_drug  FOREIGN KEY (drug_id)  REFERENCES drug (drug_id),
  CONSTRAINT fk_batch_place FOREIGN KEY (place_id) REFERENCES storage_place (place_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- PURCHASING  (normalises old flat `purchase`)
-- ---------------------------------------------------------------------

CREATE TABLE purchase_order (
  po_id         INT            NOT NULL AUTO_INCREMENT,
  company_id    INT            NOT NULL,
  order_date    DATE           NOT NULL,
  total_amount  DECIMAL(10,2)  NOT NULL DEFAULT 0,
  PRIMARY KEY (po_id),
  CONSTRAINT fk_po_company FOREIGN KEY (company_id) REFERENCES company (company_id)
) ENGINE=InnoDB;

CREATE TABLE purchase_item (
  po_item_id  INT            NOT NULL AUTO_INCREMENT,
  po_id       INT            NOT NULL,
  drug_id     INT            NOT NULL,
  quantity    INT            NOT NULL,
  unit_price  DECIMAL(10,2)  NOT NULL,
  amount      DECIMAL(10,2)  NOT NULL,
  PRIMARY KEY (po_item_id),
  CONSTRAINT fk_poitem_po   FOREIGN KEY (po_id)   REFERENCES purchase_order (po_id),
  CONSTRAINT fk_poitem_drug FOREIGN KEY (drug_id) REFERENCES drug (drug_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- SALES  (normalises old flat `sales` + `history_sales`)
-- ---------------------------------------------------------------------

CREATE TABLE sale (
  sale_id        INT            NOT NULL AUTO_INCREMENT,
  invoice_no     VARCHAR(20)    NOT NULL,
  user_id        INT            NOT NULL,   -- cashier (old history_sales.USER_NAME)
  sale_datetime  DATETIME       NOT NULL,   -- old DATE + TIME as varchar
  total_amount   DECIMAL(10,2)  NOT NULL DEFAULT 0,
  PRIMARY KEY (sale_id),
  UNIQUE KEY uq_invoice (invoice_no),
  CONSTRAINT fk_sale_user FOREIGN KEY (user_id) REFERENCES app_user (user_id)
) ENGINE=InnoDB;

CREATE TABLE sale_item (
  sale_item_id  INT            NOT NULL AUTO_INCREMENT,
  sale_id       INT            NOT NULL,
  drug_id       INT            NOT NULL,
  quantity      INT            NOT NULL,
  unit_price    DECIMAL(10,2)  NOT NULL,
  amount        DECIMAL(10,2)  NOT NULL,
  PRIMARY KEY (sale_item_id),
  CONSTRAINT fk_saleitem_sale FOREIGN KEY (sale_id) REFERENCES sale (sale_id),
  CONSTRAINT fk_saleitem_drug FOREIGN KEY (drug_id) REFERENCES drug (drug_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- AUDIT & MESSAGING
-- ---------------------------------------------------------------------

CREATE TABLE login_audit (
  audit_id      INT          NOT NULL AUTO_INCREMENT,
  user_id       INT          NOT NULL,
  login_time    DATETIME     NOT NULL,
  session_type  VARCHAR(20)  NOT NULL,
  PRIMARY KEY (audit_id),
  CONSTRAINT fk_audit_user FOREIGN KEY (user_id) REFERENCES app_user (user_id)
) ENGINE=InnoDB;

-- merges legacy `inbox` + `message_history` into one table
CREATE TABLE message (
  message_id    INT          NOT NULL AUTO_INCREMENT,
  from_user     INT          NOT NULL,
  to_user       INT          NOT NULL,
  message_text  VARCHAR(200) NOT NULL,
  sent_at       DATETIME     NOT NULL,
  is_read       BOOLEAN      NOT NULL DEFAULT FALSE,
  PRIMARY KEY (message_id),
  CONSTRAINT fk_msg_from FOREIGN KEY (from_user) REFERENCES app_user (user_id),
  CONSTRAINT fk_msg_to   FOREIGN KEY (to_user)   REFERENCES app_user (user_id)
) ENGINE=InnoDB;

-- ---------------------------------------------------------------------
-- REMOVED vs LEGACY
--   * `expiry`          -> DROPPED  (orphan table, unused by any query)
--   * `login`           -> REPLACED by login_audit (typed, date-aware)
--   * `inbox`/`message_history` -> MERGED into `message`
--   * `sales`/`history_sales`   -> NORMALISED into sale + sale_item
--   * `purchase`                -> NORMALISED into purchase_order + purchase_item
--   * `users`                   -> RENAMED to app_user, password hashed
-- =====================================================================
