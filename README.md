# FootyStats Lab


FootyStats-Lab is a lightweight data pipeline for collecting match fixtures, generating Over 2.5 Goals and Both Teams To Score (BTTS) signals from FootyStats, and evaluating confidence accuracy over time.

This project focuses on **signal collection and validation**, not staking, bankroll management, or comparison with other models.

---

## Daily Workflow

Follow these steps each matchday to keep the dataset current.

---

## 1. Build the Daily Slate (Pre-Match)

Run once per matchday, before games start.

```bash
ruby scripts/slate.rb --all --from YYYY-MM-DD
````

Optional (include recent form data):

```bash
ruby scripts/slate.rb --all --from YYYY-MM-DD --form
```

This step:

* Pulls fixtures for the given date
* Creates the canonical list of matches to track
* Is safe to re-run if needed

---

## 2. Generate Recommendations (Pre-Match)

Run after the slate has been created.

```bash
ruby scripts/recommendations.rb YYYY-MM-DD
```

This step:

* Reads the daily slate
* Pulls FootyStats probabilities
* Generates Over 2.5 and BTTS recommendations
* Writes the picks output for that date

---

## 3. Update Final Results (Post-Match)

Run after matches finish (same day or next day).

```bash
ruby scripts/update_results.rb YYYY-MM-DD
```

This step:

* Fetches final match results
* Updates existing picks with outcomes
* Closes the loop for later analysis

---

## 4. Analyze Accuracy by Confidence (Not Daily)

Run periodically (weekly or ad-hoc).

```bash
ruby scripts/accuracy_by_confidence.rb
```

This step:

* Groups historical picks by confidence ranges
* Calculates hit rates for Over 2.5 and BTTS
* Validates confidence calibration over time

---

## TL;DR Daily Checklist

**Every matchday**

* Build the slate
* Generate recommendations

**After matches finish**

* Update results

**Occasionally**

* Review confidence accuracy

---

## Script Responsibilities

### `scripts/slate.rb`

**Reads**

* League configuration
* FootyStats fixtures endpoints

**Writes**

* Daily slate data (fixtures to track)
* Optional form data when `--form` is used

Purpose: defines which matches exist for a given day.

---

### `scripts/recommendations.rb`

**Reads**

* Daily slate created by `slate.rb`
* FootyStats probability data (Over 2.5, BTTS)

**Writes**

* Daily recommendations output

Purpose: converts fixtures into Over 2.5 and BTTS signals.

---

### `scripts/update_results.rb`

**Reads**

* Existing recommendations
* FootyStats final score and result data

**Writes**

* Updated recommendations with final outcomes:

  * final score
  * Over 2.5 hit/miss
  * BTTS hit/miss

Purpose: backfills outcomes once matches are complete.

---

### `scripts/accuracy_by_confidence.rb`

**Reads**

* Historical recommendations with results populated

**Writes**

* Aggregated accuracy statistics by confidence bucket
* Console output and/or analysis files

Purpose: evaluates whether higher confidence correlates with higher accuracy.

---

## Data Flow

```text
FootyStats API
      │
      ▼
slate.rb
(fixtures + optional form)
      │
      ▼
recommendations.rb
(O2.5 + BTTS signals)
      │
      ▼
update_results.rb
(final outcomes)
      │
      ▼
accuracy_by_confidence.rb
(confidence analysis)
```

---
```
