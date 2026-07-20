import type { Role } from '../types/domain';
export type Capability='manage_users'|'manage_prices'|'global_reports'|'customer_import'|'manage_projects'|'manage_inventory'|'pay_commission'|'customer_copy'|'internal_copy';
const matrix:Record<Role,ReadonlySet<Capability>>={admin:new Set(['manage_users','manage_prices','global_reports','customer_import','manage_projects','manage_inventory','pay_commission','customer_copy','internal_copy']),district_partner:new Set(['customer_import','manage_projects','manage_inventory','customer_copy','internal_copy']),dealer:new Set(['customer_copy'])};
export const can=(role:Role,capability:Capability)=>matrix[role].has(capability);
