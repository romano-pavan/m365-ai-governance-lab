# Sensitivity labels

Four labels in Microsoft Purview, created in order of sensitivity so that priority rises from Javno (0) to Strogo povjerljivo (3). All four are scoped to files and email, carry no encryption or content marking, and are not published in any label policy yet.

| Priority | Name | Display name | Description for users | Colour | Traffic light |
| --- | --- | --- | --- | --- | --- |
| 0 | Javno | Javno | Smije van firme i u bilo koji AI alat. Cjenici, katalozi, objave. | Green | Green |
| 1 | Interno | Interno | Samo za zaposlenike. U AI samo odobrene alate uz službenu prijavu. | Yellow | Yellow |
| 2 | Povjerljivo | Povjerljivo | Samo za one kojima treba za posao: ugovori, marže, podaci kupaca. U AI samo odobrene alate uz službenu prijavu. | Yellow | Yellow |
| 3 | Strogo povjerljivo | Strogo povjerljivo | Plaće, zdravlje, kadrovski postupci, lozinke. Ne ide u AI ni van firme. | Red | Red |

English meaning of the user descriptions:

| Label | Meaning |
| --- | --- |
| Javno | May leave the company and go into any AI tool. Price lists, catalogues, published posts. |
| Interno | Employees only. Into AI only through approved tools with the work account. |
| Povjerljivo | Only for people who need it for their work: contracts, margins, customer data. Into AI only through approved tools with the work account. |
| Strogo povjerljivo | Salaries, health, HR proceedings, passwords. Never into AI, never outside the company. |

Description for admins, on every label: "L01. Razina iz semafora. Bez zaštite i obilježavanja do A09." (Level from the traffic light; no protection or marking until A09.)

Why no encryption yet: an encrypting label changes what Copilot and search can read and breaks sharing with partners, so it is decided together with the oversharing review rather than up front.

Labeling and marking are kept apart on purpose. A label is metadata that machines read; marking (a header, footer or watermark) is what a person sees. These labels do labeling only.
