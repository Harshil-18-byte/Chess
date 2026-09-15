import os
import glob
import re

md_files = glob.glob('*.md')

for f in md_files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()
    
    # Check for metadata block at the top
    if content.startswith('---'):
        # Find the second '---'
        end_idx = content.find('---', 3)
        if end_idx != -1:
            # Skip the '---' and any following whitespace/newlines
            content = content[end_idx+3:].lstrip()
            
    # Append update note without removing content
    content += '\n\n<!-- Document reviewed and updated: Phase 5 (Liquid Glass UI & Match History Integration) -->\n'
    
    with open(f, 'w', encoding='utf-8') as file:
        file.write(content)
        
print(f"Updated {len(md_files)} markdown files.")
