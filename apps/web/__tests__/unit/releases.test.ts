import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { getGitHubReleases } from "@/utils/releases";

const mockFetch = vi.fn();
global.fetch = mockFetch;

const tagName = "cap-v1.2.3";
const windowsExe = "Cap-CN-1.2.3-windows-x64.exe";
const windowsMsi = "Cap-CN-1.2.3-windows-x64.msi";
const windowsPortable = "Cap-CN-1.2.3-windows-x64-portable.zip";

function createAsset(name: string) {
	return {
		name,
		browser_download_url: `https://github.com/Lkkisme/Cap/releases/download/${tagName}/${name}`,
	};
}

function createRelease() {
	return {
		tag_name: tagName,
		name: "Cap Windows 1.2.3",
		published_at: "2026-06-20T00:00:00Z",
		body: "",
		html_url: `https://github.com/Lkkisme/Cap/releases/tag/${tagName}`,
		draft: false,
		prerelease: false,
		assets: [
			createAsset(windowsExe),
			createAsset(windowsMsi),
			createAsset(windowsPortable),
			createAsset("SHA256SUMS.txt"),
			createAsset("windows-smartscreen-report-cap-v1.2.3.md"),
			createAsset("windows-release-assets-cap-v1.2.3.json"),
			createAsset("windows-installer-smoke-test-report-cap-v1.2.3.md"),
			createAsset("windows-installer-smoke-test-results-cap-v1.2.3.json"),
			createAsset("windows-winget-manifest-cap-v1.2.3.zip"),
			createAsset("windows-winget-submission-cap-v1.2.3.md"),
			createAsset("windows-wdsi-submission-checklist-cap-v1.2.3.md"),
			createAsset("windows-wdsi-submission-text-cap-v1.2.3.zip"),
		],
	};
}

function createManifest() {
	return {
		Repository: "Lkkisme/Cap",
		Tag: tagName,
		Assets: [windowsExe, windowsMsi, windowsPortable].map((File) => ({
			File,
			SignatureStatus: "Valid",
			TimestampStatus: "Present",
			SignToolStatus: "Valid",
			ChecksumStatus: "Valid",
			AttestationStatus: "Valid",
			DefenderStatus: "Valid",
		})),
	};
}

function mockReleaseFetches() {
	mockFetch.mockImplementation(async (input) => {
		const url = String(input);

		if (url.includes("/repos/Lkkisme/Cap/releases")) {
			return {
				ok: true,
				json: async () => [createRelease()],
			};
		}

		if (url.includes("windows-release-assets-cap-v1.2.3.json")) {
			return {
				ok: true,
				json: async () => createManifest(),
			};
		}

		return {
			ok: false,
			json: async () => ({}),
		};
	});
}

describe("getGitHubReleases", () => {
	beforeEach(() => {
		vi.clearAllMocks();
		mockReleaseFetches();
	});

	afterEach(() => {
		delete process.env.WINDOWS_RELEASE_ASSET_BASE_URL;
		delete process.env.CAP_WINDOWS_RELEASE_ASSET_BASE_URL;
		delete process.env.NEXT_PUBLIC_WINDOWS_RELEASE_ASSET_BASE_URL;
	});

	it("uses the configured Windows release asset base URL for verified Windows downloads", async () => {
		process.env.WINDOWS_RELEASE_ASSET_BASE_URL =
			"https://downloads.example.com/cap/windows/{tag}/{filename}";

		const releases = await getGitHubReleases();

		expect(releases[0]?.downloads.windows).toBe(
			`https://downloads.example.com/cap/windows/${tagName}/${windowsExe}`,
		);
		expect(releases[0]?.downloads["windows-msi"]).toBe(
			`https://downloads.example.com/cap/windows/${tagName}/${windowsMsi}`,
		);
		expect(releases[0]?.downloads["windows-portable"]).toBe(
			`https://downloads.example.com/cap/windows/${tagName}/${windowsPortable}`,
		);
	});

	it("ignores GitHub release asset base URLs", async () => {
		process.env.WINDOWS_RELEASE_ASSET_BASE_URL =
			"https://github.com/Lkkisme/Cap/releases/download/{tag}/{filename}";

		const releases = await getGitHubReleases();

		expect(releases[0]?.downloads.windows).toBe(
			`https://github.com/Lkkisme/Cap/releases/download/${tagName}/${windowsExe}`,
		);
	});
});
