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
}

export const GITHUB_RELEASES_URL = "https://github.com/Lkkisme/Cap/releases";

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

interface GitHubReleaseAsset {
	name: string;
	browser_download_url: string;
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
			if (parsed["windows-msi"]) downloads["windows-msi"] = parsed["windows-msi"];
		} catch {}
	}

	return downloads;
}

function parseDownloadsFromAssets(assets: GitHubReleaseAsset[]): ReleaseDownloads {
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

	return data
		.filter((release) => !release.draft && !release.prerelease)
		.filter((release) => release.tag_name.startsWith("cap-v"))
		.map((release) => {
			const assetDownloads = parseDownloadsFromAssets(release.assets || []);
			const bodyDownloads = parseDownloadsFromBody(release.body || "");
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
			};
		});
}

export function hasDownloads(downloads: ReleaseDownloads): boolean {
	return !!(
		downloads["macos-arm64"] ||
		downloads["macos-x64"] ||
		downloads.windows ||
		downloads["windows-msi"]
	);
}

export async function getLatestWindowsDownload(
	installer: "exe" | "msi" = "exe",
): Promise<string | null> {
	const releases = await getGitHubReleases();

	for (const release of releases) {
		if (!release.hasChecksums) continue;

		const download =
			installer === "msi"
				? release.downloads["windows-msi"] || release.downloads.windows
				: release.downloads.windows || release.downloads["windows-msi"];

		if (download) return download;
	}

	return null;
}
