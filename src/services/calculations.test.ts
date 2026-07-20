import { describe, expect, it } from 'vitest';
import { amountInWords, calculateDcCapacity, calculateLoanCustomerPrice, calculateQuote, calculateSplitGst, calculateSplitInclusiveGst, calculateSubsidy, calculateSubsidyFromRules, pendingBalance, reverseCalculateGst, standardInformationalSubsidy } from './calculations';

describe('solar quotation calculations', () => {
  it('calculates DC capacity from panel wattage and quantity', () => {
    expect(calculateDcCapacity(545, 6)).toBe(3.27);
  });

  it('handles exclusive GST once', () => {
    const result = calculateQuote({ panelWattage: 545, panelQuantity: 6, basePrice: 100000, extraItems: [], discount: 0, taxMode: 'exclusive', taxRate: 12 });
    expect(result.taxableValue).toBe(100000);
    expect(result.taxAmount).toBe(12000);
    expect(result.grandTotal).toBe(112000);
  });

  it('backs tax out of GST-inclusive price without duplicating it', () => {
    const result = calculateQuote({ panelWattage: 545, panelQuantity: 6, basePrice: 112000, extraItems: [], discount: 0, taxMode: 'inclusive', taxRate: 12 });
    expect(result.taxableValue).toBe(100000);
    expect(result.taxAmount).toBe(12000);
    expect(result.grandTotal).toBe(112000);
  });

  it('does not apply residential subsidy to commercial projects', () => {
    expect(calculateSubsidy('Commercial', 5).total).toBe(0);
    expect(calculateSubsidy('Residential', 3).total).toBe(78000);
  });

  it('uses effective-dated subsidy rules without applying one to another category',()=>{const rules=[{id:'1',name:'Residential rule',customerCategory:'Residential' as const,effectiveFrom:'2026-01-01',minKw:0,maxKw:3,calculation:{upTo2Rate:30000,above2Rate:18000,capKw:3},active:true}];expect(calculateSubsidyFromRules('Residential',3,rules,new Date('2026-07-12')).total).toBe(78000);expect(calculateSubsidyFromRules('Commercial',3,rules,new Date('2026-07-12')).eligible).toBe(false);});

  it('grosses up a loan quote and adds the editable file charge',()=>{const result=calculateLoanCustomerPrice(150000,10,2000);expect(result.financedEpcPrice).toBe(166666.67);expect(result.grossUpAmount).toBe(16666.67);expect(result.total).toBe(168667);});

  it('keeps the standard subsidy informational and outside the quotation total',()=>{const subsidy=standardInformationalSubsidy();expect(subsidy.informationalOnly).toBe(true);expect(subsidy.total).toBe(78000);expect(subsidy.referenceLines).toHaveLength(4);});

  it('reverse-calculates invoice GST and preserves the accepted gross total',()=>{const tax=reverseCalculateGst(216667,12);expect(tax.taxableValue+tax.cgst+tax.sgst).toBe(216667);expect(tax.gross).toBe(216667);});

  it('splits inclusive gross value into separately taxed supply and installation lines',()=>{
    const result=calculateSplitInclusiveGst(200000,{intrastate:true,supplyGstRate:4,installationGstRate:18,supplySharePercent:70,installationSharePercent:30,supplyHsn:'854140',installationSac:'995442'});
    expect(result.lines).toHaveLength(2);
    expect(result.lines[0]?.grossAmount).toBe(140000);
    expect(result.lines[1]?.grossAmount).toBe(60000);
    expect(result.taxableValue+result.cgst+result.sgst+result.igst).toBeCloseTo(200000,2);
  });

  it('uses only the supply line when supply share is 100 percent',()=>{
    const result=calculateSplitInclusiveGst(104000,{intrastate:true,supplyGstRate:4,installationGstRate:18,supplySharePercent:100,installationSharePercent:0,supplyHsn:'854140',installationSac:'995442'});
    expect(result.lines).toHaveLength(1);
    expect(result.lines[0]?.taxableValue).toBe(100000);
    expect(result.cgst+result.sgst).toBe(4000);
    expect(result.gross).toBe(104000);
  });

  it('reverse-calculates 70/30 GST inside a GST-inclusive quotation amount',()=>{
    const result=calculateSplitGst(100000,{intrastate:true,supplyGstRate:5,installationGstRate:18,supplySharePercent:70,installationSharePercent:30,supplyHsn:'854140',installationSac:'995442'},'inclusive');
    expect(result.lines[0]).toMatchObject({grossAmount:70000,taxableValue:66666.67,cgst:1666.67,sgst:1666.66});
    expect(result.lines[1]).toMatchObject({grossAmount:30000,taxableValue:25423.73,cgst:2288.14,sgst:2288.13});
    expect(result.gross).toBe(100000);
    expect(result.taxableValue+result.cgst+result.sgst).toBeCloseTo(100000,2);
  });

  it('adds split GST above a GST-exclusive quotation amount',()=>{
    const result=calculateSplitGst(100000,{intrastate:true,supplyGstRate:5,installationGstRate:18,supplySharePercent:70,installationSharePercent:30,supplyHsn:'854140',installationSac:'995442'},'exclusive');
    expect(result.lines[0]).toMatchObject({taxableValue:70000,cgst:1750,sgst:1750,grossAmount:73500});
    expect(result.lines[1]).toMatchObject({taxableValue:30000,cgst:2700,sgst:2700,grossAmount:35400});
    expect(result.taxableValue).toBe(100000);
    expect(result.gross).toBe(108900);
  });

  it('formats Indian amount words and prevents a negative balance', () => {
    expect(amountInWords(12345678)).toBe('One Crore Twenty Three Lakh Forty Five Thousand Six Hundred Seventy Eight Rupees Only');
    expect(pendingBalance(100, 120)).toBe(0);
  });
});
