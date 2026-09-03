{% docs __overview__ %}

# Merlin & Co. Apothecaries

The analytics project behind Merlin & Co., a fifteen-shop potion retailer.

Three source systems land here:

- **grimoire_crm** — customers, guilds, and guild memberships
- **abra_pos** — the point-of-sale: orders, order lines, payments, and the potion catalogue
- **alembic_ops** — shops, suppliers, ingredients, recipes, and brew events

Everything upstream arrives as text, so the staging layer does the conforming:
casing, the two timestamp formats, messy booleans, and the region coding.

{% enddocs %}


{% docs copper_and_gold %}

Merlin & Co. records every price in **copper pieces** because the point-of-sale
predates decimal currency. Reporting is in **gold crowns**.

100 copper == 1 gold crown. The rate lives in the `copper_per_gold_crown`
project var so finance can re-denominate without a code change.

Columns are suffixed to make the unit explicit: `_copper` for the raw integer,
`_gold` for the converted value.

{% enddocs %}


{% docs canonical_region %}

Merlin & Co. operates in five regions, three shops each:

- Northern Reaches
- Crystal Vale
- The Marshlands
- Ember Coast
- Silverwood

`raw_shops.region` carries the **canonical spelling**. The CRM's
`home_region` does not — it codes the same five regions four different ways
(`NR`, `nr`, `Northern Reaches`, `northern reaches`). The `normalize_region`
macro conforms the CRM values to the shop spelling, and revenue-by-region takes
the `orders -> shops.region` path rather than trusting the CRM value.

{% enddocs %}


{% docs pipeline_run_mode %}

`PIPELINE_RUN_MODE` controls how the order fact tables materialize.

- `standard` (the default, and what the nightly deploy job uses) — tables
- `backfill` — set by hand when reprocessing history

{% enddocs %}
