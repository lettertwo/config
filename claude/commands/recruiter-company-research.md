---
name: recruiter-company-research
description: Research a company before responding to a recruiter or applying for a software engineering role. Use this skill whenever a user mentions a recruiter reached out, they received a recruiting message, they're considering responding to a job opportunity, or they want to know if a company is worth pursuing. Triggers on phrases like "recruiter reached out", "should I respond", "what do you know about [company] as an employer", "researching [company] for a job", "is [company] a good place to work". Always use this skill proactively when a user shares a company name in a job-search context.
---

# Recruiter Company Research Skill

Helps the user quickly decide whether to respond to a recruiter or pursue a job opportunity by producing a structured scorecard with key signals pulled from web research.

## Output Format

Produce two sections:

### 1. Scorecard Table

| Signal | Finding | Grade |
|---|---|---|
| Recent layoffs | ... | 🟢/🟡/🔴 |
| Comp competitiveness | ... | 🟢/🟡/🔴 |
| CEO / leadership approval | ... | 🟢/🟡/🔴 |
| Engineering team growth | ... | 🟢/🟡/🔴 |
| Glassdoor rating | ... | 🟢/🟡/🔴 |
| Blind sentiment | ... | 🟢/🟡/🔴 |
| Funding & financials | ... | 🟢/🟡/🔴 |
| News sentiment | ... | 🟢/🟡/🔴 |
| **Overall** | **One-line verdict** | 🟢/🟡/🔴 |

Grading rubric:
- 🟢 Positive signal, no concerns
- 🟡 Mixed or unclear — worth watching
- 🔴 Red flag — notable concern

### 2. Key Flags

Two brief bullet lists:

**🚩 Concerns**
- Up to 3 bullets, only if real red/yellow flags exist

**✅ Green Flags**
- Up to 3 bullets, only if genuinely positive signals exist

Keep each bullet to one sentence. Don't pad — if there are no real concerns, say so.

### 3. Sources

A short list of the actual URLs used during research, labeled by source type. Include only pages that meaningfully informed the scorecard — skip search result pages or aggregators that didn't add value. Format:

- **Glassdoor (reviews):** https://...
- **Glassdoor (salaries):** https://...
- **Levels.fyi:** https://...
- **Blind:** https://...
- **Crunchbase:** https://...
- **News:** https://... — [publication name]

Omit any source type if no useful page was found.

---

## Research Process

Use `web_search` to find data on each signal. Suggested queries per signal:

| Signal | Suggested search queries |
|---|---|
| Recent layoffs | `"[company] layoffs 2024 2025"`, `"[company] headcount reduction"` |
| Comp competitiveness | `"[company] software engineer salary levels.fyi"`, `"[company] SWE compensation reddit"` |
| CEO approval | `"[company] CEO glassdoor"`, `"[company] CEO approval rating"` |
| Glassdoor rating | `"[company] glassdoor rating reviews"` |
| Blind sentiment | `"[company] site:teamblind.com"`, `"[company] blind app reviews engineers"` |
| Funding & financials | `"[company] crunchbase funding"`, `"[company] valuation revenue 2025"` |
| Engineering team | `"[company] engineering team size growth"`, LinkedIn jobs count |
| News sentiment | `"[company] news 2025"`, `"[company] funding"`, `"[company] controversy"` |

Use `web_fetch` to retrieve full pages when snippets are insufficient (e.g., Glassdoor review pages, Crunchbase profile, Blind company page, LinkedIn).

Search efficiently — 1 query per signal is usually enough. Only go deeper if the first result is ambiguous or outdated.

---

## Tone & Length

- Be direct and opinionated. The user wants a fast decision, not a research paper.
- Total response should be scannable in under 60 seconds.
- Don't hedge everything with "this may vary" — make a call.
- If data is genuinely unavailable for a signal, write "Limited data" and grade 🟡.

---

## Priority Signals

The user cares most about these three — give them extra weight in the overall grade:
1. **Recent layoffs** — a 🔴 here should drag the overall down significantly
2. **Comp competitiveness** — a 🔴 here is a significant negative
3. **CEO/leadership approval** — below 60% on Glassdoor = 🔴

---

## Example Output

**Stripe — Recruiter Response Scorecard**

| Signal | Finding | Grade |
|---|---|---|
| Recent layoffs | 14% reduction in Nov 2023; no major cuts since | 🟡 |
| Comp competitiveness | Top of market per levels.fyi; equity-heavy packages | 🟢 |
| CEO / leadership approval | Patrick Collison at 91% on Glassdoor | 🟢 |
| Engineering team growth | Active hiring in infra and payments in 2025 | 🟢 |
| Glassdoor rating | 4.3/5 across 2,400+ reviews | 🟢 |
| Blind sentiment | Generally positive; engineers praise eng culture, flag long hours | 🟡 |
| Funding & financials | $6.5B raised; profitable per Crunchbase; IPO pending | 🟢 |
| News sentiment | Positive; IPO speculation ongoing | 🟡 |
| **Overall** | **Strong opportunity — worth a conversation** | 🟢 |

**🚩 Concerns**
- 2023 layoffs show willingness to cut headcount in downturns; worth asking about current org stability

**✅ Green Flags**
- Compensation is top of market with strong equity upside
- Leadership has unusually high approval ratings for a company this size

**Sources**
- **Glassdoor (reviews):** https://www.glassdoor.com/Reviews/Stripe-Reviews-E288690.htm
- **Levels.fyi:** https://www.levels.fyi/companies/stripe/salaries/software-engineer
- **Blind:** https://www.teamblind.com/company/Stripe
- **Crunchbase:** https://www.crunchbase.com/organization/stripe
- **News:** https://techcrunch.com/2023/11/... — TechCrunch

---

## Obsidian Export

After generating the report, save it to the Obsidian vault as a markdown file.

**Vault path:** `/Users/erice/Library/Mobile Documents/iCloud~md~obsidian/Documents/lettertwo/`

**Directory:** `Job Search/Recruiter Research/`

**Filename format:** `YYYY-MM-DD Company Name GRADE.md`
- Use today's date from `currentDate` memory (or `date` shell command if unavailable)
- Use the overall grade emoji: 🟢, 🟡, or 🔴
- Example: `2026-02-26 Boulevard 🟡.md`

**File format:** Prepend YAML frontmatter before the scorecard content:

```yaml
---
tags:
  - recruiter
  - job-search
company: <Company Name>
role: <Role Title from recruiter message>
recruiter: <Recruiter name if known>
date: <YYYY-MM-DD>
grade: "<🟢 or 🟡 or 🔴>"
---
```

Then append the full scorecard output (scorecard table, key flags, sources, and suggested reply if generated).

Use the `Write` tool to create the file. Confirm the file path to the user after saving.
