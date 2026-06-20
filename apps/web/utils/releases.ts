export interface ReleaseDownloads {
	"macos-arm64"?: string;
	"macos-x64"?: string;
	windows?: string;
	"windows-msi"?: string;
}

export interface Release {
	version: string;
	tagName: string;
	publishedAt: string;
	body: string;
	htmlUrl: string;
	downloads: ReleaseDownloads;
	hasChecksums: boolean;
	hasWindowsAuditEvidence: boolean;
	hasWindowsSmokeTestEvidence: boolean;
	hasWindowsWingetEvidence: boolean;
	hasWindowsWdsiEvidence: boolean;
}

interface GitHubRelease {
	tag_name: string;
	name: string;
	published_at: string;
	body: string;
	html_url: string;
	draft: boolean;
	prerelease: boolean;
	assets: GitHubReleaseAsset[];
}

export interface GitHubReleaseAsset {
	name: string;
	browser_download_url: string;
}

interface WindowsReleaseAssetEvidence {
	File?: string;
	SignatureStatus?: string;
	TimestampStatus?: string;
	SignToolStatus?: string;
	ChecksumStatus?: string;
	AttestationStatus?: string;
	DefenderStatus?: string;
}

interface WindowsReleaseAssetManifest {
	Repository?: string;
	Tag?: string;
	Assets?: WindowsReleaseAssetEvidence[];
}

function parseDownloadsFromBody(body: string): ReleaseDownloads {
	const downloads: ReleaseDownloads = {};

	const jsonMatch = body.match(/<!--\s*DOWNLOADS_JSON\s*(\{[^}]+\})\s*-->/);

	if (jsonMatch && jsonMatch[1]) {
		try {
			const parsed = JSON.parse(jsonMatch[1]);
			if (parsed["macos-arm64"])
				downloads["macos-arm64"] = parsed["macos-arm64"];
			if (parsed["macos-x64"]) downloads["macos-x64"] = parsed["macos-x64"];
			if (parsed.windows) downloads.windows = parsed.windows;
			if (parsed["windows-msi"])
				downloads["windows-msi"] = parsed["windows-msi"];
		} catch {}
	}

	return downloads;
}

function parseDownloadsFromAssets(
	assets: GitHubReleaseAsset[],
): ReleaseDownloads {
	const downloads: ReleaseDownloads = {};
	const windowsExe = assets.find(
		(asset) =>
			asset.name.toLowerCase().includes("windows") &&
			asset.name.toLowerCase().endsWith(".exe"),
	);
	const windowsMsi = assets.find(
		(asset) =>
			asset.name.toLowerCase().includes("windows") &&
			asset.name.toLowerCase().endsWith(".msi"),
	);
	const macosArm64 = assets.find((asset) => {
		const name = asset.name.toLowerCase();
		return (
			name.endsWith(".dmg") &&
			(name.includes("macos-arm64") || name.includes("aarch64"))
		);
	});
	const macosX64 = assets.find((asset) => {
		const name = asset.name.toLowerCase();
		return (
			name.endsWith(".dmg") &&
			(name.includes("macos-x64") || name.includes("x64"))
		);
	});

	if (windowsExe) downloads.windows = windowsExe.browser_download_url;
	if (windowsMsi) downloads["windows-msi"] = windowsMsi.browser_download_url;
	if (macosArm64) downloads["macos-arm64"] = macosArm64.browser_download_url;
	if (macosX64) downloads["macos-x64"] = macosX64.browser_download_url;

	return downloads;
}

function extractVersionFromTag(tagName: string): string {
	return tagName.replace(/^cap-v/, "").replace(/^v/, "");
}

function safeReleaseTag(tagName: string): string {
	return tagName.replace(/[^A-Za-z0-9._-]/g, "-").toLowerCase();
}

function normalizeMicrosoftStoreUrl(value: string | undefined): string | null {
	if (!value) return null;

	try {
		const url = new URL(value.trim());
		if (url.protocol !== "https:") return null;
		const hostname = url.hostname.toLowerCase();
		const pathname = withoutLocalePrefix(url.pathname.toLowerCase());

		if (hostname === "apps.microsoft.com") {
			if (
				pathname.startsWith("/detail/") ||
				pathname.startsWith("/store/detail/") ||
				pathname.startsWith("/store/apps/")
			)
				return url.toString();
			return null;
		}

		if (hostname === "www.microsoft.com" || hostname === "microsoft.com") {
			if (
				pathname.startsWith("/store/apps/") ||
				pathname.startsWith("/store/productid/") ||
				pathname.startsWith("/p/")
			)
				return url.toString();
			return null;
		}

		return null;
	} catch {
		return null;
	}
}

