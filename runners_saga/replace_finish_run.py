#!/usr/bin/env python3

# Read the original file
with open('lib/features/run/screens/run_screen.dart', 'r') as f:
    content = f.read()

# Read the new finish run method
with open('temp_finish_run.dart', 'r') as f:
    new_finish_run = f.read()

# Find the start and end of the _finishRun method
start_marker = "  void _finishRun() async {"
end_marker = "  }"

# Find the start position
start_pos = content.find(start_marker)
if start_pos == -1:
    print("Error: Could not find start of _finishRun method")
    exit(1)

# Find the end position (look for the closing brace that matches the method)
brace_count = 0
pos = start_pos
while pos < len(content):
    if content[pos] == '{':
        brace_count += 1
    elif content[pos] == '}':
        brace_count -= 1
        if brace_count == 0:
            end_pos = pos + 1
            break
    pos += 1
else:
    print("Error: Could not find end of _finishRun method")
    exit(1)

# Replace the method
new_content = content[:start_pos] + new_finish_run + content[end_pos:]

# Write the new file
with open('lib/features/run/screens/run_screen.dart', 'w') as f:
    f.write(new_content)

print("Successfully replaced _finishRun method")











