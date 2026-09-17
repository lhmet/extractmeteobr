# Documentation mechanics

Read for generation, validation, or Python style. Adapted from official sources;
researched 2026-09-17. Scientific requirements remain in `AGENTS.md`.

Roxygen blocks precede objects; the introduction supplies title/description. Put
method/assumptions in details, document actual parameters/returns, and provide
executable examples. Preserve `Roxygen: list(markdown = TRUE)`. Use Rd
`\eqn{}`/`\deqn{}` for equations; Markdown math delimiters may not generate valid Rd.
Define all scientific symbols.

For authorized regeneration from the root after checking versions:

```sh
Rscript -e 'roxygen2::roxygenize(".")'
```

This may update help, namespace, and version metadata. Inspect generated changes.
Do not silently install/upgrade roxygen2. If blocked, report source edits and the
remaining generation step accurately.

Parse affected R with `parse(file = ...)`; parse help with `tools::parse_Rd()` and
check with `tools::checkRd()`. This does not replace small example execution or
a package check when warranted. Inspect README chunks before costly rendering.

For Python, preserve existing style. NumPy uses Parameters, Returns, Raises, Notes,
and Examples; Google uses Args, Returns, Raises, and Examples with consistent
indentation. Include relevant sections only. Do not invent exceptions or mechanically
duplicate annotations; explain shapes, axes, units, and side effects.

Sources:

- [roxygen2 functions](https://roxygen2.r-lib.org/articles/rd.html)
- [roxygen2 Markdown/Rd](https://roxygen2.r-lib.org/articles/rd-formatting.html)
- [NumPy docstrings](https://numpydoc.readthedocs.io/en/latest/format.html)
- [Google docstrings](https://google.github.io/styleguide/pyguide.html#38-comments-and-docstrings)
