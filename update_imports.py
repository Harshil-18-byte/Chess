import os
import re

cwd = r'j:\Dev\PROJECTS\Chess\lib'

replacements = [
    (r"import\s+['\"].*?home_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/dashboard/home_screen.dart';"),
    (r"import\s+['\"].*?profile_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/dashboard/profile_screen.dart';"),
    (r"import\s+['\"].*?match_setup_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/dashboard/match_setup_screen.dart';"),
    (r"import\s+['\"].*?history_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/history/history_screen.dart';"),
    (r"import\s+['\"].*?match_history_list_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/history/match_history_list_screen.dart';"),
    (r"import\s+['\"].*?settings_screen\.dart['\"];?", r"import 'package:enterprise_chess/views/settings/settings_screen.dart';")
]

for root, _, files in os.walk(cwd):
    for f in files:
        if not f.endswith('.dart'): continue
        p = os.path.join(root, f)
        with open(p, 'r', encoding='utf-8') as file:
            content = file.read()
            
        new_content = content
        for pattern, replacement in replacements:
            new_content = re.sub(pattern, replacement, new_content)
            
        if new_content != content:
            with open(p, 'w', encoding='utf-8') as file:
                file.write(new_content)
            print(f'Updated {p}')
