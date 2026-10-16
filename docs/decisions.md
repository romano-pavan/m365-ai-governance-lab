# Decision log

Short entries, newest last. Each says what was decided and why, and what would make me revisit it.

## D-001 A separate admin account without a licence (L00)

Administration happens in `adm-romano`, which has Global Administrator and no licence, so it has no mailbox, no OneDrive and nothing to phish through everyday mail. My daily account `romano.pavan` has a licence and no admin role. Revisit if a feature I need to manage requires the admin to hold a licence.

## D-002 A break-glass account before any key exists (L00)

`bg-01` exists so that a broken policy or a lost phone cannot lock everyone out. It should sign in with a FIDO2 key kept offline, and there is no key yet. Having the account with a weaker sign-in is better than not having it, and the gap is written down as an accepted risk until two keys are bought.

## D-003 Licences follow a dynamic group, not people (L00)

`GRP-Licenca-BusinessPremium` contains every enabled account whose `companyName` is the company. A new employee gets a licence as soon as HR data says they work here, and a disabled account loses it. Admin and break-glass accounts have no `companyName`, so they stay out without an exclusion list.

## D-004 Billing settings are not touched during a trial (L00)

Two trials were cancelled on the same day by settings whose labels suggested otherwise. The paid continuation is set to one monthly licence, the decision is made in the fourth week, and the agreement allows cancellation with a refund within seven days.

## D-005 The AI register is for IT only (L01)

The requester wanted champions and managers to see the register. It holds risk ratings, supplier weaknesses and the name of a colleague using an unapproved tool, so it follows need-to-know. Everyone sees the policy page, which lists the approved tools. Champions get read access through their own group when it exists.

## D-006 Internal and confidential data share one colour (L01)

The traffic light answers which tool may take the data. Internal and confidential differ in who inside the company may see them, which permissions and labels already handle. Three colours are what people remember; the finer limit per tool sits in the register's "highest data class" column.

## D-007 Labels without encryption, not published (L01)

Legal wanted to see the label names first. Encryption changes what Copilot and search can read and breaks sharing outside the company, so it waits until the oversharing review. An unpublished label costs nothing and can be changed freely.

## D-008 Copilot defaults that leave the EU are turned off (L01)

Flex routing, Anthropic models in Microsoft 365 apps and OpenAI as a subprocessor were on or enabled by default. They are covered by the Microsoft DPA, but the data rule for yellow data assumes processing stays with Microsoft inside the EU, so all three were turned off. The rule: the technical owner may tighten a setting at once and records it in the register; loosening goes through approval. Message center sends a weekly digest, because these defaults arrive through it.

## D-009 SharePoint and OneDrive label processing stays on (L01)

It was switched on by accident. With no label published it changes nothing for users, and a later ticket needs it. Turning it off later would stop co-authoring and search for files encrypted by a label from then on and leave a mixed state that is hard to support, so it stays on and is logged as an unplanned change.
