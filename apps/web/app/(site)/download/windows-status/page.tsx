import { format, parseISO } from "date-fns";
import type { Metadata } from "next";
import Link from "next/link";
import {
	getGitHubReleases,
	getWindowsStoreDownloadUrl,
	hasVerifiedWindowsEvidence,
	type Release,
} from "@/utils/releases";

export const metadata: Metadata = {
	title: "Windows Download Status - Cap",
	description: "Windows download verification status for Cap.",
};

export const revalidate = 3600;

function WindowsIcon() {
	return (
		<svg className="w-4 h-4" viewBox="0 0 24 24" fill="currentColor">
			<path d="M0,0H11.377V11.372H0ZM12.623,0H24V11.372H12.623ZM0,12.623H11.377V24H0Zm12.623,0H24V24H12.623" />
		</svg>
	);
}

function isVerifiedWindowsRelease(release: Release) {
	return (
		hasVerifiedWindowsEvidence(release) &&
		!!(release.downloads.windows || release.downloads["windows-msi"])
	);
}

export default async function WindowsDownloadStatusPage() {
	const storeUrl = getWindowsStoreDownloadUrl();
	let latestRelease: Release | null = null;
	let verifiedRelease: Release | null = null;
	let error: string | null = null;

	try {
		const releases = await getGitHubReleases();
		latestRelease = releases[0] ?? null;
		verifiedRelease = releases.find(isVerifiedWindowsRelease) ?? null;
	} catch (e) {
		error =
			e instanceof Error ? e.message : "Unable to check Windows release status";
	}

	return (
		<div className="py-24 md:py-32 wrapper wrapper-sm">
			<div className="space-y-8">
				<div className="space-y-3">
					<Link
						href="/download"
						className="inline-flex items-center gap-1 text-sm text-gray-10 hover:text-gray-12"
					>
						<svg
							className="w-4 h-4"
							viewBox="0 0 24 24"
							fill="none"
							stroke="currentColor"
							strokeWidth="2"
						>
							<path d="M19 12H5M12 19l-7-7 7-7" />
						</svg>
						Back to Download
					</Link>
					<div className="flex items-center gap-3">
						<div className="inline-flex justify-center items-center w-9 h-9 rounded-md bg-gray-3 text-gray-12">
							<WindowsIcon />
						</div>
						<h1 className="text-2xl font-semibold text-gray-12 md:text-3xl">
							Windows download status
						</h1>
					</div>
				</div>

				{storeUrl ? (
					<div className="space-y-4">
						<p className="text-gray-10">
							The recommended Windows download is available from Microsoft
							Store.
						</p>
						<a
							href={storeUrl}
							className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700 transition-colors"
						>
							<WindowsIcon />
							Open Microsoft Store
						</a>
					</div>
				) : verifiedRelease ? (
					<div className="space-y-4">
						<p className="text-gray-10">
							{`The latest verified Windows installer is v${verifiedRelease.version}.`}
						</p>
						<div className="flex flex-wrap gap-2">
							{verifiedRelease.downloads.windows && (
								<a
									href="/download/windows-exe"
									className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-blue-600 text-white hover:bg-blue-700 transition-colors"
								>
									<WindowsIcon />
									Download EXE
								</a>
							)}
							{verifiedRelease.downloads["windows-msi"] && (
								<a
									href="/download/windows-msi"
									className="inline-flex items-center gap-1.5 px-4 py-2 text-sm font-medium rounded-md bg-gray-3 text-gray-12 hover:bg-gray-4 transition-colors"
								>
									<WindowsIcon />
									Download MSI
								</a>
							)}
						</div>
					</div>
				) : (
					<div className="space-y-4">
						<p className="text-gray-10">
							Windows installers are waiting for signing and release
							verification before direct download is enabled.
						</p>
						{latestRelease && (
							<div className="text-sm text-gray-9">
								Latest public release: v{latestRelease.version}, published{" "}
								{format(parseISO(latestRelease.publishedAt), "MMMM d, yyyy")}.
							</div>
						)}
						{error && (
							<div className="text-sm text-red-11">
								Windows verification status is temporarily unavailable.
							</div>
						)}
					</div>
				)}

				<div className="grid gap-3 md:grid-cols-2">
					<div className="p-4 rounded-lg border border-gray-5 bg-gray-1">
						<div className="text-sm font-medium text-gray-12">Required</div>
						<div className="mt-1 text-sm text-gray-10">
							Checksum, Authenticode audit, installer smoke test, WinGet
							manifest, and WDSI review material.
						</div>
					</div>
					<div className="p-4 rounded-lg border border-gray-5 bg-gray-1">
						<div className="text-sm font-medium text-gray-12">Next step</div>
						<div className="mt-1 text-sm text-gray-10">
							Publish through Microsoft Store or create a signed Windows
							Release.
						</div>
					</div>
				</div>

				<div className="flex flex-wrap gap-3 text-sm">
					<Link
						href="/download/versions"
						className="text-gray-10 hover:text-gray-12 hover:underline"
					>
						All versions
					</Link>
					<a
						href="https://github.com/Lkkisme/Cap/blob/main/docs/windows-smartscreen.md"
						className="text-gray-10 hover:text-gray-12 hover:underline"
					>
						Windows trust plan
					</a>
				</div>
			</div>
		</div>
	);
}
