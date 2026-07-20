# Database Schema

| Area | Authoritative tables |
|---|---|
| Identity | `districts`, `profiles`, `dealers` |
| Customer | `customers`, `customer_documents`, `site_surveys` |
| Pricing | `price_lists`, `price_list_items`, `inverter_products`, `subsidy_rules`, `tax_rules` |
| Quotation | `quotations`, `quotation_versions`, `quotation_items`, `quotation_status_history`, `quotation_overrides` |
| Agreement/feasibility | `agreements`, `agreement_signatures`, `feasibility_reports` |
| Project | `projects`, `project_stage_history`, `project_documents`, `project_material_requirements` |
| Installation/invoice | `installation_materials`, `customer_invoices`, `customer_invoice_items` |
| Inventory | `inventory_items`, `inventory_serials`, `stock_transactions`, `purchase_invoices`, `purchase_invoice_items` |
| Commission/finance | `dealer_commissions`, `dealer_commission_payments`, `payments`, `expenses` |
| Governance | `company_settings`, `document_counters`, `audit_logs`, `ai_extraction_logs` |

UUID primary keys, foreign keys, soft archival, row versions, partial unique indexes and idempotency keys protect integrity. Quotation versions, agreement/feasibility snapshots, accepted quotation snapshots, invoices, audit events, stock postings and commission payments are append-only or function-controlled.

Document numbers are allocated under row locks. `save_agreement_document` records the private editable DOCX. `save_feasibility_and_create_project` requires that agreement, stores editable report fields plus an immutable audit snapshot, and creates exactly one project, material requirements/reservations and commission entry in one transaction. `update_feasibility_report` corrects an existing report without creating a second project. Direct authenticated execution of the legacy quotation-to-project function is revoked. `save_installation_and_issue_invoice` remains available at every post-installation stage, locks the project, validates serials and reverse-calculates tax without changing the accepted gross amount.
