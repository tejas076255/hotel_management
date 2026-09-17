import Link from "next/link";

export default function UnauthorizedPage() {
  return (
    <div className="min-h-screen flex items-center justify-center p-6">
      <div className="text-center max-w-sm">
        <div className="text-5xl mb-4">🔒</div>
        <h1 className="text-xl font-bold text-[var(--text-primary)] mb-2">Access Denied</h1>
        <p className="text-sm text-[var(--text-muted)] mb-6">
          You do not have permission to access this page. Please contact an Admin to request access.
        </p>
        <Link
          href="/pms"
          className="inline-flex items-center gap-2 bg-indigo-600 text-white text-sm font-medium px-4 py-2 rounded-lg hover:bg-indigo-700 transition-colors"
        >
          Back to Dashboard
        </Link>
      </div>
    </div>
  );
}
