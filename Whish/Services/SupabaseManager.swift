import Foundation
import Supabase

// MARK: - Configuration
//
// 1. Go to https://supabase.com/dashboard → your project → Settings → API
// 2. Copy "Project URL" and "anon public" key
// 3. Replace the placeholder strings below
//
// ⚠️  Never commit real credentials.
//     Consider using Xcode build settings / xcconfig for production.

enum SupabaseConfig {
    static let projectURL = URL(string: "https://dyporggvmfyzejopaezc.supabase.co")!
    static let anonKey    = "sb_publishable_gSe6-TBAca02aJ4thj_-pw_HUSwW7oY"
}

// MARK: - Client singleton

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.projectURL,
    supabaseKey: SupabaseConfig.anonKey,
    options: .init(
        auth: .init(
            emitLocalSessionAsInitialSession: true
        )
    )
)
