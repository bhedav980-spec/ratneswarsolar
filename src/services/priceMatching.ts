import type { PriceRow } from '../types/domain';

const normalise = (value: string) => value.trim().toUpperCase();

export function wattagesForPriceRows(rows: PriceRow[], brand: string, technology: PriceRow['panelTechnology']) {
  const values = new Set<number>();
  rows
    .filter((row) => normalise(row.panelBrand) === normalise(brand) && row.panelTechnology === technology)
    .forEach((row) => {
      const minimum = row.panelWattageMin ?? row.panelWattage;
      const maximum = row.panelWattageMax ?? row.panelWattage;
      for (let wattage = minimum; wattage <= maximum; wattage += 5) values.add(wattage);
      values.add(maximum);
    });
  return [...values].sort((left, right) => left - right);
}

export function resolveOfficialPriceRow(
  rows: PriceRow[],
  brand: string,
  technology: PriceRow['panelTechnology'],
  panelWattage: number,
  requestedCapacityKw: number,
  preferredPanelQuantity?: number,
) {
  const candidates = rows.filter((row) => {
    const minimum = row.panelWattageMin ?? row.panelWattage;
    const maximum = row.panelWattageMax ?? row.panelWattage;
    return normalise(row.panelBrand) === normalise(brand)
      && row.panelTechnology === technology
      && panelWattage >= minimum
      && panelWattage <= maximum;
  });
  if (!candidates.length) return undefined;
  const requested = Math.max(0, requestedCapacityKw);
  return [...candidates].sort((left, right) => {
    if (preferredPanelQuantity != null) {
      const leftQuantityDistance = Math.abs(left.panelQuantity - preferredPanelQuantity);
      const rightQuantityDistance = Math.abs(right.panelQuantity - preferredPanelQuantity);
      if (leftQuantityDistance !== rightQuantityDistance) return leftQuantityDistance - rightQuantityDistance;
    }
    const leftCapacity = panelWattage * left.panelQuantity / 1000;
    const rightCapacity = panelWattage * right.panelQuantity / 1000;
    const leftDistance = Math.abs(leftCapacity - requested);
    const rightDistance = Math.abs(rightCapacity - requested);
    if (Math.abs(leftDistance - rightDistance) > 0.0000001) return leftDistance - rightDistance;
    return right.panelQuantity - left.panelQuantity;
  })[0];
}

export function exactCapacityKw(panelWattage: number, panelQuantity: number) {
  return Number((panelWattage * panelQuantity / 1000).toFixed(3));
}
