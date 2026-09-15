import subprocess
import os

def run_cmd(cmd):
    return subprocess.check_output(cmd, shell=True).decode('utf-8').strip()

# Stage all changes to get a comprehensive list of all modified/new/deleted files
run_cmd('git add -A')

# Get the list of files
files_output = run_cmd('git diff --cached --name-only')
files = [f for f in files_output.split('\n') if f.strip()]

# Unstage everything
run_cmd('git reset')

for f in files:
    # Add just this file
    run_cmd(f'git add "{f}"')
    
    # Get base name for commit message
    basename = os.path.basename(f)
    
    # Check if it was deleted
    status = run_cmd(f'git status --short "{f}"')
    
    if status.startswith('D') or status.startswith(' D'):
        msg = f"Delete {basename}"
    elif status.startswith('A') or status.startswith(' A') or status.startswith('??'):
        msg = f"Add {basename}"
    else:
        msg = f"Update {basename}"
        
    print(f"Committing {f} with message: {msg}")
    run_cmd(f'git commit -m "{msg}"')

print("Pushing to remote...")
try:
    run_cmd('git push')
    print("Push successful.")
except Exception as e:
    print(f"Push failed: {e}")
