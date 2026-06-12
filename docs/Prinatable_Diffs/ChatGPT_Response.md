The best paper format is usually a **unified diff / patch**, printed in a monospaced font with generous context.

Avoid pure side-by-side diffs for manual updates unless the file has very short lines. Side-by-side diffs look nice on screen, but on paper they wrap badly and make copying mistakes more likely.

Use this style:

```diff
@@ -42,7 +42,9 @@ def process_file(path):
     data = read_file(path)
-    timeout = 10
+    timeout = 30
+    retry_count = 3
+
     result = send_data(data, timeout)
     return result
```

Where:

```text
- removed line from old version
+ added line in new version
  unchanged context line
@@ old/new line-number range
```

## Best practical workflow

Generate a patch file like this:

```bash
diff -u -U 8 old_script.py new_script.py > script_update.diff
```

Or, if you have Git available:

```bash
git diff --no-index --patience --unified=8 old_script.py new_script.py > script_update.diff
```

Then print `script_update.diff`.

I would use **8 lines of context** rather than the default 3. Since you are applying it manually, extra surrounding lines help you find the correct spot in the old script and reduce the chance of editing the wrong repeated block.

## Recommended print settings

Use:

```text
Font:        Consolas, Courier New, DejaVu Sans Mono, or other monospaced font
Size:        9–11 pt
Orientation: Portrait for unified diff, Landscape for side-by-side only
Tabs:        Expanded to spaces
Line wrap:   Off if possible, or clearly wrapped with indentation
Color:       Useful, but do not rely on color only
Margins:     Narrow
```

If your editor supports it, turn on:

```text
Line numbers
Syntax highlighting
Visible whitespace, if tabs/spaces matter
```

But for the actual diff, the `+` and `-` markers matter more than syntax highlighting.

## Best version to print

Print **two things**, in this order:

1. **The unified diff**
2. **The full new script with line numbers**

The diff is what you use to make the changes. The full new script is your backup reference when a hunk is confusing or when a change is large enough that rewriting a section is safer.

## Example command set

```bash
diff -u -U 8 old_script.py new_script.py > script_update.diff
nl -ba new_script.py > new_script_numbered.txt
```

Then print:

```text
script_update.diff
new_script_numbered.txt
```

`nl -ba` numbers every line, including blank lines, which is helpful when checking that the final file structure matches.

## If you can use an editor instead

Good options are:

```text
VS Code compare editor → print/save as PDF
Notepad++ Compare plugin → print
Beyond Compare → print report
WinMerge → generate report / print
Meld → print/save where available
```

For your use case, I would still prefer exporting a **unified diff** rather than printing a visual side-by-side comparison.

## My recommendation

Use this as your standard format:

```bash
git diff --no-index --patience --unified=8 old_script.py new_script.py > script_update.diff
nl -ba new_script.py > new_script_numbered.txt
```

Print both files in a monospaced font. Use the diff as the work instruction and the numbered full script as the verification reference.
