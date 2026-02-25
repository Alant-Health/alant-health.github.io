# AGENT.md — Alant Health Website Guidelines

> This file documents the structure, conventions, and rules for the **Alant Health** website.
> It should be consulted by any AI agent or contributor before making edits.

---

## 1. Site Overview

| Field       | Value                                      |
|-------------|--------------------------------------------|
| **Name**    | Alant Health                               |
| **Domain**  | `www.alant.health`                         |
| **Engine**  | Jekyll (≥ 3.8.5), GitHub Pages             |
| **Theme**   | Clean Blog (custom fork)                   |
| **Owner**   | Abed Hammoud (`abed@alant.health`)         |
| **Repo**    | `alant-health.github.io`                   |

The site serves as a professional portfolio and news hub for Alant Health,
covering neurotechnology, medtech, and healthcare innovation.

---

## 2. Directory Structure

```
├── _config.yml            # Jekyll configuration
├── _layouts/
│   ├── default.html       # Base layout (head, navbar, footer, scripts)
│   ├── home.html          # Homepage (hero + professional bio + paginated posts)
│   ├── page.html          # Static pages (About, Contact, Privacy)
│   └── post.html          # Individual post/article layout
├── _includes/
│   ├── head.html          # <head> meta, CSS
│   ├── navbar.html        # Site navigation
│   ├── footer.html        # Site footer
│   ├── scripts.html       # JS includes
│   ├── read_time.html     # Reading time calculation
│   └── google-analytics.html
├── _posts/                # All posts (HTML files, date-prefixed)
├── _sass/
│   └── styles.scss        # Custom styles
├── assets/
│   └── main.scss          # Sass entry point
├── img/
│   ├── bg-alanthealth.jpg # Default background image
│   └── posts/             # Post-specific images
├── index.html             # Homepage content
├── about.html             # About page
├── contact.html           # Contact page
├── privacy-policy.html    # Privacy policy
├── llms.txt               # LLM-friendly site summary (llmstxt.org spec)
├── AGENT.md               # This file — agent/contributor guidelines
├── CNAME                  # Custom domain: www.alant.health
├── Gemfile                # Ruby dependencies
└── posts/                 # Pagination output directory
```

---

## 3. Post Conventions

### 3.1 File Naming

Posts **must** follow Jekyll's required naming convention:

```
YYYY-MM-DD-slug.html
```

- Date format: `YYYY-MM-DD` (e.g., `2026-02-25`)
- Slug: lowercase, hyphen-separated, descriptive (e.g., `clee-tech-eu`)
- Extension: `.html` (all posts use raw HTML, not Markdown)
- **No spaces** in filenames — Jekyll will not process files that don't match this pattern

Examples:
- `2026-02-25-clee-tech-eu.html`
- `2025-03-21-clee-venture-kick.html`
- `2008-11-20-renishaw-acquisition-i.html`

### 3.2 Front Matter

Every post requires this YAML front matter:

```yaml
---
layout: post
title: "Post Title Here"
subtitle: "Optional subtitle"        # optional
date: YYYY-MM-DD
background: '/img/bg-alanthealth.jpg'
---
```

| Field        | Required | Notes                                                       |
|--------------|----------|-------------------------------------------------------------|
| `layout`     | **Yes**  | Always `post`                                               |
| `title`      | **Yes**  | Wrapped in double quotes                                    |
| `subtitle`   | No       | Short summary; displayed below title in post header         |
| `date`       | **Yes**  | `YYYY-MM-DD` format, no time or timezone                    |
| `background` | **Yes**  | Default: `'/img/bg-alanthealth.jpg'`; can use post-specific |
| `author`     | No       | Not typically used; defaults to site author ("Alant Health") |

**Do not use**: `tags`, `categories`, `permalink`, or other front matter fields —
they are not part of the site's design.

### 3.3 Post Content Structure

Posts are **plain HTML** (not Markdown). The typical structure is:

```html
<!-- 1. Optional source/byline header -->
<div class="mb-4">
  <h3 class="font-weight-bold">Source Name</h3>
  <p class="font-italic">By Author — Date</p>
</div>

<!-- 2. Optional featured image -->
<figure>
  <img src="/img/posts/image-name.png" alt="Descriptive alt text">
  <figcaption>Optional caption</figcaption>
</figure>

<!-- 3. Body text — sequence of <p> tags -->
<p>Article body text with <a href="https://example.com">inline links</a>.</p>

<!-- 4. Optional blockquotes for direct quotes -->
<blockquote>
  <p>"Quote text here."</p>
</blockquote>

<!-- 5. Optional subsections -->
<h3>Section Heading</h3>
<p>Section content...</p>

<!-- 6. Optional embedded LinkedIn post -->
<iframe src="https://www.linkedin.com/embed/feed/update/urn:li:share:XXXXX"
  height="800" width="504" frameborder="0" allowfullscreen=""
  title="Embedded post"></iframe>

<!-- 7. Optional source attribution -->
<p><strong>Source:</strong> <a href="https://example.com/article">Source Name</a></p>
```

