# GST Configuration Note

The CRM implements a configurable 70% goods / 30% services calculation and stores the exact effective-dated rule with every issued invoice.

The Central Board of Indirect Taxes and Customs clarified the 70:30 deemed valuation approach for specified renewable-energy projects in Circular No. 163/19/2021-GST:

https://cbic-gst.gov.in/pdf/Circular-No-163-18-2021-GST.pdf

GST rates for renewable-energy goods have changed historically. Therefore:

- v8 seeds the owner-requested 5% Supply / 18% Installation configuration;
- an Admin may publish a corrected rate as a new effective-dated version;
- the system does not silently change an issued invoice;
- Ratneswar Engineering must confirm the rate, HSN/SAC and transaction classification with its GST adviser before production issuance.

## Calculation modes

### GST included in quotation amount

The accepted quotation is the final gross amount. Each 70/30 gross portion is reverse-calculated at its own rate.

### GST added above quotation amount

The accepted quotation is the taxable base. It is split 70/30, each portion is taxed at its own rate, and tax is added to produce the final invoice total.

For an intrastate transaction, each line’s tax is divided equally into CGST and SGST. For an interstate transaction, the same line tax is shown as IGST.
