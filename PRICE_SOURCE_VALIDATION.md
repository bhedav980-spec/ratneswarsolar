# Price Source Validation

Authoritative source: `Price List_Residential_Solar_Rooftop(2).pdf`, dated 06.06.2026.

The production migration contains 97 exact source configurations:

- Bifacial 530–550 Wp: ADANI, WAAREE and APS; 4–18 panels (45 rows).
- TOPCon PAHAL 600 Wp: 4–16 panels (13 rows).
- TOPCon ADANI 605–620 Wp: 4–16 panels (13 rows).
- TOPCon WAAREE 570–580 Wp: 4–16 panels (13 rows).
- TOPCon APS 580 Wp: 4–16 panels (13 rows).

Every source-listed panel count, DC capacity and gross price is stored exactly as printed. The PDF lists ADANI TOPCon 12 panels as 7.440 kW at ₹300,820; this unusual value is deliberately preserved rather than guessed. The APS TOPCon heading says 580 Wp while its listed capacities progress as 2.4, 3.0, 3.6 kW and so on; both the 580 Wp label and the exact source capacities are preserved.

The quotation selector displays the source wattage range plus the exact panel-count/capacity configuration. Prices continue to be treated as GST-inclusive, so the quotation engine does not add GST again.

The source structure table and BOS quantities are also used for new quotation BOMs. Structure quantities exist for 4–17 panels; an 18-panel quotation keeps the structure as site-design-dependent because the source does not provide an 18-panel structure row.

Automated checks fail deployment unless the migration contains exactly 97 active configurations.