### 3.4 Post Types

| Type                  | Description                                         |
|-----------------------|-----------------------------------------------------|
| **Press Release**     | Full article text, source header, source attribution |
| **LinkedIn Embed**    | Brief intro + `<iframe>` embedding a LinkedIn post   |
| **Formal PR**         | Dateline format, blockquotes, media contacts section |

---

## 4. Image Guidelines

### 4.1 Storage

- **Post images**: `/img/posts/` — all post-specific images go here
- **Site backgrounds**: `/img/` — site-wide background images

### 4.2 Naming

- Lowercase, hyphen-separated, descriptive
- Examples: `cleemedical-tech-eu.png`, `rhovica-founders.jpg`, `neuromate-peru-team.png`
- Accepted formats: `.jpg`, `.png`, `.webp`

### 4.3 Referencing

Always use **absolute paths from site root**:

```html
<img src="/img/posts/image-name.png" alt="Descriptive alt text">
```

### 4.4 Image Markup

Preferred pattern using `<figure>`:

```html
<figure>
  <img src="/img/posts/image-name.png" alt="Descriptive alt text">
  <figcaption>Optional caption text</figcaption>
</figure>
```

Alternative with Bootstrap classes:

```html
<div class="text-center">
  <img class="img-fluid rounded mb-4" src="/img/posts/image-name.png" alt="...">
  <p class="caption">Caption text</p>
</div>
```

### 4.5 Downloading External Images

When creating a post from an external article, **always download images locally**
to `/img/posts/` rather than hotlinking to external URLs.

---

## 5. HTML & Formatting Conventions

| Element        | Convention                                          |
|----------------|-----------------------------------------------------|
| **Bold**       | `<strong>` (never `<b>`)                            |
| **Italic**     | `class="font-italic"` (Bootstrap) or `<em>`         |
| **Blockquotes**| `<blockquote>` for direct quotes                    |
| **Links**      | `<a href="...">` with full URLs                     |
| **Line breaks**| `<br/>` (self-closing with slash)                   |
| **Em dashes**  | `&mdash;`                                           |
| **HR**         | `<hr>` to separate sections                         |
| **Headings**   | `<h3>` for subsections, `<h4>` for sub-subsections  |

---

## 6. Pagination

- Posts are paginated at **5 per page** on the homepage
- Pagination output goes to `/posts/page:num/`
- Configured via `jekyll-paginate` plugin

---

## 7. Plugins

| Plugin             | Purpose                    |
|--------------------|----------------------------|
| `jekyll-feed`      | RSS/Atom feed generation   |
| `jekyll-paginate`  | Homepage post pagination   |
| `jekyll-sitemap`   | Sitemap generation         |

---

## 8. Deployment

- Hosted on **GitHub Pages**
- Custom domain: `www.alant.health` (configured via `CNAME`)
- Push to `main` branch triggers automatic deployment
- Google Analytics: `UA-116925250-1` (legacy Universal Analytics; migrate to GA4 when available)

---

## 9. Checklist for Adding a New Post

1. **Create the file** in `_posts/` with correct naming: `YYYY-MM-DD-slug.html`
2. **Add front matter** with `layout: post`, `title`, `date`, and `background`
3. **Download any images** to `/img/posts/` — do not hotlink
4. **Reference images** using absolute paths from root (`/img/posts/...`)
5. **Add source attribution** at the bottom if content is from an external source
6. **Use HTML** — not Markdown — for post content
7. **Update `llms.txt`** if the post is significant (e.g., a major announcement) — add it to the "Recent News" section
8. **Test locally** with `bundle exec jekyll serve` if possible before pushing

---

## 10. llms.txt Maintenance

The site includes a `/llms.txt` file following the [llmstxt.org](https://llmstxt.org/) specification.
This file helps AI models understand the site's content at inference time.

**When to update `llms.txt`:**
- When a significant news item or press release is added (update the "Recent News" section)
- When board roles, expertise areas, or professional track record changes
- When new pages are added to the site
- Keep "Recent News" to the 3–5 most notable items

**Format rules** (per llmstxt.org spec):
- H1: Site name (required, do not change)
- Blockquote: Site summary (required)
- H2 sections: Categorized link lists with `[name](url): description` format
- "Optional" H2 section: Content LLMs can skip for shorter context
