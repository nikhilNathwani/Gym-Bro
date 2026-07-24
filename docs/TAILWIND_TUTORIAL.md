# Tailwind CSS: a tutorial, using this project as the example

You're using Tailwind v4 in Gym Bro already (`package.json` → `tailwindcss: "^4"`). This doc
teaches you the concepts by pointing at the actual code in this repo, so you can cross-reference
live examples instead of memorizing an abstract syntax.

## 1. Why Tailwind exists (and why not vanilla CSS)

**Vanilla CSS workflow:** you write a `.css` file with selectors (`.workout-card { ... }`), then
go to your `.tsx`/`.html` and add `className="workout-card"`. Every new visual tweak means
jumping between two files, inventing a class name, and hoping you don't have a stale, unused rule
sitting in the CSS file six months later (nothing tells you it's dead).

**Tailwind's approach:** instead of naming things, you compose pre-defined utility classes
directly in your markup. One class = one CSS property (roughly). Look at the home page:

```tsx
// src/app/page.tsx
<div className="mx-auto flex min-h-screen w-full max-w-md flex-col gap-6 px-4 py-8">
```

That's: center horizontally, use flexbox, full viewport height minimum, full width capped at a
medium max-width, stack children vertically, gap between them, horizontal/vertical padding. In
vanilla CSS that's a class definition, seven declarations, and a trip to a separate file.

**Why this is worth reaching for — including for a solo project like Gym Bro:**

- **No naming problem.** You never have to decide between `.card`, `.workout-card`,
  `.day-tile`, `.exercise-item` and then remember which one you used where. This matters more
  than it sounds — naming things is genuinely one of the more tedious parts of CSS at scale.
- **Nothing goes stale.** Delete a `<div>` and its styling disappears with it. There's no
  orphaned `.css` rule silently bloating your stylesheet because you forgot to remove it — a real
  problem in hand-written CSS codebases.
- **The build only ships classes you actually used.** Tailwind scans your source files and
  generates a CSS file containing only the utilities you reference — see `postcss.config.mjs` and
  `tailwindcss: "^4"` in `devDependencies`. You get a tiny production stylesheet without manually
  auditing for unused rules.
- **A constrained design system, for free.** Vanilla CSS lets you write `padding: 13px` and
  `padding: 14px` in two different places by accident. Tailwind's spacing/color/font-size scales
  (`p-3`, `p-4`... `text-sm`, `text-lg`...) are a fixed set of steps, so your UI stays visually
  consistent without you enforcing it by discipline.
- **Colocation makes solo iteration fast.** For a project where you're both the designer and the
  only engineer (this one), not context-switching between a component file and a stylesheet is a
  real speed win — you see and change the visual result in the same place you're editing markup.

**The honest tradeoff:** class-heavy JSX lines (see the `<div>` above) look noisy at first, and
there's a real vocabulary to learn (`gap-6` vs `space-y-6`, `items-center` vs `justify-center`).
Section 10 below goes into this and other drawbacks in more detail — it's not a free lunch.

**Is it a good resume/signal thing?** Yes, reasonably. Tailwind is extremely common in current
job postings for frontend/full-stack roles, it's the default styling choice for most modern React
scaffolding (Next.js's own `create-next-app` offers it out of the box, which is why it's already
in this repo), and it pairs with widely-used component libraries (shadcn/ui, etc.) that assume
Tailwind underneath. Knowing it signals you can be productive in a very common modern stack
immediately. It's not a substitute for understanding CSS fundamentals (flexbox, the box model,
specificity) — interviewers may probe for that underneath — but as a practical, resume-listable
tool, it's a legitimate one to claim once you've actually built something with it, which you're
doing here.

## 2. The mental model: utility classes

Every Tailwind class maps to (usually) one CSS declaration. Once you know the pattern, you can
often guess the class name:

| CSS you want | Tailwind class |
|---|---|
| `display: flex;` | `flex` |
| `flex-direction: column;` | `flex-col` |
| `padding: 1rem;` | `p-4` |
| `padding-left/right: 1rem;` | `px-4` |
| `padding-top/bottom: 2rem;` | `py-8` |
| `gap: 1.5rem;` | `gap-6` |
| `font-weight: 600;` | `font-semibold` |
| `font-size: 1.5rem;` | `text-2xl` |
| `border-width: 2px;` | `border-2` |

