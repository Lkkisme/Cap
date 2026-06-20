import { type NextRequest, NextResponse } from "next/server";
import {
	getLatestWindowsDownload,
	getWindowsStoreDownloadUrl,
} from "@/utils/releases";

export const runtime = "edge";

function windowsStatusUrl(request: NextRequest) {
	return new URL("/download/windows-status", request.url);
}

export async function GET(
	request: NextRequest,
	props: { params: Promise<{ platform: string }> },
) {
	const params = await props.params;
	const platform = params.platform.toLowerCase();

	if (platform === "windows" || platform === "win") {
		const storeUrl = getWindowsStoreDownloadUrl();
		if (storeUrl) return NextResponse.redirect(storeUrl);

		const downloadUrl = await getLatestWindowsDownload("exe").catch(() => null);
		return NextResponse.redirect(downloadUrl || windowsStatusUrl(request));
	}

	if (platform === "windows-store" || platform === "win-store") {
		const storeUrl = getWindowsStoreDownloadUrl();
		return NextResponse.redirect(storeUrl || windowsStatusUrl(request));
	}

	if (platform === "windows-exe" || platform === "win-exe") {
		const downloadUrl = await getLatestWindowsDownload("exe").catch(() => null);
		return NextResponse.redirect(downloadUrl || windowsStatusUrl(request));
	}

	if (platform === "windows-msi" || platform === "win-msi") {
		const downloadUrl = await getLatestWindowsDownload("msi").catch(() => null);
		return NextResponse.redirect(downloadUrl || windowsStatusUrl(request));
	}

	if (
		platform === "windows-zip" ||
		platform === "windows-portable" ||
		platform === "win-zip" ||
		platform === "win-portable"
	) {
		const downloadUrl = await getLatestWindowsDownload("portable").catch(
			() => null,
		);
		return NextResponse.redirect(downloadUrl || windowsStatusUrl(request));
	}

	const downloadUrls: Record<string, string> = {
		"apple-intel":
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-x86_64",
		intel:
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-x86_64",
		mac: "https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-aarch64",
		macos:
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-aarch64",
		"apple-silicon":
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-aarch64",
		aarch64:
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-aarch64",
		x86_64:
			"https://cdn.crabnebula.app/download/cap/cap/latest/platform/dmg-x86_64",
	};

	const downloadUrl = downloadUrls[platform];

	if (!downloadUrl) {
		return NextResponse.redirect(new URL("/download", request.url));
	}

	return NextResponse.redirect(downloadUrl);
}
