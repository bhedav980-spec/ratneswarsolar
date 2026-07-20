# Final Official Price Source Validation

Final verification date: 20/07/2026 (Asia/Kolkata)

The active production price master is created by `202607200014_official_price_match_and_project_cleanup.sql` from these five supplied PDFs:

- WAAREE Bifacial 540 Wp: 12 panel-count configurations.
- WAAREE TOPCon 580 Wp: 11 panel-count configurations.
- WAAREE TOPCon 610/615 Wp: 11 panel-count configurations.
- ADANI Bifacial 550 Wp: 12 panel-count configurations.
- ADANI TOPCon 610/615/620/625 Wp: 11 panel-count configurations.

Total: 57 verified GST-inclusive configurations.

The gross quotation price is always the PDF `Rate` or `Actual Customer Payable Amount`. `After Subsidy` is never used as the quotation price, and GST is never added again by the quotation engine.

Combined wattage sources are exposed in 5 W steps only inside the printed source range: WAAREE 610/615 and ADANI 610/615/620/625. The same official quantity-row price applies to each wattage printed together in that source row. No price is interpolated between panel quantities.

The user selects brand, technology, wattage and required kW. The application chooses the official panel quantity whose exact calculated capacity is closest to the requested kW. For example, 3.27 kW with a 540 Wp panel maps to 6 panels and an exact 3.240 kW capacity. The exact result is shown before saving.

The source row ID and PDF filename are stored only inside the immutable audit snapshot. They are not a customer-facing quotation input or printed reference.

Older 97-row migrations are retained for database history but their price lists are marked inactive by the final migration.