Numbers like `4`, `6`, `8` in spacing utilities aren't pixels — they're steps on Tailwind's scale,
where each step = `0.25rem` (4px). So `p-4` = `1rem` = `16px`, `gap-6` = `1.5rem` = `24px`. This
is the "constrained design system" from section 1 — you literally cannot pick an arbitrary
in-between value without opting in explicitly (see section 7).

**Live example — the exercise cards in `src/app/days/[id]/page.tsx`:**

```tsx
<details className="border-2 border-black" open={i === 0}>
  <summary className="cursor-pointer list-none px-5 py-4">
```

- `border-2 border-black` → a 2px solid black border (color and width are separate utilities)
- `cursor-pointer` → `cursor: pointer;`
- `list-none` → removes the default disclosure-triangle marker on `<summary>`
- `px-5 py-4` → horizontal padding of `1.25rem`, vertical padding of `1rem`

## 3. How do you actually keep the scale straight?

Fair question, and the honest answer: **nobody memorizes the full scale, and you're not supposed
to.** Here's how it actually works in practice:

- **Editor tooling does the lookup for you.** Install the official **"Tailwind CSS
  IntelliSense"** extension in VS Code. It gives you:
  - Autocomplete as you type inside a `className` string — start typing `gap-` and it lists every
    valid value (`gap-0`, `gap-1`, `gap-1.5`, `gap-2`...) before you commit to one.
  - A hover tooltip showing the exact compiled CSS for any class — hover over `gap-6` in
    `src/app/page.tsx` right now and it'll show you `gap: 1.5rem; /* 24px */` directly. This is the
    #1 way people actually "know" what a class does day to day — they look, they don't recall from
    memory.
  - Inline color swatches next to color classes, so `text-black` / `bg-background` show a little
    colored square in the gutter.
- **The docs site is a live reference, not something you read cover-to-cover.** Every utility page
  at tailwindcss.com/docs has the complete scale table for that property. Experienced devs still
  open it constantly — habitually keeping a reference tab open is completely normal, not a sign of
  not knowing Tailwind.
- **Formatting is automated, so you never think about class order.** The
  `prettier-plugin-tailwindcss` plugin auto-sorts classes into a canonical order on save, so
  arguments like "should `flex` come before or after `gap-6`?" never come up — the tool decides.
  This project doesn't have it installed yet; it's a reasonable thing to add later if the
  class-order noise starts to bother you.
- **What people actually do memorize:** through sheer repetition, most developers end up with the
  10–15 values they reach for constantly baked into muscle memory — for spacing that's usually
  `1`/`2`/`4`/`6`/`8`, for text size it's `sm`/`base`/`lg`/`xl`/`2xl`, for font weight it's
  `medium`/`semibold`/`bold`. The long tail (an exact `13px` offset, a one-off shade) is *always*
  looked up or expressed as an arbitrary value (section 7) — even by people who've used Tailwind
  for years. Section 11 at the bottom of this doc has a condensed cheat sheet for exactly this
  purpose, so you have something to glance at without leaving this file.

## 4. Layout: Flexbox utilities

This whole app is built with flexbox, not CSS Grid, because the layouts are simple single-column
stacks. From `src/app/page.tsx`:

```tsx
<div className="flex items-center justify-between border-b-2 border-black pb-4">
  <h1 className="text-2xl font-semibold">Gym Bro</h1>
  <form action={logout}>...</form>
</div>
```

- `flex` → establishes a flex container (children lay out in a row by default)
- `items-center` → `align-items: center;` (vertically centers the title and the logout button)
- `justify-between` → `justify-content: space-between;` (pushes the title left, button right)

And the vertical stack right below it:

```tsx
<div className="flex flex-col gap-3">
  {days.map((day) => ( ... ))}
</div>
```

- `flex-col` → `flex-direction: column;`, so children stack top-to-bottom
- `gap-3` → even spacing between children without needing margin on each child individually

**Try it:** in `src/app/page.tsx`, change `justify-between` to `justify-center` and reload —
you'll see the title and logout button move together in the middle instead of splitting to the
edges. That kind of instant, in-place experiment is the fastest way to build intuition.

