# Printing Code Diffs for Manual Updates

Use a unified diff as the main work instruction, then print the full new script with line numbers as a backup reference.

Side-by-side diffs are usually harder to use on paper because long lines wrap poorly.

## What to Print

Print these two files:

1. `script_update.diff`
2. `new_script_numbered.txt`

Use the diff to make the edits. Use the numbered full script to verify confusing sections or large replacements.

## Step 1: Put Both Script Versions in One Folder

Save both files with clear names:

```text
old_script.py
new_script.py
```

The old file should match the version currently on the airgapped machine.

## Step 2: Generate the Diff

If Git is available, use:

```bash
git diff --no-index --patience --unified=8 old_script.py new_script.py > script_update.diff
```

If standard `diff` is available, use:

```bash
diff -u -U 8 old_script.py new_script.py > script_update.diff
```

The `--unified=8` or `-U 8` option includes eight unchanged lines around each change. This makes it easier to find the correct location when applying edits by hand.

## Step 3: Generate a Numbered Copy of the New Script

If `nl` is available, use:

```bash
nl -ba new_script.py > new_script_numbered.txt
```

If you are using PowerShell, use:

```powershell
$i = 0
Get-Content .\new_script.py | ForEach-Object {
    $i++
    "{0,5}: {1}" -f $i, $_
} > .\new_script_numbered.txt
```

Numbering every line, including blank lines, makes final verification easier.

## Step 4: Print the Files

Recommended print settings:

```text
Font:        Consolas, Courier New, DejaVu Sans Mono, or another monospaced font
Size:        9-11 pt
Orientation: Portrait
Margins:     Narrow
Line wrap:   Off if possible
Tabs:        Expanded to spaces
Color:       Helpful, but do not rely on it
```

If possible, also enable:

```text
Line numbers
Visible whitespace
Syntax highlighting
```

## Step 5: Read the Diff Markers

Example:

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

Diff markers:

```text
-  Remove this line from the old file
+  Add this line to the updated file
   Unchanged context line
@@ Line number information for the old and new files
```

When copying code into the actual script, do not copy the leading `+` or `-` markers.

## Step 6: Apply Each Change by Hand

For each diff hunk:

1. Find the matching unchanged context lines in the old script.
2. Remove every line marked with `-`.
3. Add every line marked with `+`.
4. Leave unchanged context lines as they are.
5. Check indentation, blank lines, quotes, and punctuation before moving to the next hunk.

If a hunk changes a large block, it may be safer to rewrite that whole block using `new_script_numbered.txt`.

## Step 7: Verify the Updated Script

After applying all changes:

1. Compare the edited script against `new_script_numbered.txt`.
2. Check that line order and blank lines match.
3. Check indentation-sensitive blocks carefully.
4. Run any available local syntax check or test command on the airgapped machine.

For Python, use:

```bash
python -m py_compile updated_script.py
```

## Recommended Standard Command Set

Use this whenever possible:

```bash
git diff --no-index --patience --unified=8 old_script.py new_script.py > script_update.diff
nl -ba new_script.py > new_script_numbered.txt
```

Then print:

```text
script_update.diff
new_script_numbered.txt
```
