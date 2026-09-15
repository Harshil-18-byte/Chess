import os
import re

files_to_fix = [
    r'j:\Dev\PROJECTS\Chess\lib\views\dashboard\home_screen.dart',
    r'j:\Dev\PROJECTS\Chess\lib\views\dashboard\profile_screen.dart',
    r'j:\Dev\PROJECTS\Chess\lib\views\dashboard\match_setup_screen.dart',
    r'j:\Dev\PROJECTS\Chess\lib\views\history\history_screen.dart',
    r'j:\Dev\PROJECTS\Chess\lib\views\history\match_history_list_screen.dart',
    r'j:\Dev\PROJECTS\Chess\lib\views\settings\settings_screen.dart'
]

for p in files_to_fix:
    if not os.path.exists(p): continue
    with open(p, 'r', encoding='utf-8') as f:
        content = f.read()

    # Replace relative paths going up one level with going up two levels for core/models/etc.
    content = re.sub(r"import\s+['\"]\.\./(core|models|state|services|utils)/", r"import '../../\1/", content)

    # Widgets were in same dir, now they are in parent/widgets
    content = re.sub(r"import\s+['\"]widgets/", r"import '../widgets/", content)
    
    # credits_screen was in same dir, now parent
    content = re.sub(r"import\s+['\"]credits_screen\.dart['\"];", r"import '../credits_screen.dart';", content)
    
    with open(p, 'w', encoding='utf-8') as f:
        f.write(content)
    print(f'Fixed {p}')
