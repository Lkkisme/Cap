import { Octokit } from "@octokit/rest";
import type { RouteContext } from "@/contracts/next";

const octokit = new Octokit();
const owner = "Lkkisme";
const repo = "Cap";

export const runtime = "edge";

type ReleaseAsset = {
	name: string;
	browser_download_url: string;
};

function assetNames(assets: ReleaseAsset[]) {
	return assets.map((asset) => asset.name.toLowerCase());
}

function hasEvidenceAsset(
	names: string[],
	exactName: string,
	prefix: string,
	suffix: string,
) {
	return names.some(
		(name) =>
			name === exactName || (name.startsWith(prefix) && name.endsWith(suffix)),
	);
}

function hasVerifiedWindowsEvidence(assets: ReleaseAsset[]) {
	const names = assetNames(assets);

	return (
		names.includes("sha256sums.txt") &&
		hasEvidenceAsset(
			names,
			"windows-smartscreen-report.md",
			"windows-smartscreen-report-",
			".md",
		) &&
		hasEvidenceAsset(
			names,
			"windows-release-assets.json",
			"windows-release-assets-",
			".json",
		) &&
		hasEvidenceAsset(
			names,
			"windows-installer-smoke-test-report.md",
			"windows-installer-smoke-test-report-",
			".md",
		) &&
		hasEvidenceAsset(
			names,
			"windows-installer-smoke-test-results.json",
			"windows-installer-smoke-test-results-",
			".json",
		) &&
		hasEvidenceAsset(
			names,
			"windows-winget-manifest.zip",
			"windows-winget-manifest-",
			".zip",
		) &&
		hasEvidenceAsset(
			names,
			"windows-winget-submission.md",
			"windows-winget-submission-",
			".md",
		) &&
		hasEvidenceAsset(
			names,
			"windows-wdsi-submission-checklist.md",
			"windows-wdsi-submission-checklist-",
			".md",
		) &&
		hasEvidenceAsset(
			names,
			"windows-wdsi-submission-text.zip",
			"windows-wdsi-submission-text-",
			".zip",
		)
	);
}

function isWindowsTarget(target: string, arch: string) {
	const value = `${target}-${arch}`.toLowerCase();
	return (
		value.includes("windows") ||
		value.includes("win32") ||
		value.includes("msvc")
	);
}

function isMatchingUpdateAsset(
	asset: ReleaseAsset,
	target: string,
	arch: string,
) {
	const name = asset.name.toLowerCase();
	if (!name.endsWith(".tar.gz") || name.endsWith(".tar.gz.sig")) return false;

	const normalizedTarget = target.toLowerCase();
	const normalizedArch = arch.toLowerCase();

	if (isWindowsTarget(normalizedTarget, normalizedArch)) {
		const matchesWindows =
			name.includes("windows") || name.includes("win32") || name.includes("msvc");
		const matchesArch =
			!normalizedArch ||
			name.includes(normalizedArch) ||
			(normalizedArch === "x86_64" && name.includes("x64")) ||
			(normalizedArch === "x64" && name.includes("x86_64"));

		return matchesWindows && matchesArch;
	}

	return (
		(!normalizedTarget || name.includes(normalizedTarget)) &&
		(!normalizedArch || name.includes(normalizedArch))
	);
}

export async function GET(
	_req: Request,
	props: RouteContext<"/api/releases/tauri/[version]/[target]/[arch]">,
) {
	const params = await props.params;
	try {
		const target = params.target.toLowerCase();
		const arch = params.arch.toLowerCase();

		const { data: release } = await octokit.repos.getLatestRelease({
			owner,
			repo,
		});
		const assets = release.assets as ReleaseAsset[];

		if (isWindowsTarget(target, arch) && !hasVerifiedWindowsEvidence(assets)) {
			return new Response(null, {
				status: 204,
			});
		}

		const version = release.tag_name.replace(/^cap-v/, "").replace(/^v/, "");
		const notes = release.body;
		const pub_date = release.published_at
			? new Date(release.published_at).toISOString()
			: null;

		const asset = assets.find((asset) =>
			isMatchingUpdateAsset(asset, target, arch),
		);

		if (!asset) {
			return new Response(null, {
				status: 204,
			});
		}

		const url = asset.browser_download_url;

		const signatureAsset = assets.find(
			({ name }) => name === `${asset.name}.sig`,
		);

		if (!signatureAsset) {
			return new Response(null, {
				status: 204,
			});
		}

		const signature = await fetch(signatureAsset.browser_download_url).then(
			(r) => r.text(),
		);

		return Response.json(
			{ version, notes, pub_date, url, signature },
			{ status: 200 },
		);
	} catch (error) {
		console.error("Error fetching latest release:", error);
		return Response.json({ error: "Missing required fields" }, { status: 400 });
	}
}
