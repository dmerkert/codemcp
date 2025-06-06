# Contributing

Here's the deal: I don't want to review big, LLM generated patches to this codebase.
I haven't reviewed most of the code that I've generated; most of my confidence
arises from careful prompt writing and manual testing.

So if you want to contribute a patch, here's what I'll accept:

1. A small patch that I can easily review it by hand, or

1. A *prompt* you used to generate the output by LLM, and evidence that you manually
   tested the result and it worked.

You can feel free to submit the code that the LLM generated too but for safety
reasons I will regenerate the diff from your prompt myself.  I also don't
trust LLM generated tests, so either argue why the LLM tests are sufficient or
tell me what your manual testing protocol was.  I'm willing to hand-review
hand-written tests, keep them separate so I can easily patch them in.  If you
needed to blend prompting + final touchups, keep them in separate commits and
we'll figure something out.

If you're looking for backlog to tackle since you want to practice AI coding,
check out https://github.com/ezyang/codemcp/issues

## Local development tips

Instead of using uvx directly, I have a uv venv setup in my source directory
and connect using:

```
    "codemcp": {
      "command": "/Users/ezyang/Dev/codemcp-prod/.venv/bin/python",
      "args": [
        "-m",
        "codemcp"
      ]
    }
```

I recommend using `git worktree` to keep a separate "prod" folder from the
folder you're actually editing with Claude.  You can then `git checkout --detach main` in the prod folder to checkout your latest changes and manually
test them.

## Type Checking

This project uses `pyright` for type checking with strict mode enabled. The type checking configuration is in `pyproject.toml`. We use a few strategies to maintain type safety:

1. Type stubs for external libraries:
   - Custom type stubs are in the `stubs/` directory
   - The `stubPackages` configuration in `pyproject.toml` maps libraries to their stub packages

2. File-specific ignores for challenging cases:
   - For some files with complex dynamic typing patterns (particularly testing code), we use file-specific ignores via `tool.pyright.ignoreExtraErrors` in `pyproject.toml`
   - This is preferable to inline ignores and lets us maintain type safety in most of the codebase

When making changes, please ensure type checking passes by running:
```
./run_typecheck.sh
```
