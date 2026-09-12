import subprocess
import os
import sys

# Mapping of specific file patterns to human-readable commit messages without conventional commit prefixes
def get_commit_message(filepath):
    normalized = filepath.replace('\\', '/')
    
    # Root configs & docs
    if normalized == '.gitignore':
        return "Configure version control ignore patterns"
    if normalized == '.mcp.json' or normalized == '.vscode/mcp.json':
        return "Configure model context protocol integration"
    if normalized == '.metadata':
        return "Add Flutter project metadata"
    if normalized == 'README.md':
        return "Update application overview and architecture guide"
    if normalized == 'ARCHITECTURE.md':
        return "Add system architecture and data mutation specification"
    if normalized == 'CHANGELOG.md':
        return "Add version history and changelog tracking"
    if normalized == 'CREDITS.md':
        return "Add credits and open source license acknowledgements"
    if normalized == 'FIREBASE_SECURITY_RULES.md':
        return "Add production Firestore security rules documentation"
    if normalized == 'SECURITY.md':
        return "Add security threat model and anti-cheat documentation"
    if normalized == 'analysis_options.yaml':
        return "Configure static analysis and linter rules"
    if normalized == 'firebase.json':
        return "Configure Firebase CLI and emulator settings"
    if normalized == 'firestore.indexes.json':
        return "Define Firestore composite indexes"
    if normalized == 'firestore.rules':
        return "Implement production Firestore security rules"
    if normalized == 'pubspec.yaml':
        return "Declare Flutter dependencies and asset assets"
    if normalized == 'pubspec.lock':
        return "Pin exact package dependency versions"
        
    # Assets
    if normalized == 'assets/images/logo.png':
        return "Add Chessical obsidian and magma application logo"
    if normalized == 'assets/models/pieces/classic/manifest.json':
        return "Add classic 3D piece model asset manifest"
        
    # Core
    if normalized == 'lib/core/constants/chess_constants.dart':
        return "Define game constants Elo parameters and time controls"
    if normalized == 'lib/core/errors/app_exceptions.dart':
        return "Implement typed application exception hierarchy"
    if normalized == 'lib/core/rules/chess_rules_evaluator.dart':
        return "Implement chess engine rules and insufficient material evaluator"
    if normalized == 'lib/core/theme/board_themes.dart':
        return "Define obsidian magma and classic board theme tokens"
        
    # Models
    if normalized == 'lib/models/chess_match.dart':
        return "Implement immutable chess match state model"
    if normalized == 'lib/models/chess_move.dart':
        return "Implement chess move audit record model"
    if normalized == 'lib/models/user_profile.dart':
        return "Implement user profile and player statistics model"
        
    # Services
    if normalized == 'lib/services/firebase_auth_service.dart':
        return "Implement Firebase authentication and App Check service"
    if normalized == 'lib/services/firestore_service.dart':
        return "Implement atomic Firestore transactions and matchmaking service"
    if normalized == 'lib/services/stockfish_service.dart':
        return "Implement background isolate Stockfish FFI engine service"
        
    # State
    if normalized == 'lib/state/game_state_notifier.dart':
        return "Implement Riverpod game state notifier with move idempotency"
        
    # Views - 3D Board
    if normalized == 'lib/views/game_board/board_3d/board_3d_view.dart':
        return "Implement custom painter 3D chess viewport with gesture controls"
    if normalized == 'lib/views/game_board/board_3d/chess_scene_controller.dart':
        return "Implement camera orbit pitch yaw and zoom controller"
    if normalized == 'lib/views/game_board/board_3d/move_animation_controller.dart':
        return "Implement tweened parabolic move and capture animations"
    if normalized == 'lib/views/game_board/board_3d/piece_model_loader.dart':
        return "Implement procedural 3D lathe mesh piece loader and cache"
    if normalized == 'lib/views/game_board/board_3d/square_raycaster.dart':
        return "Implement screen to 3D square raycasting hit test mathematics"
        
    # Views - 2D & Main
    if normalized == 'lib/views/game_board/game_board_view.dart':
        return "Implement main game board canvas supporting 2D and 3D rendering modes"
    if normalized == 'lib/views/game_board/widgets/board_square.dart':
        return "Implement 2D chess board square widget with drag target"
    if normalized == 'lib/views/game_board/widgets/chess_piece.dart':
        return "Implement draggable chess piece widget with asset icons"
    if normalized == 'lib/views/game_board/widgets/game_clock.dart':
        return "Implement reactive game clock widget with server timestamp sync"
    if normalized == 'lib/views/history_screen.dart':
        return "Implement completed match history and move replay screen"
    if normalized == 'lib/views/home_screen.dart':
        return "Implement lobby home screen with matchmaking and game mode selector"
    if normalized == 'lib/main.dart':
        return "Implement application entry point and theme configuration"
        
    # Tests
    if normalized == 'test/chess_rules_test.dart':
        return "Add comprehensive unit tests for rules engine and insufficient material"
    if normalized == 'test/e2e_match_simulation_test.dart':
        return "Add end-to-end match checkmate and 3D raycasting simulation tests"
    if normalized == 'test/game_state_notifier_test.dart':
        return "Add unit tests for Riverpod game state notifier and idempotency"
    if normalized == 'test/widget_test.dart':
        return "Add application boot and lobby widget tests"
        
    # Cloud Functions
    if normalized == 'functions/package.json':
        return "Configure Cloud Functions Node dependencies"
    if normalized == 'functions/tsconfig.json':
        return "Configure Cloud Functions TypeScript compiler settings"
    if normalized == 'functions/src/index.ts':
        return "Initialize Firebase Admin and export Cloud Functions endpoints"
    if normalized == 'functions/src/inputSchemaGuard.ts':
        return "Implement payload schema validator and UUID verification guard"
    if normalized == 'functions/src/rateLimiter.ts':
        return "Implement token bucket rate limiter for move submissions"
    if normalized == 'functions/src/validateMove.ts':
        return "Implement authoritative server side move validation Cloud Function"
    if normalized == 'functions/src/enforceTimeout.ts':
        return "Implement server side timeout enforcement and scheduled sweeper"
        
    # Android Platform Files
    if normalized.startswith('android/'):
        filename = os.path.basename(normalized)
        return f"Add Android configuration file {filename}"
        
    # iOS Platform Files
    if normalized.startswith('ios/'):
        filename = os.path.basename(normalized)
        return f"Add iOS platform configuration file {filename}"
        
    # Web Platform Files
    if normalized.startswith('web/'):
        filename = os.path.basename(normalized)
        return f"Add web platform asset {filename}"
        
    # Windows Platform Files
    if normalized.startswith('windows/'):
        filename = os.path.basename(normalized)
        return f"Add Windows desktop build configuration {filename}"
        
    filename = os.path.basename(normalized)
    return f"Add {filename}"

def main():
    # Get all status items
    output = subprocess.check_output(['git', 'status', '-s', '-uall'], text=True)
    lines = [line.strip() for line in output.strip().split('\n') if line.strip()]
    
    print(f"Found {len(lines)} files to commit.")
    
    committed_count = 0
    for line in lines:
        parts = line.split(maxsplit=1)
        if len(parts) < 2:
            continue
        status_code = parts[0]
        filepath = parts[1].strip('"')
        
        # Staging single file
        subprocess.check_call(['git', 'add', filepath])
        
        msg = get_commit_message(filepath)
        print(f"[{committed_count+1}/{len(lines)}] Committing: {filepath} -> \"{msg}\"")
        subprocess.check_call(['git', 'commit', '-m', msg])
        committed_count += 1
        
    print(f"Successfully created {committed_count} individual commits.")

if __name__ == '__main__':
    main()
