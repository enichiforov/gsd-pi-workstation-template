# Process Execution

## Resolve the command

On POSIX, an argv list goes directly to the child program; a bare executable name is searched via
PATH. A shell is a separate program with its own parsing, builtins, expansion, pipelines, and
redirection. `cd` is normally a shell builtin because a child cannot change its parent's cwd.

Windows command-line parsing and executable search differ. Batch files can involve system shell
parsing. Verify platform behavior from current Python documentation.

## Safe default

When output need not be retained in memory, inherit or redirect it:

```python
completed = subprocess.run(
    ["convert", source, target],
    cwd=work_dir,
    env=child_env,
    stdout=subprocess.DEVNULL,
    stderr=log_file,
    timeout=30,
    check=True,
)
```

`capture_output=True` buffers both streams in memory; a timeout limits elapsed time, not captured
bytes. Use it only when the child contract guarantees small output. For untrusted or noisy output,
inherit streams, use `DEVNULL`, redirect to storage with an external size/rotation limit, or
implement a capped stream reader that kills the child when the cap is crossed.

`env=child_env` replaces the inherited environment. Build the complete intended mapping
deliberately, for example from a sanitized allowlist or `os.environ | overrides`; do not assume
unspecified variables survive.

Use `shell=True` only when intentionally using shell syntax such as a pipeline or redirection and
all interpolated data is safely quoted for that exact shell. Prefer implementing pipelines through
multiple `Popen` calls or library APIs.

## Failure diagnosis

Record without secrets:

- effective executable and argv;
- cwd and relevant PATH entries;
- interpreter and `sys.executable`;
- exit status or signal;
- bounded stdout/stderr;
- timeout/cancellation;
- inherited versus explicit environment;
- platform and launcher.

Use `shutil.which` for diagnostic resolution, not as a substitute for explicit deployment
configuration.

Primary reference:
https://docs.python.org/3/library/subprocess.html
