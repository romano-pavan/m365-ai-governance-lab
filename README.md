# Microsoft 365 AI governance lab

A Microsoft 365 Business Premium tenant I built for a fictional vehicle importer. I use it to rehearse the first weeks of an AI and security lead role: identity lifecycle, an AI register, a data rule for AI tools, sensitivity labels and Copilot data residency settings.

The tenant, the settings, the scripts and the findings are real. The company, its people and its data are fictional. No customer or employer data is used anywhere in this repository.

## Why this exists

At my current employer I proposed and lead the rollout of ChatGPT Business, and I am preparing for the CISSP. A small production environment rarely asks for the governance side of AI adoption, so I practise it here and write every decision down.

Each piece of work is a ticket from a fictional colleague. A ticket starts with a vague request, goes through the questions I would ask before building, the build itself and a review, and ends with an entry in the decision log. The colleagues are role-played by an AI assistant (Claude), which also reviews the work.

## Tickets

| Ticket | What it delivers | CISSP domains | Status |
| --- | --- | --- | --- |
| [L00](docs/L00-tenant-setup.md) | Separate admin and break-glass accounts, 14 users from an HR export by script, dynamic groups, group-based licensing, least-privilege roles for the manager | 5, 1 | Done |
| [L01](docs/L01-ai-register.md) | AI register in SharePoint, a three-colour data rule for AI tools, four Purview sensitivity labels, review of Copilot data residency defaults | 2, 1 | Done |
| [L02](docs/L02-conditional-access.md) | Five Conditional Access policies in place of security defaults, an excluded emergency access group, onboarding with a Temporary Access Pass, report-only and What If before the switch | 5, 1 | Done, CA003 waits for hardware keys |

The scenario and the lab rules are in [docs/scenario.md](docs/scenario.md). Every decision, with its reason, is in [docs/decisions.md](docs/decisions.md).

## Findings worth reading

New EU tenants come with Copilot defaults that weaken the EU Data Boundary. In this tenant, created in October 2026, Anthropic models in Microsoft 365 apps and OpenAI as a Microsoft subprocessor were both enabled, and flex routing is on by default for EU tenants created after 25 March 2026. All three sit under the Microsoft Data Protection Addendum, so this is not a GDPR problem in itself. It does break the assumption that data stays with Microsoft inside the EU, which is what my data rule for AI tools relied on. Details, sources and the change I made: [findings/copilot-eu-data-boundary-defaults.md](findings/copilot-eu-data-boundary-defaults.md).

Turning off security defaults creates four Microsoft Conditional Access policies within seconds, already on. They close the gap until your own policies are on, but they overlap them and ignore your exclusions, so a dated exception in my own MFA policy existed only on paper until I turned Microsoft's four off. See [findings/security-defaults-upgrade-policies.md](findings/security-defaults-upgrade-policies.md).

A permission test caught what a review did not. The all-staff group ended up in Site Members (Edit) instead of Site Visitors (Read), so every employee could edit the AI register. Check Permissions on a test user showed it before the site was announced. See [L01](docs/L01-ai-register.md#verification).

On a Microsoft Customer Agreement trial, "Cancel on expiration" cancels the subscription immediately. Two trials were lost before I wrote the rule "billing settings are not touched during a trial". See [L00](docs/L00-tenant-setup.md#what-went-wrong).

## Repository layout

```
docs/       scenario, one document per ticket, decision log
findings/   findings with their sources
policy/     the data traffic light and the sensitivity label set
register/   AI register columns and sample entries
scripts/    PowerShell (Microsoft Graph) used in the tickets
data/       fictional HR export used by L00
images/     screenshots from the tenant
```

## Running the L00 script

You need PowerShell 7, the Microsoft Graph PowerShell SDK modules listed below and a test tenant of your own.

```powershell
Install-Module Microsoft.Graph.Authentication, Microsoft.Graph.Users, Microsoft.Graph.Groups, `
    Microsoft.Graph.Identity.DirectoryManagement, Microsoft.Graph.Identity.Governance -Scope CurrentUser

# Plan only: reads the CSV, validates it and prints what would change. Connects to nothing.
.\scripts\L00-kreiraj-korisnike.ps1 -CsvPath .\data\zaposlenici_adria_motori.csv -Domena yourtenant.onmicrosoft.com

# Execute: asks you to type DA, then signs in with delegated scopes and applies the plan. Existing users and groups are skipped.
.\scripts\L00-kreiraj-korisnike.ps1 -CsvPath .\data\zaposlenici_adria_motori.csv -Domena yourtenant.onmicrosoft.com -Izvrsi
```

Identifiers and messages in the script are in Croatian (`Izvrsi` means execute, `Domena` means domain). The script refuses to run if you are signed in to a tenant other than the one in `-Domena`.

## Security notes

- No secrets are stored in this repository. Temporary passwords are written to a file in the user's home folder, outside the repository, and `.gitignore` blocks that file by name in case it is ever copied in.
- The script uses delegated permissions only and runs as the signed-in administrator.
- Screenshots show the fictional tenant only. IP addresses and session identifiers are cropped out.

## Author

Romano Pavan, IT systems administrator, Croatia. [linkedin.com/in/romano-pavan](https://www.linkedin.com/in/romano-pavan)

Licensed under the MIT License, see [LICENSE](LICENSE).
