# Database Schema

| Area | Authoritative tables |
|---|---|
| Identity | `districts`, `profiles`, `dealers` |
| Customer | `customers`, `customer_documents`, `site_surveys` |
| Pricing | `price_lists`, `price_list_items`, `inverter_products`, `subsidy_rules`, `tax_rules` |
| Quotation | `quotations`, `quotation_versions`, `quotation_items`, `quotation_status_history`, `quotation_overrides` |
| Project | `projects`, `project_stage_history`, `project_documents`, `project_material_requirements` |
| Installation/invoice | `installation_materials`, `customer_invoices`, `customer_invoice_items` |
| Inventory | `inventory_items`, `inventory_serials`, `stock_transactions`, `purchase_invoices`, `purchase_invoice_items` |
| Commission/finance | `dealer_commissions`, `dealer_commission_payments`, `payments`, `expenses` |
| Governance | `company_settings`, `document_counters`, `audit_logs`, `ai_extraction_logs` |

UUID primary keys, foreign keys, soft archival, row versions, partial unique indexes and idempotency keys protect integrity. Quotation versions, accepted quotation snapshots, invoices, audit events, stock postings and commission payments are append-only or function-controlled. Legacy agreement tables are retained only so older records are not destroyed; the final application no longer reads or writes them.

Document numbers are allocated under row locks. `approve_quotation_and_create_project` approves the quotation and creates one project, material requirements/reservations and commission entry in one transaction. `save_installation_and_issue_invoice` remains available at every post-installation stage, locks the project, validates serials and reverse-calculates tax without changing the accepted gross amount.