function withoutLocalePrefix(pathname: string): string {
	const segments = pathname.split("/").filter(Boolean);
	if (segments[0] && /^[a-z]{2}-[a-z]{2}$/.test(segments[0])) {
		return `/${segments.slice(1).join("/")}`;
	}

	return pathname || "/";
}

export function getWindowsStoreDownloadUrl(): string | null {
	const candidates = [
		process.env.NEXT_PUBLIC_WINDOWS_STORE_URL,
		process.env.WINDOWS_STORE_URL,
		process.env.CAP_WINDOWS_STORE_URL,
	];

	for (const candidate of candidates) {
		const url = normalizeMicrosoftStoreUrl(candidate);
		if (url) return url;
	}

	return null;
}

function hasAssetNamed(assets: GitHubReleaseAsset[], name: string): boolean {
	const names = assets.map((asset) => asset.name.toLowerCase());
	return names.includes(name.toLowerCase());
}

function getAssetNamed(
	assets: GitHubReleaseAsset[],
	name: string,
): GitHubReleaseAsset | null {
	return (
		assets.find((asset) => asset.name.toLowerCase() === name.toLowerCase()) ||
		null
	);
}

function getWindowsInstallerAssetNames(assets: GitHubReleaseAsset[]): string[] {
	return assets
		.filter((asset) => {
			const name = asset.name.toLowerCase();
			return (
				name.includes("windows") &&
				(name.endsWith(".exe") || name.endsWith(".msi"))
			);
		})
		.map((asset) => asset.name);
}

async function fetchJsonAsset<T>(asset: GitHubReleaseAsset): Promise<T | null> {
	try {
		const response = await fetch(asset.browser_download_url, {
			headers: {
				Accept: "application/json,text/plain,*/*",
				"User-Agent": "Cap-Web",
			},
			next: {
				revalidate: 3600,
			},
		});

		if (!response.ok) return null;
		return (await response.json()) as T;
	} catch {
		return null;
	}
}

async function hasWindowsAuditEvidence(
	assets: GitHubReleaseAsset[],
	tagName: string,
): Promise<boolean> {
	const safeTag = safeReleaseTag(tagName);
	const report = getAssetNamed(
		assets,
		`windows-smartscreen-report-${safeTag}.md`,
	);
	const manifestAsset = getAssetNamed(
		assets,
		`windows-release-assets-${safeTag}.json`,
	);
	if (!report || !manifestAsset) return false;

	return hasValidWindowsReleaseAssetManifest(assets, tagName, manifestAsset);
}

export async function hasVerifiedWindowsReleaseAssetEvidence(
	assets: GitHubReleaseAsset[],
	tagName: string,
): Promise<boolean> {
	return (
		hasAssetNamed(assets, "SHA256SUMS.txt") &&
		(await hasWindowsAuditEvidence(assets, tagName)) &&
		hasWindowsSmokeTestEvidence(assets, tagName) &&
		hasWindowsWingetEvidence(assets, tagName) &&
		hasWindowsWdsiEvidence(assets, tagName)
	);
}

async function hasValidWindowsReleaseAssetManifest(
	assets: GitHubReleaseAsset[],
	tagName: string,
	manifestAsset: GitHubReleaseAsset,
): Promise<boolean> {
	const windowsInstallerNames = getWindowsInstallerAssetNames(assets);
	if (windowsInstallerNames.length === 0) return false;

	const manifest =
		await fetchJsonAsset<WindowsReleaseAssetManifest>(manifestAsset);
	if (!manifest) return false;
	if (manifest.Repository !== "Lkkisme/Cap") return false;
	if (manifest.Tag !== tagName) return false;
	if (!Array.isArray(manifest.Assets)) return false;

	const manifestAssets = new Map(
		manifest.Assets.map((asset) => [asset.File, asset]),
	);
	const requiredStatuses: Array<
		[
			keyof WindowsReleaseAssetEvidence,
			NonNullable<
				WindowsReleaseAssetEvidence[keyof WindowsReleaseAssetEvidence]
			>,
		]
	> = [
		["SignatureStatus", "Valid"],
		["TimestampStatus", "Present"],
		["SignToolStatus", "Valid"],
		["ChecksumStatus", "Valid"],
		["AttestationStatus", "Valid"],
		["DefenderStatus", "Valid"],
	];

	for (const installerName of windowsInstallerNames) {
		const evidence = manifestAssets.get(installerName);
		if (!evidence) return false;

		for (const [key, expected] of requiredStatuses) {
			if (evidence[key] !== expected) return false;
		}
	}

	return true;
}

