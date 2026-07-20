# Role Permission Matrix

| Capability | Admin | Area Partner | Dealer |
|---|---:|---:|---:|
| Global areas/users/settings/audit | Full | No | No |
| Customer access | All | Created by or assigned to partner | Own dealer only |
| AI customer import | All | Creates customer assigned to self | No |
| Quotation create/edit/print | All | Assigned customers | Own customers |
| Price override | Reason required | Reason required | Reason required |
| Approve/reject quotation | Yes | Assigned customers | No |
| Internal copy/commission | Yes | Assigned customers | Hidden |
| Generate editable Agreement DOCX | All | Assigned customers | No |
| Generate Feasibility PDF / create project | All | Assigned customers | No |
| Tax invoice generation/print | All | Assigned projects | No |
| Inventory | Full | Scoped read/workflow | No |
| Edit/archive inventory item master | Yes | No | No |
| Edit project material requirements | Yes | Assigned projects | No |
| Create users manually / invite | Yes | No | No |
| Vendor invoice import | Yes | No | No |
| Commission payment | Yes | No | No |
| Global reports/export | Yes | No | No |

Database functions and RLS enforce this matrix; navigation is only a usability layer.
