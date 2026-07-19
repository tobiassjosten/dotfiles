---
name: flesh
description: Flesh out a draft file into publication-ready prose, respecting any local editorial guidance.
disable-model-invocation: true
---

# Flesh

Expand a draft, outline, or sketch into finished prose that reads like a human professional wrote it.

## Input

The user invokes this skill with a filename as the argument: `/flesh path/to/draft.md`.

If no filename was provided, ask for one and stop.

## Workflow

1. **Read the target file** in full. Note what's already there: the structure, the points the author is making, the voice they've started in, anything marked TODO or in brackets.

2. **Find editorial guidance.** In order:
   a. `CLAUDE.md` in the same directory as the target file.
   b. `CLAUDE.md` in any parent directory up to the repo/working root.
   c. A `STYLE.md`, `VOICE.md`, `EDITORIAL.md`, or similarly named doc near the target.
   d. A frontmatter `style:` or `voice:` field in the target file itself.

   Read every relevant doc. Any instructions found there — on tone, voice, vocabulary, structure, audience, things to avoid — **override** the defaults below. When in doubt about conflicts, local and more specific wins.

3. **If no editorial guidance exists**, apply the defaults in *Default Voice* below.

4. **Flesh out the content.** Preserve every point the author made; expand each one with the specificity, transitions, and pacing it needs to stand as finished writing. Do not invent claims, statistics, quotes, or examples the author didn't include — if a section needs evidence and none is provided, leave a bracketed `[example needed: ...]` placeholder rather than fabricating.

5. **Write the result back** to the same file using the Edit or Write tool. Do not create a new file unless the target file's frontmatter or a nearby doc asks you to.

6. **Summarize in one or two sentences** what you changed: which sections you expanded, anything you flagged with a placeholder, anything you deliberately left alone.

## Default Voice

Apply these only when no local editorial guidance exists. They describe writing that sounds like a competent human professional — not a polished AI draft.

**Cadence**
- Vary sentence length. A four-word sentence next to a twenty-eight-word one creates rhythm; uniform medium-length sentences read as machine-flat.
- Start sentences differently. Don't begin three in a row with the subject, or three in a row with a transitional adverb.

**Specificity over generality**
- Prefer the concrete noun and verb over the abstract one. "The auth library logs every token to stderr" beats "There are observability concerns with the auth library."
- If the author named an example, use that example. If they didn't, and one is genuinely needed, leave a `[example needed: ...]` placeholder.

**Point of view**
- The author is making an argument or telling a story. Keep that spine visible. Don't hedge it into mush ("there are many perspectives", "it depends", "some might say") unless the hedge is the point.
- It's fine — often necessary — to be opinionated. Professional writers commit.

**Things to avoid**
- AI-tell vocabulary: *delve, navigate, tapestry, landscape, realm, journey, unleash, leverage* (as a verb), *robust, seamless, vibrant, intricate, crucial, vital, paramount, holistic, multifaceted*. Cut or replace.
- AI-tell constructions: "It's not just X, it's Y." "In today's fast-paced world." "Whether you're a beginner or an expert." "Let's dive in." "In conclusion." "It's important to note that." Cut.
- Hollow openers and closers. Don't start a section by telling the reader what the section is about; just write it. Don't end with a summary of what you just said.
- Reflexive tricolons. Three-item lists feel natural in moderation; when every paragraph has one, the rhythm becomes audible.
- Bulleted lists for things that are actually prose. Lists earn their keep when items are genuinely parallel and discrete. Otherwise write sentences.
- Throat-clearing transitions: "Moreover", "Furthermore", "Additionally", "That said" (used as filler). Strong writing transitions through content, not connector words.
- Sycophancy and self-congratulation. No "This is a great point" or "What an interesting question" framings.

**What to preserve**
- Any voice already present in the draft. If the author writes short, punchy sentences, don't smooth them into long ones. If they're funny, stay funny.
- Idiosyncratic word choices, jargon the audience expects, and the author's structural choices unless they're broken.
- Anything in quotes, code blocks, or marked as a citation — verbatim.

**Length**
- Flesh out enough to make each point land. Don't pad to hit a word count. A finished paragraph that's two sentences long is finished.

## Rules

- Never invent facts, sources, quotes, statistics, or named examples.
- Never strip out the author's points, even ones you'd argue with — expanding is the job, editing the argument is not.
- If editorial guidance contradicts the defaults above, follow the guidance and ignore the conflicting default. Note in the summary which doc you followed.
- If the file is empty or contains only a title, ask the user for the points they want fleshed out before writing anything.