function hasWindowsSmokeTestEvidence(
	assets: GitHubReleaseAsset[],
	tagName: string,
): boolean {
	const safeTag = safeReleaseTag(tagName);
	return (
		hasAssetNamed(
			assets,
			`windows-installer-smoke-test-report-${safeTag}.md`,
		) &&
		hasAssetNamed(
			assets,
			`windows-installer-smoke-test-results-${safeTag}.json`,
		)
	);
}

function hasWindowsWdsiEvidence(
	assets: GitHubReleaseAsset[],
	tagName: string,
): boolean {
	const safeTag = safeReleaseTag(tagName);
	return (
		hasAssetNamed(assets, `windows-wdsi-submission-checklist-${safeTag}.md`) &&
		hasAssetNamed(assets, `windows-wdsi-submission-text-${safeTag}.zip`)
	);
}

function hasWindowsWingetEvidence(
	assets: GitHubReleaseAsset[],
	tagName: string,
): boolean {
	const safeTag = safeReleaseTag(tagName);
	return (
		hasAssetNamed(assets, `windows-winget-manifest-${safeTag}.zip`) &&
		hasAssetNamed(assets, `windows-winget-submission-${safeTag}.md`)
	);
}

export async function getGitHubReleases(): Promise<Release[]> {
	const response = await fetch(
		"https://api.github.com/repos/Lkkisme/Cap/releases?per_page=100",
		{
			headers: {
				Accept: "application/vnd.github.v3+json",
				"User-Agent": "Cap-Web",
			},
			next: {
				revalidate: 3600,
			},
		},
	);

	if (!response.ok) {
		throw new Error(`GitHub API error: ${response.status}`);
	}

	const data: GitHubRelease[] = await response.json();

	const releases = data
		.filter((release) => !release.draft && !release.prerelease)
		.filter((release) => release.tag_name.startsWith("cap-v"));

	return Promise.all(
		releases.map(async (release) => {
			const assetDownloads = parseDownloadsFromAssets(release.assets || []);
			const bodyDownloads = parseDownloadsFromBody(release.body || "");
			const assets = release.assets || [];
			return {
				version: extractVersionFromTag(release.tag_name),
				tagName: release.tag_name,
				publishedAt: release.published_at,
				body: release.body || "",
				htmlUrl: release.html_url,
				downloads: {
					...bodyDownloads,
					...assetDownloads,
				},
				hasChecksums: (release.assets || []).some(
					(asset) => asset.name === "SHA256SUMS.txt",
				),
				hasWindowsAuditEvidence: await hasWindowsAuditEvidence(
					assets,
					release.tag_name,
				),
				hasWindowsSmokeTestEvidence: hasWindowsSmokeTestEvidence(
					assets,
					release.tag_name,
				),
				hasWindowsWingetEvidence: hasWindowsWingetEvidence(
					assets,
					release.tag_name,
				),
				hasWindowsWdsiEvidence: hasWindowsWdsiEvidence(
					assets,
					release.tag_name,
				),
			};
		}),
	);
}

export function hasDownloads(downloads: ReleaseDownloads): boolean {
	return !!(
		downloads["macos-arm64"] ||
		downloads["macos-x64"] ||
		downloads.windows ||
		downloads["windows-msi"]
	);
}

export function hasVerifiedWindowsEvidence(
	release: Pick<
		Release,
		| "hasChecksums"
		| "hasWindowsAuditEvidence"
		| "hasWindowsSmokeTestEvidence"
		| "hasWindowsWingetEvidence"
		| "hasWindowsWdsiEvidence"
	>,
): boolean {
	return (
		release.hasChecksums &&
		release.hasWindowsAuditEvidence &&
		release.hasWindowsSmokeTestEvidence &&
		release.hasWindowsWingetEvidence &&
		release.hasWindowsWdsiEvidence
	);
}

export async function getLatestWindowsDownload(
	installer: "exe" | "msi" = "exe",
): Promise<string | null> {
	const releases = await getGitHubReleases();

	for (const release of releases) {
		if (!hasVerifiedWindowsEvidence(release)) continue;

		const download =
			installer === "msi"
				? release.downloads["windows-msi"] || release.downloads.windows
				: release.downloads.windows || release.downloads["windows-msi"];

		if (download) return download;
	}

	return null;
}
