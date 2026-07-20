import { useState } from "react";
import {
  Building2,
  CreditCard,
  FileKey2,
  KeyRound,
  Plus,
  RefreshCw,
  Save,
  UserPlus,
  UserRoundCog,
} from "lucide-react";
import { Empty, Field, PageHeader, Status } from "../components/Ui";
import { Modal } from "../components/Modal";
import { useCrm } from "../lib/CrmContext";
import { supabase } from "../lib/supabase";
import {
  createUserManually,
  inviteUser,
  manageUser,
  updateUserProfile,
} from "../services/repository";
import {
  calculateSplitInclusiveGst,
  formatDate,
  formatInr,
} from "../services/calculations";
import { documentNumberPreview } from "../services/settings";
import type { CrmSettings, Profile, Role } from "../types/domain";

type UserFormValue = {
  mode: "invite" | "manual";
  email: string;
  password: string;
  fullName: string;
  role: Role;
  districtId: string;
  dealerId: string;
};

const emptyUser = (mode: UserFormValue["mode"]): UserFormValue => ({
  mode,
  email: "",
  password: "",
  fullName: "",
  role: "district_partner",
  districtId: "",
  dealerId: "",
});

export function Administration() {
  const { data, refresh } = useCrm();
  const [userForm, setUserForm] = useState<UserFormValue | null>(null);
  const [editingUser, setEditingUser] = useState<Profile | null>(null);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  if (!data || data.profile.role !== "admin")
    return (
      <Empty
        title="Access denied"
        detail="Administration is restricted to Admin users."
      />
    );

  const addDistrict = async () => {
    const name = window.prompt("Area / territory name");
    if (!name) return;
    const code = window.prompt("Area code", name.slice(0, 4).toUpperCase());
    if (!code) return;
    const { error } = await supabase!
      .from("districts")
      .insert({ name: name.trim(), code: code.trim().toUpperCase() });
    if (error) setMessage(error.message);
    else await refresh();
  };

  return (
    <>
      <PageHeader
        title="Administration & Settings"
        subtitle="Create users manually or by invitation, assign multiple partners per district, and control every main document setting."
        actions={
          <>
            <button className="btn" onClick={() => void refresh()}>
              <RefreshCw size={15} /> Refresh
            </button>
            <button
              className="btn"
              onClick={() => setUserForm(emptyUser("manual"))}
            >
              <UserRoundCog size={16} /> Create Login Manually
            </button>
            <button
              className="btn btn--primary"
              onClick={() => setUserForm(emptyUser("invite"))}
            >
              <UserPlus size={16} /> Send Invitation
            </button>
          </>
        }
      />
      {message && <div className="alert alert--info">{message}</div>}
      <section className="card redirect-health">
        <div>
          <FileKey2 size={20} />
          <span>
            <strong>Production login and invitation URL</strong>
            <small>{window.location.origin}</small>
          </span>
        </div>
        <p>
          Invites now use this live origin. Supabase Authentication → URL
          Configuration must also use this URL as Site URL and Redirect URL.
        </p>
      </section>

      <section className="card table-card">
        <div className="card__title">
          <div>
            <h2>Users</h2>
            <p>
              An area may have multiple Area Partners. Each partner sees only
              customers created by or explicitly assigned to that partner.
            </p>
          </div>
          <Status tone="info">{data.users.length} accounts</Status>
        </div>
        <table>
          <thead>
            <tr>
              <th>User</th>
              <th>Role</th>
              <th>Area / Dealer</th>
              <th>Last Login</th>
              <th>Status</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {data.users.map((user) => (
              <tr key={user.id}>
                <td>
                  <strong>{user.fullName}</strong>
                  <small>{user.id.slice(0, 8)}</small>
                </td>
                <td>
                  {user.role === "district_partner"
                    ? "Area Partner"
                    : user.role === "admin"
                      ? "Admin"
                      : "Dealer"}
                </td>
                <td>
                  {user.districtName ?? "-"}
                  <small>
                    {
                      data.dealers.find((dealer) => dealer.id === user.dealerId)
                        ?.name
                    }
                  </small>
                </td>
                <td>{formatDate(user.lastLoginAt)}</td>
                <td>
                  <Status tone={user.active ? "good" : "bad"}>
                    {user.active ? "Active" : "Suspended"}
                  </Status>
                </td>
                <td>
                  <div className="row-actions">
                    <button
                      className="btn btn--small"
                      onClick={() => setEditingUser(user)}
                    >
                      Edit Access
                    </button>
                    <button
                      className="btn btn--small"
                      disabled={busy}
                      onClick={async () => {
                        setBusy(true);
                        setMessage("");
                        try {
                          await manageUser("reset_password", user.id);
                          setMessage(
                            "Password reset email sent to the production URL.",
                          );
                        } catch (error) {
                          setMessage(
                            error instanceof Error
                              ? error.message
                              : "Reset failed.",
                          );
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      Reset Password
                    </button>
                    <button
                      className={`btn btn--small ${user.active ? "btn--danger" : ""}`}
                      disabled={busy || user.id === data.profile.id}
                      onClick={async () => {
                        const reason = user.active
                          ? (window.prompt("Suspension reason (required)") ??
                            "")
                          : "";
                        if (user.active && !reason.trim()) return;
                        setBusy(true);
                        try {
                          await manageUser(
                            "set_active",
                            user.id,
                            !user.active,
                            reason,
                          );
                          await refresh();
                        } catch (error) {
                          setMessage(
                            error instanceof Error
                              ? error.message
                              : "User update failed.",
                          );
                        } finally {
                          setBusy(false);
                        }
                      }}
                    >
                      {user.active ? "Suspend" : "Reactivate"}
                    </button>
                    {!user.active && user.id !== data.profile.id && (
                      <button
                        className="btn btn--small btn--danger"
                        disabled={busy}
                        onClick={async () => {
                          const reason =
                            window.prompt(
                              `Permanent deletion reason for ${user.fullName} (required)`,
                            ) ?? "";
                          if (
                            !reason.trim() ||
                            !window.confirm(
                              "Permanently delete this suspended login? This cannot be undone.",
                            )
                          )
                            return;
                          setBusy(true);
                          setMessage("");
                          try {
                            await manageUser(
                              "delete_user",
                              user.id,
                              undefined,
                              reason,
                            );
                            setMessage("Suspended login permanently deleted.");
                            await refresh();
                          } catch (error) {
                            setMessage(
                              error instanceof Error
                                ? error.message
                                : "User deletion failed.",
                            );
                          } finally {
                            setBusy(false);
                          }
                        }}
                      >
                        Delete
                      </button>
                    )}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </section>

      <div className="two-col">
        <section className="card table-card">
          <div className="card__title">
            <div>
              <h2>Areas and Partner Capacity</h2>
              <p>
                Areas are admin-defined territories—not government districts.
                Multiple partners are allowed in every area.
              </p>
            </div>
            <button
              className="btn btn--small"
              onClick={() => void addDistrict()}
            >
              <Plus size={14} /> Area
            </button>
          </div>
          <table>
            <thead>
              <tr>
                <th>Code</th>
                <th>Area Name</th>
                <th>Partners</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {data.districts.map((district) => (
                <tr key={district.id}>
                  <td>{district.code}</td>
                  <td>
                    <strong>{district.name}</strong>
                  </td>
                  <td>
                    {
                      data.users.filter(
                        (user) =>
                          user.role === "district_partner" &&
                          user.districtId === district.id,
                      ).length
                    }
                  </td>
                  <td>
                    <Status tone={district.active ? "good" : "bad"}>
                      {district.active ? "Active" : "Inactive"}
                    </Status>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
        <SecuritySummary settings={data.settings} />
      </div>

      <MasterSettings />
      <CommercialSettings />
      <section className="card table-card">
        <div className="card__title">
          <h2>Security and Activity Audit</h2>
          <Status tone="info">Append-only</Status>
        </div>
        <table>
          <thead>
            <tr>
              <th>Date</th>
              <th>Actor</th>
              <th>Action</th>
              <th>Entity</th>
              <th>Reason</th>
            </tr>
          </thead>
          <tbody>
            {data.auditLogs.slice(0, 200).map((log) => (
              <tr key={log.id}>
                <td>{formatDate(log.createdAt)}</td>
                <td>{log.actorName || "-"}</td>
                <td>
                  <strong>{log.action}</strong>
                </td>
                <td>
                  {log.entityType}
                  {log.entityId ? ` · ${log.entityId.slice(0, 8)}` : ""}
                </td>
                <td>{log.reason || "-"}</td>
              </tr>
            ))}
          </tbody>
        </table>
        {!data.auditLogs.length && (
          <Empty
            title="No audit events visible"
            detail="Events appear after users perform secured actions."
          />
        )}
      </section>

      {userForm && (
        <UserCreationForm
          value={userForm}
          onChange={setUserForm}
          onClose={() => setUserForm(null)}
          onSuccess={async (text) => {
            setUserForm(null);
            setMessage(text);
            await refresh();
          }}
        />
      )}
      {editingUser && (
        <UserAccessForm
          user={editingUser}
          onClose={() => setEditingUser(null)}
        />
      )}
    </>
  );
}

function UserCreationForm({
  value,
  onChange,
  onClose,
  onSuccess,
}: {
  value: UserFormValue;
  onChange: (value: UserFormValue) => void;
  onClose: () => void;
  onSuccess: (message: string) => Promise<void>;
}) {
  const { data } = useCrm();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const manual = value.mode === "manual";
  return (
    <Modal
      title={manual ? "Create Login Manually" : "Send Secure Invitation"}
      onClose={onClose}
    >
      <form
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          setError("");
          try {
            const common = {
              email: value.email,
              fullName: value.fullName,
              role: value.role,
              districtId: value.districtId || undefined,
              dealerId: value.dealerId || undefined,
            };
            if (manual)
              await createUserManually({ ...common, password: value.password });
            else await inviteUser(common);
            await onSuccess(
              manual
                ? "Login created. Share the email and temporary password privately; ask the user to reset it after first login."
                : "Invitation sent with the production CRM redirect URL.",
            );
          } catch (cause) {
            setError(
              cause instanceof Error ? cause.message : "User creation failed.",
            );
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="alert alert--info">
          {manual
            ? "This creates an active verified login immediately—no email link is required."
            : "The email link will open the deployed CRM, never localhost."}
        </div>
        <div className="form-grid">
          <Field label="Full Name">
            <input
              required
              value={value.fullName}
              onChange={(event) =>
                onChange({ ...value, fullName: event.target.value })
              }
            />
          </Field>
          <Field label="Email">
            <input
              required
              type="email"
              value={value.email}
              onChange={(event) =>
                onChange({ ...value, email: event.target.value })
              }
            />
          </Field>
          {manual && (
            <Field label="Temporary Password">
              <input
                required
                type="password"
                minLength={12}
                autoComplete="new-password"
                value={value.password}
                onChange={(event) =>
                  onChange({ ...value, password: event.target.value })
                }
              />
              <small>
                Minimum 12 characters with upper/lowercase, number and symbol.
              </small>
            </Field>
          )}
          <Field label="Role">
            <select
              value={value.role}
              onChange={(event) =>
                onChange({
                  ...value,
                  role: event.target.value as Role,
                  districtId:
                    event.target.value === "admin" ? "" : value.districtId,
                  dealerId:
                    event.target.value === "dealer" ? value.dealerId : "",
                })
              }
            >
              <option value="admin">Admin</option>
              <option value="district_partner">Area Partner</option>
              <option value="dealer">Dealer</option>
            </select>
          </Field>
          {value.role !== "admin" && (
            <Field label="Area / Territory">
              <select
                required
                value={value.districtId}
                onChange={(event) =>
                  onChange({
                    ...value,
                    districtId: event.target.value,
                    dealerId: "",
                  })
                }
              >
                <option value="">Select area</option>
                {data?.districts.map((district) => (
                  <option value={district.id} key={district.id}>
                    {district.name}
                  </option>
                ))}
              </select>
            </Field>
          )}
          {value.role === "dealer" && (
            <Field label="Dealer Master">
              <select
                required
                value={value.dealerId}
                onChange={(event) =>
                  onChange({ ...value, dealerId: event.target.value })
                }
              >
                <option value="">Select dealer</option>
                {data?.dealers
                  .filter(
                    (dealer) =>
                      !value.districtId ||
                      dealer.districtId === value.districtId,
                  )
                  .map((dealer) => (
                    <option value={dealer.id} key={dealer.id}>
                      {dealer.name}
                    </option>
                  ))}
              </select>
            </Field>
          )}
        </div>
        {error && <div className="alert alert--error">{error}</div>}
        <div className="form-actions">
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn--primary" disabled={busy}>
            {busy
              ? "Saving..."
              : manual
                ? "Create Active Login"
                : "Send Invitation"}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function UserAccessForm({
  user,
  onClose,
}: {
  user: Profile;
  onClose: () => void;
}) {
  const { data, refresh } = useCrm();
  const [value, setValue] = useState({
    fullName: user.fullName,
    role: user.role,
    districtId: user.districtId ?? "",
    dealerId: user.dealerId ?? "",
  });
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  return (
    <Modal title="Edit User Access" onClose={onClose}>
      <form
        onSubmit={async (event) => {
          event.preventDefault();
          setBusy(true);
          setError("");
          try {
            await updateUserProfile({
              userId: user.id,
              fullName: value.fullName,
              role: value.role,
              districtId: value.districtId || null,
              dealerId: value.dealerId || null,
            });
            await refresh();
            onClose();
          } catch (cause) {
            setError(cause instanceof Error ? cause.message : "Update failed.");
          } finally {
            setBusy(false);
          }
        }}
      >
        <div className="form-grid">
          <Field label="Full Name">
            <input
              required
              value={value.fullName}
              onChange={(event) =>
                setValue({ ...value, fullName: event.target.value })
              }
            />
          </Field>
          <Field label="Role">
            <select
              value={value.role}
              onChange={(event) =>
                setValue({
                  ...value,
                  role: event.target.value as Role,
                  districtId:
                    event.target.value === "admin" ? "" : value.districtId,
                  dealerId:
                    event.target.value === "dealer" ? value.dealerId : "",
                })
              }
            >
              <option value="admin">Admin</option>
              <option value="district_partner">Area Partner</option>
              <option value="dealer">Dealer</option>
            </select>
          </Field>
          {value.role !== "admin" && (
            <Field label="Area / Territory">
              <select
                required
                value={value.districtId}
                onChange={(event) =>
                  setValue({ ...value, districtId: event.target.value })
                }
              >
                <option value="">Select area</option>
                {data?.districts.map((district) => (
                  <option key={district.id} value={district.id}>
                    {district.name}
                  </option>
                ))}
              </select>
            </Field>
          )}
          {value.role === "dealer" && (
            <Field label="Dealer">
              <select
                required
                value={value.dealerId}
                onChange={(event) =>
                  setValue({ ...value, dealerId: event.target.value })
                }
              >
                <option value="">Select dealer</option>
                {data?.dealers
                  .filter(
                    (dealer) =>
                      !value.districtId ||
                      dealer.districtId === value.districtId,
                  )
                  .map((dealer) => (
                    <option key={dealer.id} value={dealer.id}>
                      {dealer.name}
                    </option>
                  ))}
              </select>
            </Field>
          )}
        </div>
        {error && <div className="alert alert--error">{error}</div>}
        <div className="form-actions">
          <button type="button" className="btn" onClick={onClose}>
            Cancel
          </button>
          <button className="btn btn--primary" disabled={busy}>
            {busy ? "Saving..." : "Save Access"}
          </button>
        </div>
      </form>
    </Modal>
  );
}

function SecuritySummary({ settings }: { settings: CrmSettings }) {
  return (
    <section className="card">
      <div className="card__title">
        <h2>
          <KeyRound size={18} /> Security Policy
        </h2>
      </div>
      <p>
        Email/password authentication, verified identities, role permissions and
        database row-level policies are active.
      </p>
      <div className="settings-summary">
        <span>
          Idle logout <b>{settings.inactivityMinutes} minutes</b>
        </span>
        <span>
          Manual password <b>12+ strong characters</b>
        </span>
        <span>
          Paid authenticator <b>Not required</b>
        </span>
      </div>
    </section>
  );
}

function MasterSettings() {
  const { data, saveSettings, saving } = useCrm();
  const [value, setValue] = useState<CrmSettings>(data!.settings);
  const [message, setMessage] = useState("");
  const company = value.company;
  const bank = value.bank;
  return (
    <section className="card settings-master">
      <div className="card__title">
        <div>
          <h2>Main Editable Settings</h2>
          <p>
            These values flow into quotation, invoice, dashboard header and
            future automatic document numbers.
          </p>
        </div>
        <button
          className="btn btn--primary"
          disabled={saving}
          onClick={async () => {
            await saveSettings(value);
            setMessage("All main settings and document counters saved.");
          }}
        >
          <Save size={15} /> Save All Settings
        </button>
      </div>
      {message && <div className="alert alert--info">{message}</div>}
      <div className="settings-grid">
        <div className="settings-panel">
          <h3>
            <Building2 size={17} /> Company Details
          </h3>
          <div className="form-grid">
            <Field label="Legal Name">
              <input
                value={company.legalName}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, legalName: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Display Name">
              <input
                value={company.tradeName}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, tradeName: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Full Address" wide>
              <textarea
                value={company.address}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, address: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Primary Mobile">
              <input
                value={company.mobilePrimary}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, mobilePrimary: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Secondary Mobile">
              <input
                value={company.mobileSecondary}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: {
                      ...company,
                      mobileSecondary: event.target.value,
                    },
                  })
                }
              />
            </Field>
            <Field label="Email">
              <input
                type="email"
                value={company.email}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, email: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="GSTIN">
              <input
                value={company.gstin}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: {
                      ...company,
                      gstin: event.target.value.toUpperCase(),
                    },
                  })
                }
              />
            </Field>
            <Field label="PAN">
              <input
                value={company.pan}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: {
                      ...company,
                      pan: event.target.value.toUpperCase(),
                    },
                  })
                }
              />
            </Field>
            <Field label="State">
              <input
                value={company.state}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, state: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="State Code">
              <input
                value={company.stateCode}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, stateCode: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Jurisdiction">
              <input
                value={company.jurisdiction}
                onChange={(event) =>
                  setValue({
                    ...value,
                    company: { ...company, jurisdiction: event.target.value },
                  })
                }
              />
            </Field>
          </div>
        </div>
        <div className="settings-panel">
          <h3>
            <CreditCard size={17} /> Bank Details
          </h3>
          <div className="form-grid">
            <Field label="Account Holder">
              <input
                value={bank.accountHolder}
                onChange={(event) =>
                  setValue({
                    ...value,
                    bank: { ...bank, accountHolder: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Bank Name">
              <input
                value={bank.bankName}
                onChange={(event) =>
                  setValue({
                    ...value,
                    bank: { ...bank, bankName: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="Account Number">
              <input
                value={bank.accountNumber}
                onChange={(event) =>
                  setValue({
                    ...value,
                    bank: { ...bank, accountNumber: event.target.value },
                  })
                }
              />
            </Field>
            <Field label="IFSC">
              <input
                value={bank.ifsc}
                onChange={(event) =>
                  setValue({
                    ...value,
                    bank: { ...bank, ifsc: event.target.value.toUpperCase() },
                  })
                }
              />
            </Field>
            <Field label="Branch">
              <input
                value={bank.branch}
                onChange={(event) =>
                  setValue({
                    ...value,
                    bank: { ...bank, branch: event.target.value },
                  })
                }
              />
            </Field>
          </div>
        </div>
        <NumberingPanel
          title="Quotation Numbering"
          settings={value.quotationNumbering}
          onChange={(quotationNumbering) =>
            setValue({ ...value, quotationNumbering })
          }
        />
        <NumberingPanel
          title="Invoice Numbering"
          settings={value.invoiceNumbering}
          onChange={(invoiceNumbering) =>
            setValue({ ...value, invoiceNumbering })
          }
        />
        <div className="settings-panel settings-panel--wide">
          <h3>Quotation & Invoice Defaults</h3>
          <div className="form-grid">
            <Field label="Quotation Validity Days">
              <input
                type="number"
                min="1"
                value={value.quotationValidityDays}
                onChange={(event) =>
                  setValue({
                    ...value,
                    quotationValidityDays: Number(event.target.value),
                  })
                }
              />
            </Field>
            <Field label="Default HSN/SAC">
              <input
                value={value.defaultHsnSac}
                onChange={(event) =>
                  setValue({ ...value, defaultHsnSac: event.target.value })
                }
              />
            </Field>
            <Field label="Payment Terms" wide>
              <textarea
                value={value.paymentTerms}
                onChange={(event) =>
                  setValue({ ...value, paymentTerms: event.target.value })
                }
              />
            </Field>
            <Field label="Warranty Terms" wide>
              <textarea
                value={value.warrantyTerms}
                onChange={(event) =>
                  setValue({ ...value, warrantyTerms: event.target.value })
                }
              />
            </Field>
            <Field label="Default Quotation Notes" wide>
              <textarea
                value={value.quotationNotes}
                onChange={(event) =>
                  setValue({ ...value, quotationNotes: event.target.value })
                }
              />
            </Field>
            <Field label="Document Footer" wide>
              <input
                value={value.footerText}
                onChange={(event) =>
                  setValue({ ...value, footerText: event.target.value })
                }
              />
            </Field>
            <Field label="Idle Logout Minutes">
              <input
                type="number"
                min="5"
                max="480"
                value={value.inactivityMinutes}
                onChange={(event) =>
                  setValue({
                    ...value,
                    inactivityMinutes: Number(event.target.value),
                  })
                }
              />
            </Field>
          </div>
        </div>
      </div>
    </section>
  );
}

function NumberingPanel({
  title,
  settings,
  onChange,
}: {
  title: string;
  settings: CrmSettings["quotationNumbering"];
  onChange: (settings: CrmSettings["quotationNumbering"]) => void;
}) {
  return (
    <div className="settings-panel">
      <h3>
        <FileKey2 size={17} /> {title}
      </h3>
      <div className="document-preview">
        Next: <strong>{documentNumberPreview(settings)}</strong>
      </div>
      <div className="form-grid">
        <Field label="Prefix">
          <input
            value={settings.prefix}
            onChange={(event) =>
              onChange({ ...settings, prefix: event.target.value })
            }
          />
        </Field>
        <Field label="Next Number">
          <input
            type="number"
            min="1"
            value={settings.nextNumber}
            onChange={(event) =>
              onChange({ ...settings, nextNumber: Number(event.target.value) })
            }
          />
        </Field>
        <Field label="Zero Padding">
          <input
            type="number"
            min="1"
            max="10"
            value={settings.padding}
            onChange={(event) =>
              onChange({ ...settings, padding: Number(event.target.value) })
            }
          />
        </Field>
      </div>
    </div>
  );
}

function CommercialSettings() {
  const { data, refresh } = useCrm();
  const [tax, setTax] = useState({
    name: "Solar EPC 70/30 - Supply 5% / Installation 18%",
    supplyRate: "5",
    installationRate: "18",
    supplyShare: "70",
    installationShare: "30",
    supplyHsn: "854140",
    installationSac: "995442",
    effectiveFrom: new Date().toISOString().slice(0, 10),
    intrastate: true,
  });
  const [subsidy, setSubsidy] = useState({
    name: "PM Surya Ghar Rule",
    category: "Residential",
    upTo2Rate: "",
    above2Rate: "",
    capKw: "3",
    effectiveFrom: new Date().toISOString().slice(0, 10),
  });
  const [message, setMessage] = useState("");
  const shareTotal = Number(tax.supplyShare) + Number(tax.installationShare);
  const preview =
    shareTotal === 100
      ? calculateSplitInclusiveGst(100000, {
          intrastate: tax.intrastate,
          supplyGstRate: Number(tax.supplyRate),
          installationGstRate: Number(tax.installationRate),
          supplySharePercent: Number(tax.supplyShare),
          installationSharePercent: Number(tax.installationShare),
          supplyHsn: tax.supplyHsn,
          installationSac: tax.installationSac,
        })
      : null;
  const loadRuleVersion = (
    rule: NonNullable<typeof data>["taxRules"][number],
  ) =>
    setTax({
      name: `${rule.name} - New Version`,
      supplyRate: String(rule.supplyGstRate),
      installationRate: String(rule.installationGstRate),
      supplyShare: String(rule.supplySharePercent),
      installationShare: String(rule.installationSharePercent),
      supplyHsn: rule.supplyHsn,
      installationSac: rule.installationSac,
      effectiveFrom: new Date().toISOString().slice(0, 10),
      intrastate: rule.intrastate,
    });
  return (
    <section className="card">
      <div className="card__title">
        <div>
          <h2>Effective-Dated Invoice Tax Rules</h2>
          <p>
            GST values are editable. A new published rule is used by invoices
            dated on or after its effective date; issued invoices keep their
            saved calculation.
          </p>
        </div>
      </div>
      {message && <div className="alert alert--info">{message}</div>}
      <div className="two-col">
        <form
          onSubmit={async (event) => {
            event.preventDefault();
            if (shareTotal !== 100) {
              setMessage(
                "Supply and installation shares must total exactly 100%.",
              );
              return;
            }
            const { error } = await supabase!
              .from("tax_rules")
              .insert({
                name: tax.name,
                gst_rate: Number(tax.supplyRate),
                supply_gst_rate: Number(tax.supplyRate),
                installation_gst_rate: Number(tax.installationRate),
                supply_share_percent: Number(tax.supplyShare),
                installation_share_percent: Number(tax.installationShare),
                supply_hsn: tax.supplyHsn.trim(),
                installation_sac: tax.installationSac.trim(),
                effective_from: tax.effectiveFrom,
                intrastate: tax.intrastate,
                active: true,
                created_by: data?.profile.id,
              });
            setMessage(
              error?.message ??
                "Split GST rule published. Future invoices will calculate automatically.",
            );
            if (!error) await refresh();
          }}
        >
          <h3>Split GST Invoice Rule</h3>
          <div className="alert alert--info">
            Default requested configuration: 70% supply and 30% installation. Rates remain effective-dated and editable; confirm the legally applicable rate before publishing.
          </div>
          <div className="form-grid">
            <Field label="Rule Name" wide>
              <input
                required
                value={tax.name}
                onChange={(event) =>
                  setTax({ ...tax, name: event.target.value })
                }
              />
            </Field>
            <Field label="Supply Share %">
              <input
                required
                type="number"
                min="0"
                max="100"
                step="0.001"
                value={tax.supplyShare}
                onChange={(event) =>
                  setTax({
                    ...tax,
                    supplyShare: event.target.value,
                    installationShare: String(
                      Math.max(0, 100 - Number(event.target.value)),
                    ),
                  })
                }
              />
            </Field>
            <Field label="Supply GST %">
              <input
                required
                type="number"
                min="0"
                step="0.001"
                value={tax.supplyRate}
                onChange={(event) =>
                  setTax({ ...tax, supplyRate: event.target.value })
                }
              />
            </Field>
            <Field label="Supply HSN">
              <input
                required
                value={tax.supplyHsn}
                onChange={(event) =>
                  setTax({ ...tax, supplyHsn: event.target.value })
                }
              />
            </Field>
            <Field label="Installation Share %">
              <input
                required
                type="number"
                min="0"
                max="100"
                step="0.001"
                value={tax.installationShare}
                onChange={(event) =>
                  setTax({
                    ...tax,
                    installationShare: event.target.value,
                    supplyShare: String(
                      Math.max(0, 100 - Number(event.target.value)),
                    ),
                  })
                }
              />
            </Field>
            <Field label="Installation GST %">
              <input
                required
                type="number"
                min="0"
                step="0.001"
                value={tax.installationRate}
                onChange={(event) =>
                  setTax({ ...tax, installationRate: event.target.value })
                }
              />
            </Field>
            <Field label="Installation SAC">
              <input
                required
                value={tax.installationSac}
                onChange={(event) =>
                  setTax({ ...tax, installationSac: event.target.value })
                }
              />
            </Field>
            <Field label="Effective From">
              <input
                required
                type="date"
                value={tax.effectiveFrom}
                onChange={(event) =>
                  setTax({ ...tax, effectiveFrom: event.target.value })
                }
              />
            </Field>
            <Field label="Tax Type">
              <select
                value={tax.intrastate ? "intra" : "inter"}
                onChange={(event) =>
                  setTax({ ...tax, intrastate: event.target.value === "intra" })
                }
              >
                <option value="intra">CGST + SGST</option>
                <option value="inter">IGST</option>
              </select>
            </Field>
          </div>
          <div
            className={`split-tax-preview ${shareTotal === 100 ? "" : "is-invalid"}`}
          >
            <strong>
              Calculation preview on GST-inclusive {formatInr(100000)}
            </strong>
            {preview ? (
              preview.lines.map((line) => (
                <span key={line.lineType}>
                  {line.lineType === "supply" ? "Supply" : "Installation"}{" "}
                  {line.sharePercent}% · taxable {formatInr(line.taxableValue)}{" "}
                  · GST {line.gstRate}% ={" "}
                  {formatInr(line.cgst + line.sgst + line.igst)}
                </span>
              ))
            ) : (
              <span>
                Shares currently total {shareTotal}%. They must total 100%.
              </span>
            )}
            <b>Invoice grand total remains {formatInr(100000)}</b>
          </div>
          <button className="btn btn--primary" disabled={shareTotal !== 100}>
            <Save size={15} /> Publish Split GST Rule
          </button>
        </form>
        <form
          style={{ display: "none" }}
          aria-hidden="true"
          onSubmit={async (event) => {
            event.preventDefault();
            const { error } = await supabase!
              .from("subsidy_rules")
              .insert({
                name: subsidy.name,
                customer_category: subsidy.category,
                effective_from: subsidy.effectiveFrom,
                min_kw: 0,
                max_kw: Number(subsidy.capKw),
                calculation: {
                  upTo2Rate: Number(subsidy.upTo2Rate),
                  above2Rate: Number(subsidy.above2Rate),
                  capKw: Number(subsidy.capKw),
                },
                active: true,
                created_by: data?.profile.id,
              });
            setMessage(error?.message ?? "Subsidy rule published.");
            if (!error) await refresh();
          }}
        >
          <h3>Subsidy Rule</h3>
          <div className="form-grid">
            <Field label="Rule Name">
              <input
                required
                value={subsidy.name}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, name: event.target.value })
                }
              />
            </Field>
            <Field label="Customer Category">
              <select
                value={subsidy.category}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, category: event.target.value })
                }
              >
                {[
                  "Residential",
                  "RWA/GHS",
                  "Commercial",
                  "Agricultural",
                  "Industrial",
                  "Institutional",
                ].map((item) => (
                  <option key={item}>{item}</option>
                ))}
              </select>
            </Field>
            <Field label="Rate up to 2 kW">
              <input
                required
                type="number"
                min="0"
                value={subsidy.upTo2Rate}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, upTo2Rate: event.target.value })
                }
              />
            </Field>
            <Field label="Rate above 2 kW">
              <input
                required
                type="number"
                min="0"
                value={subsidy.above2Rate}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, above2Rate: event.target.value })
                }
              />
            </Field>
            <Field label="Capacity Cap (kW)">
              <input
                required
                type="number"
                min="0"
                value={subsidy.capKw}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, capKw: event.target.value })
                }
              />
            </Field>
            <Field label="Effective From">
              <input
                required
                type="date"
                value={subsidy.effectiveFrom}
                onChange={(event) =>
                  setSubsidy({ ...subsidy, effectiveFrom: event.target.value })
                }
              />
            </Field>
          </div>
          <button className="btn btn--primary">
            <Save size={15} /> Publish Subsidy Rule
          </button>
        </form>
        <aside className="settings-note-card">
          <h3>Quotation Subsidy Information</h3>
          <p>The standard subsidy table is printed separately on every customer quotation and never adds to or subtracts from the quotation total.</p>
          <strong>No subsidy rule setup is required.</strong>
        </aside>
      </div>
      <div className="table-card split-tax-rule-list">
        <table>
          <thead>
            <tr>
              <th>GST Rule</th>
              <th>Supply</th>
              <th>Installation</th>
              <th>Tax Type</th>
              <th>Effective</th>
              <th></th>
            </tr>
          </thead>
          <tbody>
            {data?.taxRules.map((rule) => (
              <tr key={rule.id}>
                <td>
                  <strong>{rule.name}</strong>
                </td>
                <td>
                  {rule.supplySharePercent}% @ {rule.supplyGstRate}%
                  <small>HSN {rule.supplyHsn}</small>
                </td>
                <td>
                  {rule.installationSharePercent}% @ {rule.installationGstRate}%
                  <small>SAC {rule.installationSac}</small>
                </td>
                <td>{rule.intrastate ? "CGST + SGST" : "IGST"}</td>
                <td>{formatDate(rule.effectiveFrom)}</td>
                <td>
                  <button
                    type="button"
                    className="btn btn--small"
                          onClick={() => loadRuleVersion(rule)}
                  >
                    Use as New Version
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </section>
  );
}