## 5. Colors and this project's off-white/black theme

Tailwind ships a full color palette (`neutral-500`, `red-600`, etc.) as classes like
`text-neutral-500`, `bg-red-600`. **This project deliberately isn't using any of them right now** —
every color in the UI is one of exactly two values, so the wireframe stays pure black-on-off-white
with no gray creeping in while the design is still being conceptualized. You'll see that
constraint enforced with plain `text-black` throughout, instead of a gray shade, even for
secondary/muted text like the "No days yet" empty state.

Those two colors are defined once as **CSS custom properties wired into Tailwind's theme**, in
`src/app/globals.css`:

```css
:root {
  --background: #faf8f4;
  --foreground: #111111;
}

@theme inline {
  --color-background: var(--background);
  --color-foreground: var(--foreground);
}
```

That `@theme inline` block is Tailwind v4's config mechanism — notice there's no
`tailwind.config.js` file in this repo at all. In Tailwind v3 you configured your theme in a JS
file; in v4 you do it directly in CSS with `@theme`. Declaring `--color-background` there is what
makes `bg-background` and `text-background` valid utility classes elsewhere in the app — e.g. the
login button:

```tsx
// src/app/login/page.tsx
className="... bg-black px-4 py-3 text-base font-medium text-background active:bg-background active:text-black"
```

`text-background` here means "use the theme's background color as the text color" — since the
button itself is `bg-black`, this renders as off-white text on a black button. On press
(`active:`), it fully inverts to an off-white button with black text — still only the two colors,
just swapped. Defining the colors once as variables (rather than hardcoding `#faf8f4` everywhere)
means changing the whole app's palette later — including reintroducing grays, if you want them
once you move past the wireframe stage — is a one- or two-line edit in `globals.css` rather than a
find-and-replace across every file.

## 6. State variants: `hover:`, `active:`, `focus:`

Prefix any utility with a state name and a colon, and it only applies during that state. From the
home page:

```tsx
className="border-2 border-black px-5 py-4 text-lg font-medium active:bg-black active:text-background"
```

Normally this link has a black border on an off-white background. `active:bg-black
active:text-background` says: *while being pressed/clicked*, invert to a black background with
off-white text. No JavaScript, no separate CSS rule with a `:active` pseudo-class — just another
class name, colocated with the rest of the element's styling. Same two-color rule applies here as
in section 5 — the "highlight" is an inversion of black/off-white, not a third gray tone.

**Try it:** since desktop users hover before they click (unlike touchscreens), you could add a
`hover:` variant to the day-link cards in `src/app/page.tsx` for a press-preview effect. To keep
the two-color rule intact, invert border-weight or use the same black/off-white swap instead of a
gray hover shade — e.g. `hover:border-4` for a "thickening" hover cue with zero new colors.

## 7. Responsive design: breakpoint prefixes

