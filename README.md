# Real Estate Market Analysis — Saint Petersburg & Leningrad Oblast

SQL-based analysis of residential real estate listings to identify the
most attractive market segments, seasonal trends, and regional differences
across Saint Petersburg and the Leningrad Oblast — supporting a
go-to-market and dashboard-driven business strategy.

**Dashboard:** [Yandex DataLens](https://datalens.yandex.cloud/uexzz6cp08mih)
*(Yandex login required — see screenshots below for a preview)*

---

## 1. Business Context

A real estate agency based in Petrozavodsk is planning to expand into the
Saint Petersburg and Leningrad Oblast market and relocate its main office
there. They need a data-driven view of which property segments are most
attractive, and how seasonality and regional differences should shape
their go-to-market strategy.

**Goals:**
1. Identify the most attractive real estate segments in Saint Petersburg
   and Leningrad Oblast based on listing activity duration
2. Understand seasonal trends across the region to time marketing
   campaigns and market entry
3. Analyze the Leningrad Oblast market in more detail — which towns are
   most active and sell fastest

---

## 2. Tech Stack

- **PostgreSQL** — data querying (CTEs, percentile-based outlier filtering, window functions, CASE-based segmentation, multi-table joins)
- **Yandex DataLens** — dashboard & visualization

---

## 3. Data Schema

The dataset covers archival listings from the Yandex Real Estate service
for Saint Petersburg and Leningrad Oblast, spread across 4 related tables.

### `advertisement` — listing metadata
| Field | Description |
|---|---|
| `id` | Listing ID (primary key, linked to `flats.id`) |
| `first_day_exposition` | Date the listing was published |
| `days_exposition` | Number of days the listing stayed active on the site |
| `last_price` | Listed price, RUB |

### `flats` — property characteristics
| Field | Description |
|---|---|
| `id` | Apartment ID (primary key, linked to `advertisement.id`) |
| `city_id` | City ID (foreign key → `city.city_id`) |
| `type_id` | Settlement type ID (foreign key → `type.type_id`) |
| `total_area` | Total area, sqm |
| `rooms` | Number of rooms |
| `ceiling_height` | Ceiling height, m |
| `floors_total` | Total floors in the building |
| `living_area` | Living area, sqm |
| `floor` | Floor of the apartment |
| `is_apartment` | 1 = apartment-type unit, 0 = otherwise |
| `open_plan` | 1 = open floor plan, 0 = otherwise |
| `kitchen_area` | Kitchen area, sqm |
| `balcony` | Number of balconies |
| `airports_nearest` | Distance to nearest airport, m |
| `parks_around3000` | Number of parks within a 3 km radius |
| `ponds_around3000` | Number of water bodies within a 3 km radius |

### `city` — settlement directory
| Field | Description |
|---|---|
| `city_id` | Settlement ID (primary key) |
| `city` | Settlement name |

### `type` — settlement type directory
| Field | Description |
|---|---|
| `type_id` | Settlement type ID (primary key) |
| `type` | Settlement type name |

**ER diagram:**

```
advertisement ──┐
                 ├──< flats >──── city
                 │       │
                 └───────┴──── type
```

---

## 4. Methodology

1. **Outlier filtering** — used `PERCENTILE_DISC` (1st/99th percentiles) on
   `total_area`, `rooms`, `balcony`, and `ceiling_height` to exclude
   anomalous listings (~19% of records filtered out). This filtered set is
   reused as a base CTE across all three analytical queries — see
   [`sql/00_outlier_filtering.sql`](./sql/00_outlier_filtering.sql).
2. **Task 1 — Listing duration analysis** — segmented listings by region
   (Saint Petersburg vs. Leningrad Oblast) and activity duration (up to a
   month / up to 3 months / up to 6 months / 6+ months / still active),
   then compared price per sqm, area, rooms, and balconies across
   segments.
3. **Task 2 — Seasonality analysis** — mapped listing publication and
   removal dates to months (2015–2018, full years only) to identify
   seasonal patterns in activity, price, and apartment size.
4. **Task 3 — Leningrad Oblast deep dive** — ranked Oblast towns by
   listing volume, removal share, average price/area, and listing
   duration (towns with 50+ listings only, for statistical stability).

SQL implementations: see [`/sql`](./sql) folder.

---

## 5. Key Insights

**Listing duration by region**
In Saint Petersburg, "more than six months" and "up to three months" are
the most common duration segments, with roughly 1,000 more listings than
other categories — likely driven by higher prices and larger unit sizes.
The shortest activity segment ("up to a month") had 2,168 listings. In
Leningrad Oblast, "up to three months" dominates instead, with "up to a
month" again being the shortest segment.

**Price/area relationship differs by region**
In Saint Petersburg, price per sqm and apartment area both increase
together with longer listing duration — buyers are willing to wait longer
for larger, pricier units. In Leningrad Oblast, the relationship inverts:
the fastest-selling listings ("up to a month") have a *higher* price per
sqm but *smaller* area than longer-duration segments — a smaller, premium
product that moves quickly.

**Regional scale and pricing gap**
Saint Petersburg has roughly 3x the listing volume of Leningrad Oblast.
Average price per sqm differs by about 40,000 RUB between regions, and
average apartment size differs by about 10 sqm (60 sqm in SPb vs. ~49 sqm
in the Oblast). Typical building height also differs — 9–12 floors in SPb
vs. 5–9 floors in the Oblast.

**Seasonality**
Listing publications peak from **February to April** (likely the start of
the buying season) and again in **November**. Listing removals (a proxy
for sales) peak in **February, October, and November** — publication and
removal cycles move largely in sync, pointing to a clear seasonal rhythm
rather than a lag between listing and selling. Average price per sqm is
lowest in **May** (also a low-volume month) and highest in **August**.

**Leningrad Oblast towns**
- **Murino** has the highest listing volume, but also longer-than-average
  exposure time; its removal share is high (93%) but ranks just behind the leader.
- **Kudrovo** has the highest removal share (93%), suggesting the fastest
  relative sales activity among the towns analyzed.
- **Otradnoye** is the least active, with the lowest removal share (75%).
- **Pushkin** has the highest average price per sqm (~104,158 RUB);
  **Slantsy** has the lowest (~18,110 RUB) — roughly a 10x spread driven by
  town desirability rather than apartment size, which varies far less
  (43–55 sqm across the top 10 towns).
- **Sosnovy Bor** sells fastest (avg. ~85 days), likely reflecting limited
  local supply or demand; **Nikolskoye** sells slowest (avg. ~237 days),
  also likely a low-demand market.

---

## 6. Recommendations

1. **Leningrad Oblast** — focus inventory on compact, affordably-priced
   apartments; these sell measurably faster than larger units.
2. **Saint Petersburg** — develop a dedicated strategy for moving larger
   units, since high-end listings here both sell slower *and* carry
   higher prices — a longer sales cycle the business should plan around.
3. **Timing market entry / campaigns** — prioritize **February, October,
   and November**, when both publication and sales activity (removals)
   peak across the region.
4. **Town-level targeting in the Oblast** — **Murino, Kudrovo, and
   Shushary** show the strongest combination of listing volume and
   removal share, making them the most promising entry points outside
   Saint Petersburg, despite longer average time-to-sale.

---

## 7. Dashboard Preview

*(screenshots to be added)*

---

## 8. Repository Structure

```
.
├── README.md
└── sql/
    ├── 00_outlier_filtering.sql
    ├── 01_listing_duration.sql
    ├── 02_seasonality.sql
    └── 03_oblast_market_analysis.sql
```

---

## Author

**Vladislav Wiesner**
[LinkedIn](https://www.linkedin.com/in/vladislav-wiesner-317048300/) · [GitHub](https://github.com/w1benz)