Not used much in this project yet (it's intentionally a fixed `max-w-md` mobile-width column),
but it's core Tailwind and worth knowing. Breakpoint prefixes work the same way state variants do:

```tsx
className="text-base md:text-lg lg:text-xl"
```

This means: `text-base` by default, `text-lg` from the `md` breakpoint (768px) up, `text-xl` from
`lg` (1024px) up. Tailwind is **mobile-first**: unprefixed utilities are the base/smallest-screen
style, and each prefix overrides it going *up* in screen size — never down. If you eventually want
Gym Bro to also look good on a tablet or desktop browser instead of staying phone-width, this is
the mechanism you'd reach for on `src/app/page.tsx`'s outer `max-w-md` container.

## 8. Arbitrary values: escaping the scale

Sometimes the fixed scale doesn't have the exact value you need. Square-bracket syntax lets you
drop to a raw CSS value without leaving the class list:

```tsx
className="bg-[#faf8f4]"       // arbitrary hex color
className="top-[3px]"          // arbitrary pixel value
className="grid-cols-[1fr_2fr]" // arbitrary grid-template-columns
```

This project doesn't currently use arbitrary values — it defines the off-white/black colors as
named theme variables instead (section 5), which is generally the better pattern once a value is
used more than once. Reach for square brackets for genuine one-offs; reach for `@theme` when a
value is part of your actual design system.

## 9. When utility classes get repetitive: extraction options

Look at `src/app/page.tsx` — the logout button and the day-link cards share almost the same
border/padding/active-state classes. Right now they're just duplicated, which is fine at this
size. Once a pattern repeats across many places, you have two escape hatches:

1. **Extract a React component** (the idiomatic move in this codebase — you're already in
   React/Next.js, so a `<WireframeButton>` or `<WireframeCard>` component wrapping the className
   string is the natural fix, not a CSS-level one).
2. **`@apply` in CSS** (Tailwind's own escape hatch, for cases where a component wrapper doesn't
   fit): in `globals.css` you could write
   ```css
   .wireframe-box {
     @apply border-2 border-black px-5 py-4;
   }
   ```
   and use `className="wireframe-box"` in markup. Reach for this rarely — it reintroduces the
   naming problem from section 1, so prefer component extraction in a React codebase like this
   one.

## 10. Drawbacks and limitations of utility-first CSS

Tailwind is a genuine tradeoff, not a strict upgrade over vanilla CSS. Things people run into:

- **Upfront lookup overhead.** Until the muscle memory in section 3 kicks in, you're constantly
  translating "I want 24px of gap" → "gap-6," which is real friction for the first few weeks. This
  is the honest cost of the "constrained design system" benefit from section 1 — the constraint
  has to come from *somewhere*, and until you've internalized the scale, that somewhere is you
  pausing to look it up.
- **Verbose, noisy markup.** Long `className` strings (this project's are still fairly short) can
  make JSX harder to skim, especially once a component has several conditional/state variants
  layered on. Structure ("what element is this and what does it do") gets buried next to styling
  ("what does it look like") in the same attribute.
- **You can't build class names dynamically at runtime.** Tailwind's build step scans your source
  files for *literal* class-name strings — it doesn't execute your JavaScript. So this **does not
  work**:
  ```tsx
  const color = "red";
  <div className={`text-${color}-500`} /> // Tailwind never sees "text-red-500" as a literal string — this class won't be generated
  ```
  You have to spell out full class names somewhere Tailwind's scanner can see them, e.g. a ternary
  or lookup map (`color === "red" ? "text-red-500" : "text-blue-500"`). This trips up nearly every
  beginner at least once.
- **Harder to reuse across projects without a component layer.** A plain CSS class like
  `.btn-primary` can be dropped into any HTML page. A pile of Tailwind utility classes isn't
  "reusable" the same way unless you wrap it in an actual component (section 9) — which is usually
  the right answer in a React app, but is an extra step vanilla CSS doesn't require.
- **The fixed scale can fight a pixel-precise design.** If you're handed a Figma spec that says
  "13px padding," Tailwind's scale doesn't have a `p-3.25`. You either round to the nearest step
  (`p-3` = 12px) or reach for an arbitrary value (`p-[13px]`, section 8) — which, if overused,
  erodes the consistency benefit that was the whole point.
- **Diffs get noisier.** Changing one visual property (say, a border color) means editing a
  `className` string; in a `git diff`, that can show as a full-line change even for a one-word
  edit, which is a slightly worse review experience than a one-line CSS change.
- **It's a build-time tool, not just a stylesheet.** Production use (like this project) requires
  the PostCSS scanning step (`postcss.config.mjs`) to work — you can't just drop a `.css` file onto
  a static page the way you could with hand-written CSS. (Tailwind does offer a browser/CDN build
  for quick prototypes without a build step, but that's not what real apps ship with.)

None of this means "don't use Tailwind" — the tradeoffs in section 1 are real too, and for a
React/Next.js project like this one, Tailwind is a very reasonable default. The point is knowing
what you're trading, not treating it as strictly free.

## 11. Quick reference cheat sheet

The values Tailwind developers actually keep coming back to — worth glancing at instead of
memorizing. (Editor hover-tooltips from section 3 give you this same info live, in context.)

**Spacing scale** (`p-`, `m-`, `gap-`, `w-`, `h-`, `space-x-`/`space-y-`, `top-`/`left-`/etc. — each
step = `0.25rem`):

| Class suffix | rem | px |
|---|---|---|
| `0` | 0 | 0 |
| `px` | — | 1px (literal) |
| `1` | 0.25rem | 4px |
| `2` | 0.5rem | 8px |
| `3` | 0.75rem | 12px |
| `4` | 1rem | 16px |
| `5` | 1.25rem | 20px |
| `6` | 1.5rem | 24px |
| `8` | 2rem | 32px |
| `10` | 2.5rem | 40px |
| `12` | 3rem | 48px |
| `16` | 4rem | 64px |
| `20` | 5rem | 80px |
| `24` | 6rem | 96px |

(Full scale goes up to `96`; half-steps like `1.5`, `2.5`, `3.5` also exist below `4`.)

**Font size** (`text-`):

| Class | rem | px |
|---|---|---|
| `xs` | 0.75rem | 12px |
| `sm` | 0.875rem | 14px |
| `base` | 1rem | 16px (default body size) |
| `lg` | 1.125rem | 18px |
| `xl` | 1.25rem | 20px |
| `2xl` | 1.5rem | 24px |
| `3xl` | 1.875rem | 30px |
| `4xl` | 2.25rem | 36px |
| `5xl` | 3rem | 48px |

**Font weight** (`font-`): `thin`(100) `extralight`(200) `light`(300) `normal`(400) `medium`(500)
`semibold`(600) `bold`(700) `extrabold`(800) `black`(900)

**Border width** (`border-`): default `border` = 1px, then `border-0`, `border-2`, `border-4`,
`border-8` (this project uses `border-2` everywhere for its wireframe look)

**Border radius** (`rounded-`): `none`(0) `sm`(0.125rem) `rounded`(0.25rem, the unsuffixed
default) `md`(0.375rem) `lg`(0.5rem) `xl`(0.75rem) `2xl`(1rem) `3xl`(1.5rem) `full`(9999px, a pill/
circle). This project uses none of these — square corners everywhere, on purpose, for the
wireframe look.

**Breakpoints** (responsive prefixes, section 7): `sm` 640px · `md` 768px · `lg` 1024px ·
`xl` 1280px · `2xl` 1536px

**Color shades:** Tailwind's built-in color families (`neutral`, `red`, `blue`, etc. — not
currently used in this project, see section 5) run `50` (lightest) → `950` (darkest) in steps of
100, e.g. `neutral-50`, `neutral-100`, ... `neutral-900`, `neutral-950`.

## 12. Reading this project's Tailwind setup end-to-end

- `postcss.config.mjs` — wires the Tailwind PostCSS plugin into the build so `@import
  "tailwindcss";` in `globals.css` gets expanded.
- `src/app/globals.css` — the one and only place colors/fonts are defined (`@theme inline`), plus
  the `@import "tailwindcss";` that pulls in all the utility classes.
- `src/app/layout.tsx` — loads the Geist fonts and wires their CSS variables
  (`--font-geist-sans`) into `@theme`'s `--font-sans`, which is why `font-sans` (the default body
  font) resolves to Geist across the app without any per-page font class.
- No `tailwind.config.js` — this is Tailwind v4's CSS-first config; everything that used to live
  in that JS file now lives in `@theme` blocks in CSS.

## 13. Suggested practice, in this repo

1. Open `src/app/page.tsx`, change `gap-3` to `gap-1` and `gap-6`, reload, and watch spacing
   change — build a feel for the spacing scale from section 11.
2. Install the "Tailwind CSS IntelliSense" VS Code extension (section 3) and hover over a few
   classes in `src/app/days/[id]/page.tsx` to see the compiled CSS pop up.
3. Pick a new accent detail — e.g. make the header border `border-b-4` instead of `border-b-2` —
   and decide if it still reads as "wireframe" to you at that weight.
4. Try breaking the off-white background on purpose: change `--background` in `globals.css` to
   `#ffffff` and reload every page, to see concretely why the softer `#faf8f4` was chosen (compare
   against how the pure-white version feels — that's the Apple Notes-style off-white reasoning in
   practice).
5. Once you're comfortable, try extracting the repeated button/card classes from section 9 into a
   small shared component — this is the natural "next skill" once utility classes start repeating.
